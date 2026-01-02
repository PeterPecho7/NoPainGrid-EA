//+------------------------------------------------------------------+
//|                                    NoPainGrid_EA_v3_Monitoring.mq5|
//|                                                                   |
//|  VERZIA S MONITORINGOM                                           |
//|  ======================                                           |
//|  Táto verzia obsahuje:                                           |
//|  - Discord notifikácie (webhook)                                 |
//|  - MT5 Push notifikácie na mobil                                 |
//|  - Email notifikácie                                             |
//|  - Denný report                                                  |
//|  - Heartbeat monitoring (kontrola že EA beží)                    |
//|                                                                   |
//|  NASTAVENIE DISCORD:                                             |
//|  1. Vytvor Discord server alebo použi existujúci                 |
//|  2. Vytvor kanál pre notifikácie (napr. #trading-alerts)         |
//|  3. Klikni na ozubené koliesko pri kanáli -> Integrations        |
//|  4. Klikni "Create Webhook" a skopíruj URL                       |
//|  5. Zadaj URL do nastavení EA                                    |
//|                                                                   |
//|  NASTAVENIE MT5 PUSH:                                            |
//|  1. Stiahni MetaTrader 5 app na mobil                            |
//|  2. V app choď do Settings -> Messages                           |
//|  3. Nájdi MetaQuotes ID (8 znakov)                               |
//|  4. V MT5 PC: Tools -> Options -> Notifications                  |
//|  5. Zadaj MetaQuotes ID a zapni notifikácie                      |
//|                                                                   |
//|  NASTAVENIE EMAIL:                                               |
//|  1. V MT5: Tools -> Options -> Email                             |
//|  2. Zadaj SMTP server (napr. smtp.gmail.com:465)                 |
//|  3. Zadaj email a heslo (pre Gmail použi App Password)           |
//|  4. Otestuj tlačidlom Test                                       |
//+------------------------------------------------------------------+
#property copyright "Based on NoPain MT5 Signal + Monitoring"
#property version   "3.00"
#property description "Grid/Martingale EA s Discord/Email/Push monitoringom"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| VSTUPNÉ PARAMETRE                                                 |
//+------------------------------------------------------------------+

//--- Hlavné nastavenia gridu
input group "=== HLAVNÉ NASTAVENIA GRIDU ==="
input double   InpLotSize        = 0.13;          // Počiatočná veľkosť lotu
input double   InpLotMultiplier  = 1.5;           // Násobič lotu pre ďalšie úrovne
input int      InpGridStepPips   = 20;            // Rozostup mriežky v pipsoch
input int      InpMaxGridLevels  = 10;            // Maximálny počet úrovní gridu
input double   InpTakeProfitPips = 15;            // Take Profit v pipsoch
input double   InpTotalTPPercent = 1.0;           // Celkový TP ako % zostatku

//--- Časové filtre
input group "=== ČASOVÉ FILTRE ==="
input int      InpStartHour      = 0;             // Začiatok obchodovania
input int      InpEndHour        = 23;            // Koniec obchodovania
input bool     InpTradeFriday    = true;          // Obchodovať v piatok?

//--- Riadenie rizika
input group "=== RIADENIE RIZIKA ==="
input double   InpMaxDrawdownPct = 20.0;          // Max drawdown %
input double   InpMaxLotSize     = 5.0;           // Max celková veľkosť lotov
input int      InpMagicNumber    = 2262642;       // Magické číslo

//--- Vstupné signály
input group "=== VSTUPNÉ SIGNÁLY ==="
input int      InpRSIPeriod      = 14;            // Perióda RSI
input int      InpRSIOverbought  = 70;            // RSI prekúpená úroveň
input int      InpRSIOversold    = 30;            // RSI prepredaná úroveň
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1;   // Časový rámec

//--- DISCORD MONITORING
input group "=== DISCORD WEBHOOK ==="
input bool     InpUseDiscord     = true;          // Používať Discord notifikácie
input string   InpDiscordWebhook = "";            // Discord Webhook URL (celá URL)

//--- MT5 PUSH NOTIFIKÁCIE
input group "=== MT5 PUSH NOTIFIKÁCIE ==="
input bool     InpUsePush        = true;          // Používať MT5 Push notifikácie (nastav MetaQuotes ID v Options)

//--- EMAIL NOTIFIKÁCIE
input group "=== EMAIL NOTIFIKÁCIE ==="
input bool     InpUseEmail       = true;          // Používať Email notifikácie (nastav SMTP v Options)

//--- TYPY NOTIFIKÁCIÍ
input group "=== ČO NOTIFIKOVAŤ ==="
input bool     InpNotifyStart    = true;          // Notifikovať pri štarte/zastavení EA
input bool     InpNotifyTrade    = true;          // Notifikovať pri otvorení obchodu
input bool     InpNotifyProfit   = true;          // Notifikovať pri zatvorení (profit/strata)
input bool     InpNotifyDrawdown = true;          // Notifikovať pri vysokom drawdowne
input bool     InpNotifyDaily    = true;          // Denný report (o 23:00)
input bool     InpNotifyHeartbeat= true;          // Heartbeat každú hodinu

//--- PRAHY UPOZORNENÍ
input group "=== PRAHY UPOZORNENÍ ==="
input double   InpAlertDrawdown  = 10.0;          // Upozorniť pri drawdowne % (varovanie pred max)
input int      InpHeartbeatHour  = 1;             // Heartbeat každých X hodín (1-24)

//+------------------------------------------------------------------+
//| GLOBÁLNE PREMENNÉ                                                 |
//+------------------------------------------------------------------+
CTrade         trade;
int            handleRSI;
double         gridStep;
double         point;
string         symbol = "AUDCAD";
double         initialBalance;

//--- Grid tracking
struct GridPosition
{
   ulong    ticket;
   double   openPrice;
   double   lots;
   int      type;
   int      level;
};

GridPosition   buyGrid[];
GridPosition   sellGrid[];
int            buyLevels = 0;
int            sellLevels = 0;

//--- Monitoring premenné
datetime       lastHeartbeat = 0;
datetime       lastDailyReport = 0;
datetime       lastDDAlert = 0;
double         dailyStartBalance = 0;
int            dailyTrades = 0;
double         dailyProfit = 0;
int            totalTradesSession = 0;
double         maxDrawdownToday = 0;

//+------------------------------------------------------------------+
//| INICIALIZÁCIA                                                     |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Overenie symbolu
   if(!SymbolSelect(symbol, true))
   {
      Print("CHYBA: Symbol ", symbol, " nie je dostupný!");
      return(INIT_FAILED);
   }

   //--- Nastavenie trade objektu
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   //--- Výpočet hodnôt
   point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      gridStep = InpGridStepPips * 10 * point;
   else
      gridStep = InpGridStepPips * point;

   //--- RSI indikátor
   handleRSI = iRSI(symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   if(handleRSI == INVALID_HANDLE)
   {
      Print("CHYBA: Nepodarilo sa vytvoriť RSI indikátor!");
      return(INIT_FAILED);
   }

   //--- Inicializácia
   initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   dailyStartBalance = initialBalance;
   ArrayResize(buyGrid, InpMaxGridLevels);
   ArrayResize(sellGrid, InpMaxGridLevels);

   //--- Notifikácia o štarte
   if(InpNotifyStart)
   {
      string startMsg =
         ":green_circle: **EA SPUSTENÝ**\n" +
         "```\n" +
         "Symbol:    " + symbol + "\n" +
         "Zostatok:  $" + DoubleToString(initialBalance, 2) + "\n" +
         "Lot:       " + DoubleToString(InpLotSize, 2) + "\n" +
         "Grid:      " + IntegerToString(InpGridStepPips) + " pips\n" +
         "Max DD:    " + DoubleToString(InpMaxDrawdownPct, 1) + "%\n" +
         "```";
      SendNotification_All("EA SPUSTENÝ", startMsg);
   }

   Print("NoPain Grid EA v3 (Monitoring) inicializovaný");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| DEINICIALIZÁCIA                                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(handleRSI != INVALID_HANDLE)
      IndicatorRelease(handleRSI);

   //--- Notifikácia o zastavení
   if(InpNotifyStart)
   {
      double sessionPL = AccountInfoDouble(ACCOUNT_BALANCE) - initialBalance;
      string stopMsg =
         ":red_circle: **EA ZASTAVENÝ**\n" +
         "```\n" +
         "Dôvod:     " + GetDeinitReasonText(reason) + "\n" +
         "Zostatok:  $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n" +
         "Session:   " + (sessionPL >= 0 ? "+" : "") + DoubleToString(sessionPL, 2) + "$\n" +
         "Obchodov:  " + IntegerToString(totalTradesSession) + "\n" +
         "```";
      SendNotification_All("EA ZASTAVENÝ", stopMsg);
   }
}

//+------------------------------------------------------------------+
//| HLAVNÁ FUNKCIA                                                    |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Monitoring kontroly
   CheckHeartbeat();
   CheckDailyReport();
   CheckDrawdownAlert();

   //--- Obchodná logika
   if(!IsTradingTime())
      return;

   if(CheckDrawdown())
   {
      CloseAllPositions("Max Drawdown");
      return;
   }

   UpdateGridInfo();

   if(CheckTotalProfit())
   {
      CloseAllPositions("Target Profit");
      return;
   }

   int signal = GetSignal();

   if(buyLevels == 0 && sellLevels == 0)
   {
      if(signal == 1)
         OpenGridPosition(ORDER_TYPE_BUY, 0);
      else if(signal == -1)
         OpenGridPosition(ORDER_TYPE_SELL, 0);
   }
   else
   {
      ManageGrid();
   }
}

//+------------------------------------------------------------------+
//| DISCORD WEBHOOK NOTIFIKÁCIA                                       |
//| Pošle správu cez Discord Webhook                                 |
//+------------------------------------------------------------------+
bool SendDiscord(string message)
{
   if(!InpUseDiscord || InpDiscordWebhook == "")
      return false;

   //--- Vytvorenie JSON payload pre Discord
   //    Discord webhook očakáva JSON s "content" alebo "embeds"
   string jsonPayload = "{\"content\": \"" + EscapeJsonString(message) + "\"}";

   //--- Konverzia na char array
   char postData[];
   char result[];
   string headers = "Content-Type: application/json\r\n";

   StringToCharArray(jsonPayload, postData, 0, StringLen(jsonPayload));

   //--- Odoslanie HTTP POST požiadavky
   int timeout = 5000;
   string resultHeaders;

   int res = WebRequest(
      "POST",
      InpDiscordWebhook,
      headers,
      timeout,
      postData,
      result,
      resultHeaders
   );

   if(res == -1)
   {
      int error = GetLastError();
      if(error == 4014)
         Print("DISCORD: Pridaj URL do povolených: Tools -> Options -> Expert Advisors -> Allow WebRequest for: discord.com");
      else
         Print("DISCORD: Chyba ", error);
      return false;
   }

   //--- Discord vracia 204 No Content pri úspechu
   if(res == 204 || res == 200)
      return true;

   Print("DISCORD: HTTP response code: ", res);
   return false;
}

//+------------------------------------------------------------------+
//| ESCAPE JSON STRING                                                |
//| Escapuje špeciálne znaky pre JSON                                |
//+------------------------------------------------------------------+
string EscapeJsonString(string text)
{
   string result = text;
   StringReplace(result, "\\", "\\\\");
   StringReplace(result, "\"", "\\\"");
   StringReplace(result, "\n", "\\n");
   StringReplace(result, "\r", "\\r");
   StringReplace(result, "\t", "\\t");
   return result;
}

//+------------------------------------------------------------------+
//| MT5 PUSH NOTIFIKÁCIA                                              |
//| Pošle notifikáciu do MT5 mobilnej aplikácie                      |
//| Vyžaduje nastavenie MetaQuotes ID v MT5: Tools->Options->Notif.  |
//+------------------------------------------------------------------+
bool SendPushNotification(string message)
{
   if(!InpUsePush)
      return false;

   //--- Orezanie správy (push má limit ~255 znakov)
   string shortMsg = message;
   if(StringLen(shortMsg) > 250)
      shortMsg = StringSubstr(message, 0, 247) + "...";

   //--- Odstránenie Discord formátovania pre push
   StringReplace(shortMsg, ":green_circle:", "[OK]");
   StringReplace(shortMsg, ":red_circle:", "[!]");
   StringReplace(shortMsg, ":chart_with_upwards_trend:", "[+]");
   StringReplace(shortMsg, ":moneybag:", "[$]");
   StringReplace(shortMsg, ":warning:", "[!]");
   StringReplace(shortMsg, ":heartbeat:", "[♥]");
   StringReplace(shortMsg, ":bar_chart:", "[#]");
   StringReplace(shortMsg, "```", "");
   StringReplace(shortMsg, "**", "");

   return SendNotification(shortMsg);
}

//+------------------------------------------------------------------+
//| EMAIL NOTIFIKÁCIA                                                 |
//| Pošle email (vyžaduje nastavenie SMTP v MT5: Tools->Options->Email)|
//+------------------------------------------------------------------+
bool SendEmailNotification(string subject, string body)
{
   if(!InpUseEmail)
      return false;

   //--- Odstránenie Discord formátovania pre email
   string cleanBody = body;
   StringReplace(cleanBody, ":green_circle:", "[OK]");
   StringReplace(cleanBody, ":red_circle:", "[STOP]");
   StringReplace(cleanBody, ":chart_with_upwards_trend:", "[TRADE]");
   StringReplace(cleanBody, ":moneybag:", "[PROFIT]");
   StringReplace(cleanBody, ":warning:", "[WARNING]");
   StringReplace(cleanBody, ":heartbeat:", "[HEARTBEAT]");
   StringReplace(cleanBody, ":bar_chart:", "[REPORT]");
   StringReplace(cleanBody, "```", "");
   StringReplace(cleanBody, "**", "");
   StringReplace(cleanBody, "\\n", "\n");

   return SendMail("NoPain EA: " + subject, cleanBody);
}

//+------------------------------------------------------------------+
//| UNIVERZÁLNA NOTIFIKÁCIA - POŠLE VŠETKÝMI KANÁLMI                 |
//+------------------------------------------------------------------+
void SendNotification_All(string subject, string message)
{
   //--- Discord (plná správa s formátovaním)
   SendDiscord(message);

   //--- MT5 Push (skrátená verzia)
   SendPushNotification(subject + ": " + message);

   //--- Email (čistý text)
   SendEmailNotification(subject, message);

   //--- Log do terminálu
   Print("NOTIFIKÁCIA [", subject, "]: ", StringSubstr(message, 0, 100), "...");
}

//+------------------------------------------------------------------+
//| HEARTBEAT - KONTROLA ŽE EA BEŽÍ                                  |
//| Pošle správu každých X hodín                                     |
//+------------------------------------------------------------------+
void CheckHeartbeat()
{
   if(!InpNotifyHeartbeat)
      return;

   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);

   //--- Heartbeat podľa nastaveného intervalu
   int heartbeatInterval = InpHeartbeatHour * 3600; // v sekundách

   if(currentTime - lastHeartbeat >= heartbeatInterval)
   {
      lastHeartbeat = currentTime;

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double floatingPL = equity - balance;
      double currentDD = (balance > 0) ? ((balance - equity) / balance * 100) : 0;
      int openPositions = GetPositionCount();

      string heartbeatMsg =
         ":heartbeat: **HEARTBEAT** " + TimeToString(currentTime, TIME_DATE|TIME_MINUTES) + "\n" +
         "```\n" +
         "Zostatok:  $" + DoubleToString(balance, 2) + "\n" +
         "Equity:    $" + DoubleToString(equity, 2) + "\n" +
         "Floating:  " + (floatingPL >= 0 ? "+" : "") + DoubleToString(floatingPL, 2) + "$\n" +
         "Drawdown:  " + DoubleToString(currentDD, 2) + "%\n" +
         "Pozície:   " + IntegerToString(openPositions) + "\n" +
         "```";

      //--- Heartbeat len cez Discord (menej spam na mobil)
      SendDiscord(heartbeatMsg);
   }
}

//+------------------------------------------------------------------+
//| DENNÝ REPORT                                                      |
//| O 23:00 pošle súhrn dňa                                          |
//+------------------------------------------------------------------+
void CheckDailyReport()
{
   if(!InpNotifyDaily)
      return;

   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);

   //--- Denný report o 23:00
   if(dt.hour == 23 && dt.min == 0 && currentTime - lastDailyReport > 3500)
   {
      lastDailyReport = currentTime;

      double currentBalance = AccountInfoDouble(ACCOUNT_BALANCE);
      double dayPL = currentBalance - dailyStartBalance;
      double dayPLPercent = (dailyStartBalance > 0) ? (dayPL / dailyStartBalance * 100) : 0;

      string emoji = (dayPL >= 0) ? ":chart_with_upwards_trend:" : ":chart_with_downwards_trend:";

      string reportMsg =
         ":bar_chart: **DENNÝ REPORT**\n" +
         "```\n" +
         "Dátum:     " + IntegerToString(dt.year) + "-" +
                         StringFormat("%02d", dt.mon) + "-" +
                         StringFormat("%02d", dt.day) + "\n" +
         "Zostatok:  $" + DoubleToString(currentBalance, 2) + "\n" +
         "Denný P/L: " + (dayPL >= 0 ? "+" : "") + DoubleToString(dayPL, 2) +
                    "$ (" + DoubleToString(dayPLPercent, 2) + "%)\n" +
         "Obchodov:  " + IntegerToString(dailyTrades) + "\n" +
         "Max DD:    " + DoubleToString(maxDrawdownToday, 2) + "%\n" +
         "```";

      SendNotification_All("DENNÝ REPORT", reportMsg);

      //--- Reset denných počítadiel
      dailyStartBalance = currentBalance;
      dailyTrades = 0;
      dailyProfit = 0;
      maxDrawdownToday = 0;
   }
}

//+------------------------------------------------------------------+
//| KONTROLA DRAWDOWN ALERTU                                         |
//+------------------------------------------------------------------+
void CheckDrawdownAlert()
{
   if(!InpNotifyDrawdown)
      return;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   if(balance <= 0)
      return;

   double currentDD = (balance - equity) / balance * 100;

   //--- Aktualizuj max drawdown dnes
   if(currentDD > maxDrawdownToday)
      maxDrawdownToday = currentDD;

   //--- Alert ak drawdown prekročí varovnú úroveň (max 1x za hodinu)
   if(currentDD >= InpAlertDrawdown && TimeCurrent() - lastDDAlert > 3600)
   {
      lastDDAlert = TimeCurrent();

      string ddMsg =
         ":warning: **DRAWDOWN ALERT!**\n" +
         "```\n" +
         "Aktuálny:  " + DoubleToString(currentDD, 2) + "%\n" +
         "Maximum:   " + DoubleToString(InpMaxDrawdownPct, 1) + "%\n" +
         "Zostatok:  $" + DoubleToString(balance, 2) + "\n" +
         "Equity:    $" + DoubleToString(equity, 2) + "\n" +
         "Strata:    $" + DoubleToString(balance - equity, 2) + "\n" +
         "```";

      SendNotification_All("DRAWDOWN ALERT", ddMsg);
   }
}

//+------------------------------------------------------------------+
//| NOTIFIKÁCIA PRI OTVORENÍ OBCHODU                                 |
//+------------------------------------------------------------------+
void NotifyTradeOpen(string type, int level, double lots, double price)
{
   if(!InpNotifyTrade)
      return;

   dailyTrades++;
   totalTradesSession++;

   string tradeMsg =
      ":chart_with_upwards_trend: **NOVÝ OBCHOD**\n" +
      "```\n" +
      "Typ:       " + type + "\n" +
      "Úroveň:    " + IntegerToString(level) + "\n" +
      "Loty:      " + DoubleToString(lots, 2) + "\n" +
      "Cena:      " + DoubleToString(price, 5) + "\n" +
      "Pozícií:   " + IntegerToString(GetPositionCount()) + "\n" +
      "```";

   SendNotification_All("OBCHOD " + type, tradeMsg);
}

//+------------------------------------------------------------------+
//| NOTIFIKÁCIA PRI ZATVORENÍ VŠETKÝCH POZÍCIÍ                       |
//+------------------------------------------------------------------+
void NotifyTradeClose(string reason, double profit, int count)
{
   if(!InpNotifyProfit)
      return;

   dailyProfit += profit;

   string emoji = (profit >= 0) ? ":moneybag:" : ":small_red_triangle_down:";

   string closeMsg =
      emoji + " **POZÍCIE ZATVORENÉ**\n" +
      "```\n" +
      "Dôvod:     " + reason + "\n" +
      "Pozícií:   " + IntegerToString(count) + "\n" +
      "Profit:    " + (profit >= 0 ? "+" : "") + DoubleToString(profit, 2) + "$\n" +
      "Zostatok:  $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + "\n" +
      "```";

   SendNotification_All("PROFIT " + DoubleToString(profit, 2) + "$", closeMsg);
}

//+------------------------------------------------------------------+
//| POMOCNÁ FUNKCIA - TEXT DÔVODU DEINIT                             |
//+------------------------------------------------------------------+
string GetDeinitReasonText(int reason)
{
   switch(reason)
   {
      case REASON_PROGRAM:     return "EA zastavený";
      case REASON_REMOVE:      return "EA odstránený";
      case REASON_RECOMPILE:   return "Prekompilovaný";
      case REASON_CHARTCHANGE: return "Zmena grafu";
      case REASON_CHARTCLOSE:  return "Graf zatvorený";
      case REASON_PARAMETERS:  return "Zmena parametrov";
      case REASON_ACCOUNT:     return "Zmena účtu";
      case REASON_TEMPLATE:    return "Šablóna";
      case REASON_INITFAILED:  return "Init failed";
      case REASON_CLOSE:       return "MT5 zatvorený";
      default:                 return "Neznámy";
   }
}

//+------------------------------------------------------------------+
//| OBCHODNÁ LOGIKA                                                  |
//+------------------------------------------------------------------+

bool IsTradingTime()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   if(dt.day_of_week == 5 && !InpTradeFriday) return false;
   if(dt.day_of_week == 0 || dt.day_of_week == 6) return false;
   if(dt.hour < InpStartHour || dt.hour > InpEndHour) return false;
   return true;
}

bool CheckDrawdown()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(balance <= 0) return false;
   double drawdown = (balance - equity) / balance * 100;
   if(drawdown >= InpMaxDrawdownPct)
   {
      Print("MAX DRAWDOWN: ", drawdown, "%");
      return true;
   }
   return false;
}

int GetSignal()
{
   double rsi[];
   ArraySetAsSeries(rsi, true);
   if(CopyBuffer(handleRSI, 0, 0, 3, rsi) < 3) return 0;
   if(rsi[1] < InpRSIOversold && rsi[0] >= InpRSIOversold) return 1;
   if(rsi[0] < InpRSIOversold) return 1;
   if(rsi[1] > InpRSIOverbought && rsi[0] <= InpRSIOverbought) return -1;
   if(rsi[0] > InpRSIOverbought) return -1;
   return 0;
}

void UpdateGridInfo()
{
   buyLevels = 0;
   sellLevels = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double lots = PositionGetDouble(POSITION_VOLUME);
      if(posType == POSITION_TYPE_BUY && buyLevels < InpMaxGridLevels)
      {
         buyGrid[buyLevels].ticket = ticket;
         buyGrid[buyLevels].openPrice = openPrice;
         buyGrid[buyLevels].lots = lots;
         buyLevels++;
      }
      else if(posType == POSITION_TYPE_SELL && sellLevels < InpMaxGridLevels)
      {
         sellGrid[sellLevels].ticket = ticket;
         sellGrid[sellLevels].openPrice = openPrice;
         sellGrid[sellLevels].lots = lots;
         sellLevels++;
      }
   }
}

bool OpenGridPosition(ENUM_ORDER_TYPE orderType, int level)
{
   double lotSize = CalculateLotSize(level);
   double totalLots = GetTotalLots() + lotSize;
   if(totalLots > InpMaxLotSize)
   {
      Print("MAX LOTY: ", totalLots);
      return false;
   }

   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double price = (orderType == ORDER_TYPE_BUY) ? ask : bid;

   double tp = 0;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double tpPips = InpTakeProfitPips * ((digits == 3 || digits == 5) ? 10 : 1) * point;
   if(orderType == ORDER_TYPE_BUY) tp = price + tpPips;
   else tp = price - tpPips;

   bool result = false;
   string comment = "NoPain L" + IntegerToString(level);
   if(orderType == ORDER_TYPE_BUY)
      result = trade.Buy(lotSize, symbol, price, 0, tp, comment);
   else
      result = trade.Sell(lotSize, symbol, price, 0, tp, comment);

   if(result)
   {
      string typeStr = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      Print("OPEN: ", typeStr, " L", level, " @", price, " Lots:", lotSize);
      NotifyTradeOpen(typeStr, level, lotSize, price);
   }
   else
   {
      Print("ERROR: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
   return result;
}

double CalculateLotSize(int level)
{
   double lots = InpLotSize;
   for(int i = 0; i < level; i++) lots *= InpLotMultiplier;
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP);
   lots = MathFloor(lots / lotStep) * lotStep;
   lots = MathMax(minLot, MathMin(maxLot, lots));
   return lots;
}

double GetTotalLots()
{
   double totalLots = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      totalLots += PositionGetDouble(POSITION_VOLUME);
   }
   return totalLots;
}

void ManageGrid()
{
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

   if(buyLevels > 0 && buyLevels < InpMaxGridLevels)
   {
      double lowestBuy = DBL_MAX;
      for(int i = 0; i < buyLevels; i++)
         if(buyGrid[i].openPrice < lowestBuy) lowestBuy = buyGrid[i].openPrice;
      if(ask <= lowestBuy - gridStep)
         OpenGridPosition(ORDER_TYPE_BUY, buyLevels);
   }

   if(sellLevels > 0 && sellLevels < InpMaxGridLevels)
   {
      double highestSell = 0;
      for(int i = 0; i < sellLevels; i++)
         if(sellGrid[i].openPrice > highestSell) highestSell = sellGrid[i].openPrice;
      if(bid >= highestSell + gridStep)
         OpenGridPosition(ORDER_TYPE_SELL, sellLevels);
   }
}

bool CheckTotalProfit()
{
   double totalProfit = GetTotalProfit();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double targetProfit = balance * InpTotalTPPercent / 100.0;
   if(totalProfit >= targetProfit)
   {
      Print("TARGET PROFIT: ", totalProfit);
      return true;
   }
   return false;
}

double GetTotalProfit()
{
   double totalProfit = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      totalProfit += PositionGetDouble(POSITION_PROFIT);
      totalProfit += PositionGetDouble(POSITION_SWAP);
   }
   return totalProfit;
}

void CloseAllPositions(string reason)
{
   int closedCount = 0;
   double closedProfit = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      closedProfit += PositionGetDouble(POSITION_PROFIT);
      closedProfit += PositionGetDouble(POSITION_SWAP);
      if(trade.PositionClose(ticket)) closedCount++;
   }

   Print("CLOSED ", closedCount, " | Reason: ", reason, " | Profit: ", closedProfit);
   NotifyTradeClose(reason, closedProfit, closedCount);
}

int GetPositionCount()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
      if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
