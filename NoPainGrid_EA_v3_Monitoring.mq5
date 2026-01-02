//+------------------------------------------------------------------+
//|                                    NoPainGrid_EA_v3_Monitoring.mq5|
//|                                                                   |
//|  VERZIA S MONITORINGOM                                           |
//|  ======================                                           |
//|  Táto verzia obsahuje:                                           |
//|  - Telegram notifikácie                                          |
//|  - MT5 Push notifikácie na mobil                                 |
//|  - Denný report                                                  |
//|  - Heartbeat monitoring (kontrola že EA beží)                    |
//|                                                                   |
//|  NASTAVENIE TELEGRAMU:                                           |
//|  1. Vytvor bota cez @BotFather na Telegrame                      |
//|  2. Získaj Bot Token (napr. 123456:ABC-DEF...)                   |
//|  3. Získaj Chat ID cez @userinfobot                              |
//|  4. Zadaj tieto údaje do nastavení EA                            |
//+------------------------------------------------------------------+
#property copyright "Based on NoPain MT5 Signal + Monitoring"
#property version   "3.00"
#property description "Grid/Martingale EA s Telegram monitoringom"
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

//--- MONITORING NASTAVENIA
input group "=== TELEGRAM MONITORING ==="
input bool     InpUseTelegram    = true;          // Používať Telegram notifikácie
input string   InpTelegramToken  = "";            // Telegram Bot Token (od @BotFather)
input string   InpTelegramChatID = "";            // Telegram Chat ID (od @userinfobot)

input group "=== MT5 PUSH NOTIFIKÁCIE ==="
input bool     InpUsePush        = true;          // Používať MT5 Push notifikácie
input bool     InpUseEmail       = false;         // Používať Email notifikácie

input group "=== TYPY NOTIFIKÁCIÍ ==="
input bool     InpNotifyTrade    = true;          // Notifikovať pri otvorení/zatvorení obchodu
input bool     InpNotifyProfit   = true;          // Notifikovať pri dosiahnutí TP
input bool     InpNotifyDrawdown = true;          // Notifikovať pri vysokom drawdowne
input bool     InpNotifyDaily    = true;          // Denný report (o 23:00)
input bool     InpNotifyHeartbeat= true;          // Heartbeat každú hodinu

input group "=== UPOZORNENIA ==="
input double   InpAlertDrawdown  = 10.0;          // Upozorniť pri drawdowne % (pred max)
input double   InpAlertProfit    = 50.0;          // Upozorniť pri profite $ (denne)

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
datetime       lastHeartbeat = 0;      // Čas posledného heartbeatu
datetime       lastDailyReport = 0;    // Čas posledného denného reportu
double         dailyStartBalance = 0;  // Zostatok na začiatku dňa
int            dailyTrades = 0;        // Počet obchodov dnes
double         dailyProfit = 0;        // Profit dnes
int            totalTradesSession = 0; // Celkový počet obchodov v session
double         maxDrawdownToday = 0;   // Max drawdown dnes

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
   string startMsg = StringFormat(
      "🟢 EA SPUSTENÝ\n" +
      "━━━━━━━━━━━━━━━\n" +
      "Symbol: %s\n" +
      "Zostatok: $%.2f\n" +
      "Lot: %.2f\n" +
      "Grid: %d pips\n" +
      "Max DD: %.1f%%\n" +
      "━━━━━━━━━━━━━━━",
      symbol,
      initialBalance,
      InpLotSize,
      InpGridStepPips,
      InpMaxDrawdownPct
   );
   SendNotification_All(startMsg);

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
   string stopMsg = StringFormat(
      "🔴 EA ZASTAVENÝ\n" +
      "━━━━━━━━━━━━━━━\n" +
      "Dôvod: %s\n" +
      "Zostatok: $%.2f\n" +
      "Session P/L: $%.2f\n" +
      "Obchodov: %d\n" +
      "━━━━━━━━━━━━━━━",
      GetDeinitReasonText(reason),
      AccountInfoDouble(ACCOUNT_BALANCE),
      AccountInfoDouble(ACCOUNT_BALANCE) - initialBalance,
      totalTradesSession
   );
   SendNotification_All(stopMsg);
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
//| TELEGRAM NOTIFIKÁCIA                                              |
//| Pošle správu cez Telegram Bot API                                |
//+------------------------------------------------------------------+
bool SendTelegram(string message)
{
   if(!InpUseTelegram || InpTelegramToken == "" || InpTelegramChatID == "")
      return false;

   //--- Escapovanie špeciálnych znakov pre URL
   string encodedMsg = message;
   StringReplace(encodedMsg, " ", "%20");
   StringReplace(encodedMsg, "\n", "%0A");
   StringReplace(encodedMsg, "#", "%23");
   StringReplace(encodedMsg, "&", "%26");

   //--- Vytvorenie URL pre Telegram API
   string url = StringFormat(
      "https://api.telegram.org/bot%s/sendMessage?chat_id=%s&text=%s&parse_mode=HTML",
      InpTelegramToken,
      InpTelegramChatID,
      encodedMsg
   );

   //--- Odoslanie HTTP požiadavky
   char post[], result[];
   string headers;
   int timeout = 5000;

   int res = WebRequest("GET", url, "", timeout, post, result, headers);

   if(res == -1)
   {
      int error = GetLastError();
      if(error == 4014)
         Print("TELEGRAM: Pridaj URL do povolených: Tools -> Options -> Expert Advisors -> Allow WebRequest for: api.telegram.org");
      else
         Print("TELEGRAM: Chyba ", error);
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| MT5 PUSH NOTIFIKÁCIA                                              |
//| Pošle notifikáciu do MT5 mobilnej aplikácie                      |
//+------------------------------------------------------------------+
bool SendPushNotification(string message)
{
   if(!InpUsePush)
      return false;

   //--- MT5 Push notifikácia (vyžaduje nastavenie v MT5 -> Tools -> Options -> Notifications)
   return SendNotification(message);
}

//+------------------------------------------------------------------+
//| EMAIL NOTIFIKÁCIA                                                 |
//+------------------------------------------------------------------+
bool SendEmailNotification(string subject, string message)
{
   if(!InpUseEmail)
      return false;

   //--- Email (vyžaduje nastavenie v MT5 -> Tools -> Options -> Email)
   return SendMail(subject, message);
}

//+------------------------------------------------------------------+
//| UNIVERZÁLNA NOTIFIKÁCIA - POŠLE VŠETKÝMI KANÁLMI                 |
//+------------------------------------------------------------------+
void SendNotification_All(string message)
{
   //--- Telegram
   SendTelegram(message);

   //--- MT5 Push (skrátiť pre push)
   string shortMsg = message;
   if(StringLen(shortMsg) > 200)
   {
      shortMsg = StringSubstr(message, 0, 197) + "...";
   }
   SendPushNotification(shortMsg);

   //--- Email
   SendEmailNotification("NoPain Grid EA", message);

   //--- Log
   Print("NOTIFIKÁCIA: ", message);
}

//+------------------------------------------------------------------+
//| HEARTBEAT - KONTROLA ŽE EA BEŽÍ                                  |
//| Každú hodinu pošle správu že EA je aktívny                       |
//+------------------------------------------------------------------+
void CheckHeartbeat()
{
   if(!InpNotifyHeartbeat)
      return;

   datetime currentTime = TimeCurrent();
   MqlDateTime dt;
   TimeToStruct(currentTime, dt);

   //--- Heartbeat na začiatku každej hodiny (minúta 0)
   if(dt.min == 0 && currentTime - lastHeartbeat > 3500) // 3500 sekúnd = skoro hodina
   {
      lastHeartbeat = currentTime;

      double equity = AccountInfoDouble(ACCOUNT_EQUITY);
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double floatingPL = equity - balance;
      int openPositions = GetPositionCount();

      string heartbeatMsg = StringFormat(
         "💓 HEARTBEAT %02d:00\n" +
         "Zostatok: $%.2f\n" +
         "Equity: $%.2f\n" +
         "Floating: %s$%.2f\n" +
         "Pozície: %d",
         dt.hour,
         balance,
         equity,
         (floatingPL >= 0 ? "+" : ""),
         floatingPL,
         openPositions
      );

      SendTelegram(heartbeatMsg);  // Len Telegram pre heartbeat
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

      string reportMsg = StringFormat(
         "📊 DENNÝ REPORT\n" +
         "━━━━━━━━━━━━━━━\n" +
         "Dátum: %04d-%02d-%02d\n" +
         "Zostatok: $%.2f\n" +
         "Denný P/L: %s$%.2f (%.2f%%)\n" +
         "Obchodov: %d\n" +
         "Max DD: %.2f%%\n" +
         "━━━━━━━━━━━━━━━",
         dt.year, dt.mon, dt.day,
         currentBalance,
         (dayPL >= 0 ? "+" : ""),
         dayPL,
         dayPLPercent,
         dailyTrades,
         maxDrawdownToday
      );

      SendNotification_All(reportMsg);

      //--- Reset denných počítadiel
      dailyStartBalance = currentBalance;
      dailyTrades = 0;
      dailyProfit = 0;
      maxDrawdownToday = 0;
   }
}

//+------------------------------------------------------------------+
//| KONTROLA DRAWDOWN ALERTU                                         |
//| Upozorní keď drawdown prekročí nastavenú úroveň                  |
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

   //--- Alert ak drawdown prekročí varovnú úroveň
   static datetime lastDDAlert = 0;
   if(currentDD >= InpAlertDrawdown && TimeCurrent() - lastDDAlert > 3600) // Max 1 alert za hodinu
   {
      lastDDAlert = TimeCurrent();

      string ddMsg = StringFormat(
         "⚠️ DRAWDOWN ALERT!\n" +
         "━━━━━━━━━━━━━━━\n" +
         "Aktuálny DD: %.2f%%\n" +
         "Max povolený: %.2f%%\n" +
         "Zostatok: $%.2f\n" +
         "Equity: $%.2f\n" +
         "Strata: $%.2f\n" +
         "━━━━━━━━━━━━━━━",
         currentDD,
         InpMaxDrawdownPct,
         balance,
         equity,
         balance - equity
      );

      SendNotification_All(ddMsg);
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

   string tradeMsg = StringFormat(
      "📈 NOVÝ OBCHOD\n" +
      "Typ: %s\n" +
      "Úroveň: %d\n" +
      "Loty: %.2f\n" +
      "Cena: %.5f\n" +
      "Celkom pozícií: %d",
      type,
      level,
      lots,
      price,
      GetPositionCount()
   );

   SendNotification_All(tradeMsg);
}

//+------------------------------------------------------------------+
//| NOTIFIKÁCIA PRI ZATVORENÍ VŠETKÝCH POZÍCIÍ                       |
//+------------------------------------------------------------------+
void NotifyTradeClose(string reason, double profit, int count)
{
   if(!InpNotifyProfit && !InpNotifyTrade)
      return;

   dailyProfit += profit;

   string emoji = (profit >= 0) ? "💰" : "📉";
   string closeMsg = StringFormat(
      "%s POZÍCIE ZATVORENÉ\n" +
      "━━━━━━━━━━━━━━━\n" +
      "Dôvod: %s\n" +
      "Pozícií: %d\n" +
      "Profit: %s$%.2f\n" +
      "Nový zostatok: $%.2f\n" +
      "━━━━━━━━━━━━━━━",
      emoji,
      reason,
      count,
      (profit >= 0 ? "+" : ""),
      profit,
      AccountInfoDouble(ACCOUNT_BALANCE)
   );

   SendNotification_All(closeMsg);
}

//+------------------------------------------------------------------+
//| POMOCNÁ FUNKCIA - TEXT DÔVODU DEINIT                             |
//+------------------------------------------------------------------+
string GetDeinitReasonText(int reason)
{
   switch(reason)
   {
      case REASON_PROGRAM:     return "EA zastavený";
      case REASON_REMOVE:      return "EA odstránený z grafu";
      case REASON_RECOMPILE:   return "EA prekompilovaný";
      case REASON_CHARTCHANGE: return "Zmena symbolu/timeframe";
      case REASON_CHARTCLOSE:  return "Graf zatvorený";
      case REASON_PARAMETERS:  return "Zmena parametrov";
      case REASON_ACCOUNT:     return "Zmena účtu";
      case REASON_TEMPLATE:    return "Aplikovaná šablóna";
      case REASON_INITFAILED:  return "Zlyhanie inicializácie";
      case REASON_CLOSE:       return "Terminál zatvorený";
      default:                 return "Neznámy dôvod";
   }
}

//+------------------------------------------------------------------+
//| ZVYŠOK KÓDU - OBCHODNÁ LOGIKA (ROVNAKÁ AKO V1)                   |
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
      Print("VAROVANIE: Maximálny drawdown dosiahnutý: ", drawdown, "%");
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
      Print("VAROVANIE: Max loty dosiahnuté: ", totalLots);
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
   string comment = "NoPain Grid L" + IntegerToString(level);
   if(orderType == ORDER_TYPE_BUY)
      result = trade.Buy(lotSize, symbol, price, 0, tp, comment);
   else
      result = trade.Sell(lotSize, symbol, price, 0, tp, comment);

   if(result)
   {
      string typeStr = (orderType == ORDER_TYPE_BUY) ? "BUY" : "SELL";
      Print("OTVORENÁ: ", typeStr, " L", level, " Lots:", lotSize, " @", price);
      NotifyTradeOpen(typeStr, level, lotSize, price);
   }
   else
   {
      Print("CHYBA: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
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
      Print("CIEĽOVÝ PROFIT: ", totalProfit, " >= ", targetProfit);
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

   Print("ZATVORENÉ ", closedCount, " pozícií | Dôvod: ", reason, " | Profit: ", closedProfit);
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
