//+------------------------------------------------------------------+
//|                                            Claude_Like_NoPain.mq5|
//|                                                                   |
//|  AUTO-OPTIMIZED GRID EA                                          |
//|  ======================                                           |
//|  - Automaticky vypočíta lot podľa zostatku účtu                  |
//|  - Optimalizované pre AUDCAD                                     |
//|  - Discord/Push/Email monitoring                                 |
//|                                                                   |
//|  STAČÍ SPUSTIŤ - všetko sa nastaví automaticky!                  |
//|                                                                   |
//|  VOLITEĽNÉ NASTAVENIE DISCORD:                                   |
//|  1. Vytvor Discord server alebo použi existujúci                 |
//|  2. Vytvor kanál pre notifikácie (napr. #trading-alerts)         |
//|  3. Klikni na ozubené koliesko pri kanáli -> Integrations        |
//|  4. Klikni "Create Webhook" a skopíruj URL                       |
//|  5. Zadaj URL do nastavení EA                                    |
//+------------------------------------------------------------------+
#property copyright "Claude Like NoPain - Auto Optimized"
#property version   "4.30"
#property description "Auto-optimized Grid EA pre AUDCAD"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| VSTUPNÉ PARAMETRE                                                 |
//+------------------------------------------------------------------+

//--- AUTO-OPTIMIZED NASTAVENIA (netreba meniť!)
input group "=== AUTO NASTAVENIA (netreba meniť) ==="
input bool     InpAutoLot        = true;          // AUTO LOT podľa zostatku (odporúčané)
input double   InpRiskPercent    = 2.0;           // Risk % na grid sériu (ak AutoLot=true)
input double   InpManualLot      = 0.01;          // Manuálny lot (ak AutoLot=false)

//--- OPTIMALIZOVANÉ HODNOTY PRE AUDCAD
input group "=== OPTIMALIZOVANÉ PRE AUDCAD ==="
input double   InpLotMultiplier  = 1.3;           // Násobič lotu (1.3 = konzervatívny)
input int      InpGridStepPips   = 25;            // Grid step v pipsoch (25 = bezpečnejší)
input int      InpMaxGridLevels  = 7;             // Max úrovní gridu (7 = ochrana)
input double   InpTakeProfitPips = 20;            // TP v pipsoch
input double   InpTotalTPPercent = 0.8;           // Celkový TP ako % zostatku

//--- RISK MANAGEMENT
input group "=== RIADENIE RIZIKA ==="
input double   InpMaxDrawdownPct = 15.0;          // Max drawdown % (15 = bezpečné)
input double   InpMaxLossAmount  = 0;             // Max strata v $ (0 = vypnuté, napr. 500)
input double   InpMaxSpreadPips  = 3.0;           // Max spread pre obchodovanie (0 = vypnuté)
input bool     InpUseBreakeven   = true;          // Posunúť na breakeven po dosiahnutí profitu
input double   InpBreakevenStart = 10.0;          // Aktivovať breakeven po X pipsoch profitu
input double   InpBreakevenOffset= 2.0;           // Offset od entry (2 = +2 pips nad breakeven)
input int      InpMagicNumber    = 2262642;       // Magické číslo

//--- TRAILING STOP & DYNAMIC TP
input group "=== TRAILING STOP & DYNAMIC TP ==="
input bool     InpUseTrailing    = true;          // Používať trailing stop
input double   InpTrailingStart  = 15.0;          // Aktivovať trailing po X pipsoch profitu
input double   InpTrailingStep   = 5.0;           // Trailing step v pipsoch
input bool     InpUseDynamicTP   = true;          // Dynamický TP podľa ATR (prepíše fixný TP)
input double   InpATRMultiplier  = 1.5;           // ATR násobič pre TP (1.5 = konzervatívny)
input int      InpATRPeriod      = 14;            // ATR perióda

//--- ČASOVÉ FILTRE (optimalizované pre AUDCAD)
input group "=== ČASOVÉ FILTRE ==="
input int      InpStartHour      = 0;             // Začiatok obchodovania
input int      InpEndHour        = 23;            // Koniec obchodovania
input bool     InpTradeFriday    = true;          // Obchodovať v piatok?

//--- VSTUPNÉ SIGNÁLY
input group "=== VSTUPNÉ SIGNÁLY ==="
input int      InpRSIPeriod      = 14;            // Perióda RSI
input int      InpRSIOverbought  = 65;            // RSI prekúpená (65 = citlivejšie)
input int      InpRSIOversold    = 35;            // RSI prepredaná (35 = citlivejšie)
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1;   // Časový rámec pre vstup

//--- MULTI-TIMEFRAME ANALÝZA
input group "=== MULTI-TIMEFRAME FILTER ==="
input bool     InpUseMTF         = true;          // Používať MTF filter (odporúčané)
input int      InpMTF_RSI_Period = 14;            // RSI perióda pre MTF
input int      InpMTF_TrendLevel = 50;            // Hranica pre určenie trendu (50 = neutrálny)

//--- DISCORD MONITORING
input group "=== DISCORD WEBHOOK ==="
input bool     InpUseDiscord     = true;          // Používať Discord notifikácie
input string   InpDiscordWebhook = "https://discord.com/api/webhooks/1456625827281109114/g_25SWqOMfYoiHKJUuJ2JMYl5-QTg_aqt9GHIEsQroNpHOF5Y5hGcp9Qv50lbcl4OhYT"; // Discord Webhook URL

//--- MT5 PUSH NOTIFIKÁCIE
input group "=== MT5 PUSH NOTIFIKÁCIE ==="
input bool     InpUsePush        = true;          // Používať MT5 Push notifikácie (nastav MetaQuotes ID v Options)

//--- EMAIL NOTIFIKÁCIE
input group "=== EMAIL NOTIFIKÁCIE ==="
input bool     InpUseEmail       = false;         // Používať Email notifikácie (nastav SMTP v Options)

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

//--- VIZUALIZÁCIA
input group "=== VIZUALIZÁCIA ==="
input bool     InpShowPanel      = true;          // Zobraziť info panel na grafe
input color    InpPanelColor     = clrDarkSlateGray; // Farba pozadia panelu
input color    InpTextColor      = clrWhite;      // Farba textu

//+------------------------------------------------------------------+
//| GLOBÁLNE PREMENNÉ                                                 |
//+------------------------------------------------------------------+
CTrade         trade;
int            handleRSI;
int            handleATR;
double         gridStep;
double         point;
string         g_symbol = "AUDCAD";
double         initialBalance;
double         currentATR = 0;
double         trailingStopPrice = 0;

//--- MTF RSI handles
int            handleRSI_D1;           // Denný RSI
int            handleRSI_H4;           // 4-hodinový RSI
int            handleRSI_H1;           // Hodinový RSI (záložný ak iný TF)
double         rsi_D1 = 50;            // Aktuálna D1 RSI hodnota
double         rsi_H4 = 50;            // Aktuálna H4 RSI hodnota
double         rsi_H1 = 50;            // Aktuálna H1 RSI hodnota
int            mtfTrend = 0;           // MTF trend: 1=bullish, -1=bearish, 0=neutral
bool           breakevenActivated = false;  // Či bol breakeven už aktivovaný
double         currentSpread = 0;      // Aktuálny spread v pipsoch

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
   if(!SymbolSelect(g_symbol, true))
   {
      Print("CHYBA: Symbol ", g_symbol, " nie je dostupný!");
      return(INIT_FAILED);
   }

   //--- Nastavenie trade objektu
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(30);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   //--- Výpočet hodnôt
   point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   if(digits == 3 || digits == 5)
      gridStep = InpGridStepPips * 10 * point;
   else
      gridStep = InpGridStepPips * point;

   //--- RSI indikátor
   handleRSI = iRSI(g_symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   if(handleRSI == INVALID_HANDLE)
   {
      Print("CHYBA: Nepodarilo sa vytvoriť RSI indikátor!");
      return(INIT_FAILED);
   }

   //--- ATR indikátor pre dynamický TP
   handleATR = iATR(g_symbol, InpTimeframe, InpATRPeriod);
   if(handleATR == INVALID_HANDLE)
   {
      Print("CHYBA: Nepodarilo sa vytvoriť ATR indikátor!");
      return(INIT_FAILED);
   }

   //--- MTF RSI indikátory
   if(InpUseMTF)
   {
      handleRSI_D1 = iRSI(g_symbol, PERIOD_D1, InpMTF_RSI_Period, PRICE_CLOSE);
      handleRSI_H4 = iRSI(g_symbol, PERIOD_H4, InpMTF_RSI_Period, PRICE_CLOSE);
      handleRSI_H1 = iRSI(g_symbol, PERIOD_H1, InpMTF_RSI_Period, PRICE_CLOSE);

      if(handleRSI_D1 == INVALID_HANDLE || handleRSI_H4 == INVALID_HANDLE || handleRSI_H1 == INVALID_HANDLE)
      {
         Print("VAROVANIE: Nepodarilo sa vytvoriť MTF RSI indikátory, MTF filter vypnutý");
      }
      else
      {
         Print("MTF RSI inicializované: D1, H4, H1");
      }
   }

   //--- Inicializácia
   initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   dailyStartBalance = initialBalance;
   ArrayResize(buyGrid, InpMaxGridLevels);
   ArrayResize(sellGrid, InpMaxGridLevels);

   //--- Notifikácia o štarte
   if(InpNotifyStart)
   {
      double autoLot = CalculateLotSize(0);
      string lotMode = InpAutoLot ? "AUTO" : "MANUAL";
      string startMsg =
         "[OK] EA SPUSTENY - " + g_symbol + " | " +
         "Zostatok: $" + DoubleToString(initialBalance, 2) + " | " +
         "Lot: " + lotMode + " " + DoubleToString(autoLot, 2) + " | " +
         "Grid: " + IntegerToString(InpGridStepPips) + "pips x " + IntegerToString(InpMaxGridLevels) + " | " +
         "Risk: " + DoubleToString(InpRiskPercent, 1) + "% | " +
         "Max DD: " + DoubleToString(InpMaxDrawdownPct, 1) + "%";
      SendNotification_All("EA SPUSTENÝ", startMsg);
   }

   Print("Claude Like NoPain EA v4.30 - SPREAD + EQUITY + BE + MTF + TRAILING - inicializovaný");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| DEINICIALIZÁCIA                                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Odstráň panel
   DeleteInfoPanel();

   if(handleRSI != INVALID_HANDLE)
      IndicatorRelease(handleRSI);
   if(handleATR != INVALID_HANDLE)
      IndicatorRelease(handleATR);
   if(handleRSI_D1 != INVALID_HANDLE)
      IndicatorRelease(handleRSI_D1);
   if(handleRSI_H4 != INVALID_HANDLE)
      IndicatorRelease(handleRSI_H4);
   if(handleRSI_H1 != INVALID_HANDLE)
      IndicatorRelease(handleRSI_H1);

   //--- Notifikácia o zastavení
   if(InpNotifyStart)
   {
      double sessionPL = AccountInfoDouble(ACCOUNT_BALANCE) - initialBalance;
      string stopMsg =
         "[STOP] EA ZASTAVENY | " +
         "Dovod: " + GetDeinitReasonText(reason) + " | " +
         "Zostatok: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2) + " | " +
         "Session: " + (sessionPL >= 0 ? "+" : "") + DoubleToString(sessionPL, 2) + "$ | " +
         "Obchodov: " + IntegerToString(totalTradesSession);
      SendNotification_All("EA ZASTAVENÝ", stopMsg);
   }
}

//+------------------------------------------------------------------+
//| HLAVNÁ FUNKCIA                                                    |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Vizualizácia
   DrawInfoPanel();
   DrawGridLevels();

   //--- Aktualizuj ATR hodnotu
   UpdateATR();

   //--- Aktualizuj MTF hodnoty
   UpdateMTF();

   //--- Monitoring kontroly
   CheckHeartbeat();
   CheckDailyReport();
   CheckDrawdownAlert();

   //--- Obchodná logika
   if(!IsTradingTime())
      return;

   //--- Kontrola spread
   CheckSpread();  // Aktualizuje currentSpread pre panel

   //--- Kontrola drawdown (%)
   if(CheckDrawdown())
   {
      CloseAllPositions("Max Drawdown");
      return;
   }

   //--- Kontrola equity protection ($)
   if(CheckEquityProtection())
   {
      CloseAllPositions("Equity Protection");
      return;
   }

   UpdateGridInfo();

   //--- Breakeven management (pred trailing)
   if(InpUseBreakeven && (buyLevels > 0 || sellLevels > 0))
   {
      ManageBreakeven();
   }

   //--- Trailing stop management
   if(InpUseTrailing && (buyLevels > 0 || sellLevels > 0))
   {
      ManageTrailingStop();
   }

   if(CheckTotalProfit())
   {
      CloseAllPositions("Target Profit");
      return;
   }

   int signal = GetSignal();

   if(buyLevels == 0 && sellLevels == 0)
   {
      //--- Spread filter pre nové obchody
      if(!CheckSpread())
      {
         // Spread príliš vysoký, neotváraj nové pozície
         return;
      }

      if(signal == 1)
         OpenGridPosition(ORDER_TYPE_BUY, 0);
      else if(signal == -1)
         OpenGridPosition(ORDER_TYPE_SELL, 0);
   }
   else
   {
      //--- Grid pozície - spread filter pre ďalšie úrovne
      if(CheckSpread())
      {
         ManageGrid();
      }
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
         "[HEARTBEAT] " + TimeToString(currentTime, TIME_DATE|TIME_MINUTES) + " | " +
         "Bal: $" + DoubleToString(balance, 2) + " | " +
         "Eq: $" + DoubleToString(equity, 2) + " | " +
         "Float: " + (floatingPL >= 0 ? "+" : "") + DoubleToString(floatingPL, 2) + "$ | " +
         "DD: " + DoubleToString(currentDD, 2) + "% | " +
         "Pos: " + IntegerToString(openPositions);

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

      string reportMsg =
         "[DAILY] " + IntegerToString(dt.year) + "-" +
                      StringFormat("%02d", dt.mon) + "-" +
                      StringFormat("%02d", dt.day) + " | " +
         "Bal: $" + DoubleToString(currentBalance, 2) + " | " +
         "P/L: " + (dayPL >= 0 ? "+" : "") + DoubleToString(dayPL, 2) +
                   "$ (" + DoubleToString(dayPLPercent, 2) + "%) | " +
         "Trades: " + IntegerToString(dailyTrades) + " | " +
         "Max DD: " + DoubleToString(maxDrawdownToday, 2) + "%";

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
         "[WARNING] DRAWDOWN " + DoubleToString(currentDD, 2) + "% | " +
         "Max: " + DoubleToString(InpMaxDrawdownPct, 1) + "% | " +
         "Bal: $" + DoubleToString(balance, 2) + " | " +
         "Eq: $" + DoubleToString(equity, 2) + " | " +
         "Loss: $" + DoubleToString(balance - equity, 2);

      SendNotification_All("DRAWDOWN ALERT", ddMsg);
   }
}

//+------------------------------------------------------------------+
//| AKTUALIZÁCIA ATR HODNOTY                                         |
//+------------------------------------------------------------------+
void UpdateATR()
{
   double atr[];
   ArraySetAsSeries(atr, true);
   if(CopyBuffer(handleATR, 0, 0, 1, atr) > 0)
      currentATR = atr[0];
}

//+------------------------------------------------------------------+
//| AKTUALIZÁCIA MTF RSI HODNÔT                                      |
//+------------------------------------------------------------------+
void UpdateMTF()
{
   if(!InpUseMTF)
      return;

   double rsi[];
   ArraySetAsSeries(rsi, true);

   //--- D1 RSI
   if(handleRSI_D1 != INVALID_HANDLE && CopyBuffer(handleRSI_D1, 0, 0, 1, rsi) > 0)
      rsi_D1 = rsi[0];

   //--- H4 RSI
   if(handleRSI_H4 != INVALID_HANDLE && CopyBuffer(handleRSI_H4, 0, 0, 1, rsi) > 0)
      rsi_H4 = rsi[0];

   //--- H1 RSI
   if(handleRSI_H1 != INVALID_HANDLE && CopyBuffer(handleRSI_H1, 0, 0, 1, rsi) > 0)
      rsi_H1 = rsi[0];

   //--- Analyzuj celkový MTF trend
   AnalyzeMTFTrend();
}

//+------------------------------------------------------------------+
//| ANALÝZA MTF TRENDU                                               |
//| Kombinácia D1, H4, H1 RSI pre určenie hlavného trendu            |
//| Váhy: D1 = 50%, H4 = 30%, H1 = 20%                               |
//+------------------------------------------------------------------+
void AnalyzeMTFTrend()
{
   //--- Počítadlá pre bullish/bearish signály
   int bullishScore = 0;
   int bearishScore = 0;

   //--- D1 (najdôležitejší - určuje hlavný trend)
   //--- Váha: 3 body
   if(rsi_D1 > InpMTF_TrendLevel + 5)       // RSI > 55 = bullish
      bullishScore += 3;
   else if(rsi_D1 < InpMTF_TrendLevel - 5)  // RSI < 45 = bearish
      bearishScore += 3;

   //--- H4 (stredne dôležitý - potvrdenie trendu)
   //--- Váha: 2 body
   if(rsi_H4 > InpMTF_TrendLevel + 3)       // RSI > 53 = bullish
      bullishScore += 2;
   else if(rsi_H4 < InpMTF_TrendLevel - 3)  // RSI < 47 = bearish
      bearishScore += 2;

   //--- H1 (najmenej dôležitý - krátkodobý sentiment)
   //--- Váha: 1 bod
   if(rsi_H1 > InpMTF_TrendLevel)           // RSI > 50 = bullish
      bullishScore += 1;
   else if(rsi_H1 < InpMTF_TrendLevel)      // RSI < 50 = bearish
      bearishScore += 1;

   //--- Určenie trendu
   //--- Potrebujeme aspoň 4 body pre jasný trend (z max 6)
   if(bullishScore >= 4 && bullishScore > bearishScore)
      mtfTrend = 1;   // BULLISH - preferuj BUY
   else if(bearishScore >= 4 && bearishScore > bullishScore)
      mtfTrend = -1;  // BEARISH - preferuj SELL
   else
      mtfTrend = 0;   // NEUTRAL - obchoduj oboje
}

//+------------------------------------------------------------------+
//| KONTROLA SPREADU                                                  |
//| Vracia true ak je spread OK pre obchodovanie                     |
//+------------------------------------------------------------------+
bool CheckSpread()
{
   if(InpMaxSpreadPips <= 0)
      return true;  // Spread filter vypnutý

   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double spreadPoints = ask - bid;

   int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1;

   currentSpread = spreadPoints / point / pipMultiplier;

   if(currentSpread > InpMaxSpreadPips)
   {
      return false;  // Spread príliš vysoký
   }

   return true;
}

//+------------------------------------------------------------------+
//| KONTROLA ABSOLÚTNEJ STRATY                                       |
//| Ochrana equity - max strata v dolároch                          |
//+------------------------------------------------------------------+
bool CheckEquityProtection()
{
   if(InpMaxLossAmount <= 0)
      return false;  // Equity protection vypnutá

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double currentLoss = initialBalance - equity;

   if(currentLoss >= InpMaxLossAmount)
   {
      Print("EQUITY PROTECTION: Strata $", DoubleToString(currentLoss, 2), " >= Max $", DoubleToString(InpMaxLossAmount, 2));
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| BREAKEVEN MANAGEMENT                                              |
//| Posunie SL na breakeven + offset keď dosiahne určitý profit      |
//+------------------------------------------------------------------+
void ManageBreakeven()
{
   if(!InpUseBreakeven || breakevenActivated)
      return;

   int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1;
   double breakevenStartPips = InpBreakevenStart * pipMultiplier * point;
   double breakevenOffsetPips = InpBreakevenOffset * pipMultiplier * point;

   double avgPrice = 0;
   double totalLots = 0;

   //--- BUY pozície
   if(buyLevels > 0)
   {
      for(int i = 0; i < buyLevels; i++)
      {
         avgPrice += buyGrid[i].openPrice * buyGrid[i].lots;
         totalLots += buyGrid[i].lots;
      }
      if(totalLots > 0)
         avgPrice /= totalLots;

      double currentBid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
      double profitPips = currentBid - avgPrice;

      //--- Aktivuj breakeven
      if(profitPips >= breakevenStartPips)
      {
         double breakevenPrice = avgPrice + breakevenOffsetPips;
         breakevenActivated = true;
         trailingStopPrice = breakevenPrice;  // Nastav trailing na breakeven úroveň
         Print("BREAKEVEN ACTIVATED BUY: BE @ ", DoubleToString(breakevenPrice, digits),
               " | Avg: ", DoubleToString(avgPrice, digits),
               " | Profit: ", DoubleToString(profitPips / pipMultiplier / point, 1), " pips");
      }
   }
   //--- SELL pozície
   else if(sellLevels > 0)
   {
      for(int i = 0; i < sellLevels; i++)
      {
         avgPrice += sellGrid[i].openPrice * sellGrid[i].lots;
         totalLots += sellGrid[i].lots;
      }
      if(totalLots > 0)
         avgPrice /= totalLots;

      double currentAsk = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
      double profitPips = avgPrice - currentAsk;

      //--- Aktivuj breakeven
      if(profitPips >= breakevenStartPips)
      {
         double breakevenPrice = avgPrice - breakevenOffsetPips;
         breakevenActivated = true;
         trailingStopPrice = breakevenPrice;  // Nastav trailing na breakeven úroveň
         Print("BREAKEVEN ACTIVATED SELL: BE @ ", DoubleToString(breakevenPrice, digits),
               " | Avg: ", DoubleToString(avgPrice, digits),
               " | Profit: ", DoubleToString(profitPips / pipMultiplier / point, 1), " pips");
      }
   }
}

//+------------------------------------------------------------------+
//| VÝPOČET DYNAMICKÉHO TP PODĽA ATR                                 |
//+------------------------------------------------------------------+
double GetDynamicTP()
{
   if(!InpUseDynamicTP || currentATR == 0)
   {
      //--- Použij fixný TP
      int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
      return InpTakeProfitPips * ((digits == 3 || digits == 5) ? 10 : 1) * point;
   }

   //--- Dynamický TP = ATR * násobič
   return currentATR * InpATRMultiplier;
}

//+------------------------------------------------------------------+
//| TRAILING STOP MANAGEMENT                                          |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!InpUseTrailing)
      return;

   int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1;
   double trailingStartPips = InpTrailingStart * pipMultiplier * point;
   double trailingStepPips = InpTrailingStep * pipMultiplier * point;

   double totalProfit = GetTotalProfit();
   double avgPrice = 0;
   double totalLots = 0;

   //--- Vypočítaj priemernú cenu
   if(buyLevels > 0)
   {
      for(int i = 0; i < buyLevels; i++)
      {
         avgPrice += buyGrid[i].openPrice * buyGrid[i].lots;
         totalLots += buyGrid[i].lots;
      }
      if(totalLots > 0)
         avgPrice /= totalLots;

      double currentBid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
      double profitPips = currentBid - avgPrice;

      //--- Aktivuj trailing ak profit >= trailingStart
      if(profitPips >= trailingStartPips)
      {
         double newTrailingStop = currentBid - trailingStepPips;

         //--- Ak ešte nemáme trailing alebo máme lepší
         if(trailingStopPrice == 0 || newTrailingStop > trailingStopPrice)
         {
            trailingStopPrice = newTrailingStop;
            Print("TRAILING UPDATE BUY: Stop @ ", DoubleToString(trailingStopPrice, digits), " | Profit: ", DoubleToString(profitPips / pipMultiplier / point, 1), " pips");
         }

         //--- Ak cena klesla pod trailing stop, zatvor všetko
         if(currentBid <= trailingStopPrice)
         {
            Print("TRAILING STOP HIT @ ", DoubleToString(currentBid, digits));
            CloseAllPositions("Trailing Stop");
            trailingStopPrice = 0;
            return;
         }
      }
   }
   else if(sellLevels > 0)
   {
      for(int i = 0; i < sellLevels; i++)
      {
         avgPrice += sellGrid[i].openPrice * sellGrid[i].lots;
         totalLots += sellGrid[i].lots;
      }
      if(totalLots > 0)
         avgPrice /= totalLots;

      double currentAsk = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
      double profitPips = avgPrice - currentAsk;

      //--- Aktivuj trailing ak profit >= trailingStart
      if(profitPips >= trailingStartPips)
      {
         double newTrailingStop = currentAsk + trailingStepPips;

         //--- Ak ešte nemáme trailing alebo máme lepší
         if(trailingStopPrice == 0 || newTrailingStop < trailingStopPrice)
         {
            trailingStopPrice = newTrailingStop;
            Print("TRAILING UPDATE SELL: Stop @ ", DoubleToString(trailingStopPrice, digits), " | Profit: ", DoubleToString(profitPips / pipMultiplier / point, 1), " pips");
         }

         //--- Ak cena stúpla nad trailing stop, zatvor všetko
         if(currentAsk >= trailingStopPrice)
         {
            Print("TRAILING STOP HIT @ ", DoubleToString(currentAsk, digits));
            CloseAllPositions("Trailing Stop");
            trailingStopPrice = 0;
            return;
         }
      }
   }
   else
   {
      //--- Žiadne pozície, resetuj trailing
      trailingStopPrice = 0;
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
      "[TRADE] " + type + " L" + IntegerToString(level) + " | " +
      "Lots: " + DoubleToString(lots, 2) + " | " +
      "Price: " + DoubleToString(price, 5) + " | " +
      "Positions: " + IntegerToString(GetPositionCount());

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

   string closeMsg =
      "[CLOSE] " + reason + " | " +
      "Positions: " + IntegerToString(count) + " | " +
      "Profit: " + (profit >= 0 ? "+" : "") + DoubleToString(profit, 2) + "$ | " +
      "Balance: $" + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);

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

   int signal = 0;

   //--- Základný RSI signál
   if(rsi[1] < InpRSIOversold && rsi[0] >= InpRSIOversold) signal = 1;
   else if(rsi[0] < InpRSIOversold) signal = 1;
   else if(rsi[1] > InpRSIOverbought && rsi[0] <= InpRSIOverbought) signal = -1;
   else if(rsi[0] > InpRSIOverbought) signal = -1;

   //--- MTF filter
   if(InpUseMTF && signal != 0)
   {
      //--- Ak MTF trend je bullish, blokuj SELL signály
      if(mtfTrend == 1 && signal == -1)
      {
         Print("MTF FILTER: SELL signál blokovaný (D1:", DoubleToString(rsi_D1, 1),
               " H4:", DoubleToString(rsi_H4, 1), " H1:", DoubleToString(rsi_H1, 1), " = BULLISH)");
         return 0;
      }
      //--- Ak MTF trend je bearish, blokuj BUY signály
      else if(mtfTrend == -1 && signal == 1)
      {
         Print("MTF FILTER: BUY signál blokovaný (D1:", DoubleToString(rsi_D1, 1),
               " H4:", DoubleToString(rsi_H4, 1), " H1:", DoubleToString(rsi_H1, 1), " = BEARISH)");
         return 0;
      }
      //--- mtfTrend == 0 (neutral) - povolí oba smery
   }

   return signal;
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
      if(PositionGetString(POSITION_SYMBOL) != g_symbol) continue;
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
   //--- Dynamický max lot limit (10% zostatku v margin)
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double maxTotalLots = balance / 1000.0;  // Cca 10% marginu pri páke 1:500
   double totalLots = GetTotalLots() + lotSize;
   if(totalLots > maxTotalLots)
   {
      Print("MAX LOTY dosiahnuté: ", totalLots, " > ", maxTotalLots);
      return false;
   }

   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
   double price = (orderType == ORDER_TYPE_BUY) ? ask : bid;

   double tp = 0;
   int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   //--- Použi dynamický TP podľa ATR alebo fixný
   double tpDistance = GetDynamicTP();
   if(orderType == ORDER_TYPE_BUY) tp = price + tpDistance;
   else tp = price - tpDistance;

   bool result = false;
   string comment = "NoPain L" + IntegerToString(level);
   if(orderType == ORDER_TYPE_BUY)
      result = trade.Buy(lotSize, g_symbol, price, 0, tp, comment);
   else
      result = trade.Sell(lotSize, g_symbol, price, 0, tp, comment);

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
   double baseLot;

   if(InpAutoLot)
   {
      //--- AUTO LOT: vypočítaj podľa zostatku a rizika
      //--- Pre AUDCAD s pákou 1:500, grid 7 úrovní
      //--- Vzorec: (balance * risk%) / (maxGridDrawdownPips * pipValue * lotMultiplierSum)
      double balance = AccountInfoDouble(ACCOUNT_BALANCE);
      double pipValue = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);

      //--- Suma násobičov pre všetky úrovne (1 + 1.3 + 1.69 + ...)
      double multiplierSum = 0;
      double mult = 1.0;
      for(int i = 0; i < InpMaxGridLevels; i++)
      {
         multiplierSum += mult;
         mult *= InpLotMultiplier;
      }

      //--- Max potenciálny DD v pipsoch (všetky úrovne otvorené)
      double maxDDPips = InpGridStepPips * InpMaxGridLevels;

      //--- Bezpečný base lot
      baseLot = (balance * InpRiskPercent / 100.0) / (maxDDPips * pipValue * multiplierSum);

      //--- Pre páku 1:500 na IC Markets, min lot 0.01
      baseLot = MathMax(0.01, baseLot);
   }
   else
   {
      baseLot = InpManualLot;
   }

   //--- Aplikuj násobič pre aktuálnu úroveň
   double lots = baseLot;
   for(int i = 0; i < level; i++) lots *= InpLotMultiplier;

   //--- Normalizuj na povolené hodnoty
   double minLot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);
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
      if(PositionGetString(POSITION_SYMBOL) != g_symbol) continue;
      totalLots += PositionGetDouble(POSITION_VOLUME);
   }
   return totalLots;
}

void ManageGrid()
{
   double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);

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
      if(PositionGetString(POSITION_SYMBOL) != g_symbol) continue;
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
      if(PositionGetString(POSITION_SYMBOL) != g_symbol) continue;
      closedProfit += PositionGetDouble(POSITION_PROFIT);
      closedProfit += PositionGetDouble(POSITION_SWAP);
      if(trade.PositionClose(ticket)) closedCount++;
   }

   //--- Reset breakeven flag pre ďalšiu sériu
   breakevenActivated = false;

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
      if(PositionGetString(POSITION_SYMBOL) != g_symbol) continue;
      count++;
   }
   return count;
}

//+------------------------------------------------------------------+
//| VIZUALIZÁCIA - INFO PANEL NA GRAFE                               |
//+------------------------------------------------------------------+
void DrawInfoPanel()
{
   if(!InpShowPanel)
      return;

   string prefix = "NoPain_";
   int x = 10;
   int y = 30;
   int lineHeight = 18;
   int line = 0;

   //--- Získaj aktuálne hodnoty
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double floatingPL = equity - balance;
   double drawdown = (balance > 0) ? ((balance - equity) / balance * 100) : 0;
   double totalProfit = GetTotalProfit();
   double sessionPL = balance - initialBalance;

   //--- RSI hodnota
   double rsi[];
   ArraySetAsSeries(rsi, true);
   double rsiValue = 0;
   if(CopyBuffer(handleRSI, 0, 0, 1, rsi) > 0)
      rsiValue = rsi[0];

   //--- Stav signálu
   string signalText = "CAKAM";
   color signalColor = clrGray;
   if(rsiValue < InpRSIOversold)
   {
      signalText = "BUY SIGNAL";
      signalColor = clrLime;
   }
   else if(rsiValue > InpRSIOverbought)
   {
      signalText = "SELL SIGNAL";
      signalColor = clrRed;
   }

   //--- Stav gridu
   string gridStatus = "";
   color gridColor = clrWhite;
   if(buyLevels > 0)
   {
      gridStatus = "BUY GRID L" + IntegerToString(buyLevels);
      gridColor = clrDodgerBlue;
   }
   else if(sellLevels > 0)
   {
      gridStatus = "SELL GRID L" + IntegerToString(sellLevels);
      gridColor = clrOrangeRed;
   }
   else
   {
      gridStatus = "ZIADEN GRID";
      gridColor = clrGray;
   }

   //--- Farba drawdownu
   color ddColor = clrLime;
   if(drawdown > 5) ddColor = clrYellow;
   if(drawdown > 10) ddColor = clrOrange;
   if(drawdown > InpAlertDrawdown) ddColor = clrRed;

   //--- Vytvor pozadie panelu
   string bgName = prefix + "BG";
   if(ObjectFind(0, bgName) < 0)
      ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x - 5);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y - 5);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 220);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, lineHeight * 23 + 10);  // Zväčšené pre spread, BE, MTF
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, InpPanelColor);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, bgName, OBJPROP_BACK, false);

   //--- Nadpis
   CreateLabel(prefix + "Title", x, y + line * lineHeight, "=== CLAUDE LIKE NOPAIN ===", clrGold, 9, true);
   line++;

   //--- Separator
   CreateLabel(prefix + "Sep1", x, y + line * lineHeight, "------------------------", clrGray, 8, false);
   line++;

   //--- Account info
   CreateLabel(prefix + "Balance", x, y + line * lineHeight, "Zostatok:  $" + DoubleToString(balance, 2), InpTextColor, 8, false);
   line++;
   CreateLabel(prefix + "Equity", x, y + line * lineHeight, "Equity:    $" + DoubleToString(equity, 2), InpTextColor, 8, false);
   line++;
   CreateLabel(prefix + "Floating", x, y + line * lineHeight, "Floating:  " + (floatingPL >= 0 ? "+" : "") + DoubleToString(floatingPL, 2) + "$", floatingPL >= 0 ? clrLime : clrRed, 8, false);
   line++;
   CreateLabel(prefix + "Drawdown", x, y + line * lineHeight, "Drawdown:  " + DoubleToString(drawdown, 2) + "%", ddColor, 8, false);
   line++;

   //--- Spread info
   color spreadColor = clrLime;
   if(InpMaxSpreadPips > 0)
   {
      if(currentSpread > InpMaxSpreadPips * 0.8) spreadColor = clrYellow;
      if(currentSpread > InpMaxSpreadPips) spreadColor = clrRed;
   }
   string spreadText = "Spread:    " + DoubleToString(currentSpread, 1) + " pips";
   if(InpMaxSpreadPips > 0)
      spreadText += " (max " + DoubleToString(InpMaxSpreadPips, 1) + ")";
   CreateLabel(prefix + "Spread", x, y + line * lineHeight, spreadText, spreadColor, 8, false);
   line++;

   //--- Separator
   CreateLabel(prefix + "Sep2", x, y + line * lineHeight, "------------------------", clrGray, 8, false);
   line++;

   //--- Grid info
   CreateLabel(prefix + "GridStatus", x, y + line * lineHeight, "Grid:      " + gridStatus, gridColor, 8, false);
   line++;
   CreateLabel(prefix + "Positions", x, y + line * lineHeight, "Pozicie:   " + IntegerToString(buyLevels + sellLevels) + "/" + IntegerToString(InpMaxGridLevels), InpTextColor, 8, false);
   line++;
   CreateLabel(prefix + "BaseLot", x, y + line * lineHeight, "Base Lot:  " + DoubleToString(CalculateLotSize(0), 2), InpTextColor, 8, false);
   line++;

   //--- Separator
   CreateLabel(prefix + "Sep3", x, y + line * lineHeight, "------------------------", clrGray, 8, false);
   line++;

   //--- Signal info
   CreateLabel(prefix + "RSI", x, y + line * lineHeight, "RSI(" + IntegerToString(InpRSIPeriod) + "): " + DoubleToString(rsiValue, 1), InpTextColor, 8, false);
   line++;
   CreateLabel(prefix + "Signal", x, y + line * lineHeight, "Signal:    " + signalText, signalColor, 8, true);
   line++;

   //--- ATR & Trailing info
   int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
   double pipMultiplier = (digits == 3 || digits == 5) ? 10 : 1;
   double atrPips = (point > 0) ? (currentATR / point / pipMultiplier) : 0;
   double dynamicTPPips = (point > 0) ? (GetDynamicTP() / point / pipMultiplier) : 0;

   string atrText = "ATR:       " + DoubleToString(atrPips, 1) + " pips";
   CreateLabel(prefix + "ATR", x, y + line * lineHeight, atrText, clrAqua, 8, false);
   line++;

   string tpText = "Dyn TP:    " + DoubleToString(dynamicTPPips, 1) + " pips";
   CreateLabel(prefix + "DynTP", x, y + line * lineHeight, tpText, InpUseDynamicTP ? clrLime : clrGray, 8, false);
   line++;

   //--- Breakeven status
   string beText = "Breakeven: ";
   color beColor = clrGray;
   if(breakevenActivated)
   {
      beText += "AKTIVNY";
      beColor = clrLime;
   }
   else if(InpUseBreakeven)
   {
      beText += "Caka na +" + DoubleToString(InpBreakevenStart, 0) + "pips";
      beColor = clrGray;
   }
   else
   {
      beText += "Vypnuty";
   }
   CreateLabel(prefix + "BE", x, y + line * lineHeight, beText, beColor, 8, false);
   line++;

   //--- Trailing stop status
   string trailText = "Trailing:  ";
   color trailColor = clrGray;
   if(trailingStopPrice > 0)
   {
      trailText += DoubleToString(trailingStopPrice, digits);
      trailColor = clrYellow;
   }
   else if(InpUseTrailing)
   {
      trailText += "Caka na +" + DoubleToString(InpTrailingStart, 0) + "pips";
      trailColor = clrGray;
   }
   else
   {
      trailText += "Vypnuty";
   }
   CreateLabel(prefix + "Trail", x, y + line * lineHeight, trailText, trailColor, 8, false);
   line++;

   //--- Separator
   CreateLabel(prefix + "Sep4", x, y + line * lineHeight, "------------------------", clrGray, 8, false);
   line++;

   //--- MTF Status
   string mtfText = "MTF:       ";
   color mtfColor = clrGray;
   if(InpUseMTF)
   {
      if(mtfTrend == 1)
      {
         mtfText += "BULLISH (BUY only)";
         mtfColor = clrLime;
      }
      else if(mtfTrend == -1)
      {
         mtfText += "BEARISH (SELL only)";
         mtfColor = clrOrangeRed;
      }
      else
      {
         mtfText += "NEUTRAL (all)";
         mtfColor = clrYellow;
      }
   }
   else
   {
      mtfText += "Vypnuty";
   }
   CreateLabel(prefix + "MTF", x, y + line * lineHeight, mtfText, mtfColor, 8, false);
   line++;

   //--- MTF RSI hodnoty
   if(InpUseMTF)
   {
      string mtfRSI = "D1:" + DoubleToString(rsi_D1, 0) + " H4:" + DoubleToString(rsi_H4, 0) + " H1:" + DoubleToString(rsi_H1, 0);
      CreateLabel(prefix + "MTFRSI", x, y + line * lineHeight, "RSI MTF:   " + mtfRSI, clrAqua, 8, false);
      line++;
   }

   //--- Session P/L
   CreateLabel(prefix + "Session", x, y + line * lineHeight, "Session:   " + (sessionPL >= 0 ? "+" : "") + DoubleToString(sessionPL, 2) + "$", sessionPL >= 0 ? clrLime : clrRed, 8, false);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| POMOCNÁ FUNKCIA - VYTVORENIE LABELU                              |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize, bool bold)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| ODSTRÁNENIE PANELU                                               |
//+------------------------------------------------------------------+
void DeleteInfoPanel()
{
   string prefix = "NoPain_";
   ObjectsDeleteAll(0, prefix);
}

//+------------------------------------------------------------------+
//| KRESLENIE GRID ÚROVNÍ NA GRAF                                    |
//+------------------------------------------------------------------+
void DrawGridLevels()
{
   if(!InpShowPanel)
      return;

   string prefix = "NoPain_Grid_";

   //--- Sleduj zmeny stavu aby sa zbytočne neprekresloval
   static int lastBuyLevels = -1;
   static int lastSellLevels = -1;
   static datetime lastUpdate = 0;

   //--- Aktualizuj len každú sekundu alebo pri zmene gridu
   datetime now = TimeCurrent();
   bool forceUpdate = (buyLevels != lastBuyLevels || sellLevels != lastSellLevels);

   if(!forceUpdate && now - lastUpdate < 1)
      return;

   lastUpdate = now;

   //--- Ak sa zmenil stav gridu, odstráň staré objekty
   if(forceUpdate)
   {
      ObjectsDeleteAll(0, prefix);
      lastBuyLevels = buyLevels;
      lastSellLevels = sellLevels;
   }

   //--- Ak nie sú žiadne pozície, nakresli potenciálne entry úrovne
   if(buyLevels == 0 && sellLevels == 0)
   {
      double currentPrice = SymbolInfoDouble(g_symbol, SYMBOL_BID);

      //--- Nakresli potenciálne BUY úrovne (dole)
      for(int i = 0; i < InpMaxGridLevels; i++)
      {
         double levelPrice = currentPrice - (i * gridStep);
         string lineName = prefix + "PotBuy_" + IntegerToString(i);
         CreateHLine(lineName, levelPrice, clrDodgerBlue, STYLE_DOT, 1);

         //--- Label pre úroveň
         string labelName = prefix + "LblBuy_" + IntegerToString(i);
         double lotAtLevel = CalculateLotSize(i);
         string desc = "BUY L" + IntegerToString(i) + " | " + DoubleToString(lotAtLevel, 2) + " lot";
         if(i == 0) desc += " (ENTRY)";
         CreatePriceLabel(labelName, levelPrice, desc, clrDodgerBlue);
      }

      //--- Nakresli potenciálne SELL úrovne (hore)
      for(int i = 0; i < InpMaxGridLevels; i++)
      {
         double levelPrice = currentPrice + (i * gridStep);
         string lineName = prefix + "PotSell_" + IntegerToString(i);
         CreateHLine(lineName, levelPrice, clrOrangeRed, STYLE_DOT, 1);

         string labelName = prefix + "LblSell_" + IntegerToString(i);
         double lotAtLevel = CalculateLotSize(i);
         string desc = "SELL L" + IntegerToString(i) + " | " + DoubleToString(lotAtLevel, 2) + " lot";
         if(i == 0) desc += " (ENTRY)";
         CreatePriceLabel(labelName, levelPrice, desc, clrOrangeRed, false);
      }
      return;
   }

   //--- Ak máme BUY grid
   if(buyLevels > 0)
   {
      //--- Nakresli otvorené pozície
      for(int i = 0; i < buyLevels; i++)
      {
         string lineName = prefix + "Buy_" + IntegerToString(i);
         CreateHLine(lineName, buyGrid[i].openPrice, clrDodgerBlue, STYLE_SOLID, 2);

         string labelName = prefix + "LblBuyOpen_" + IntegerToString(i);
         string lotText = "OPEN BUY L" + IntegerToString(i) + " | " + DoubleToString(buyGrid[i].lots, 2) + " lot @ " + DoubleToString(buyGrid[i].openPrice, 5);
         CreatePriceLabel(labelName, buyGrid[i].openPrice, lotText, clrDodgerBlue);
      }

      //--- Nakresli nasledujúcu grid úroveň (kde sa otvorí ďalšia pozícia)
      if(buyLevels < InpMaxGridLevels)
      {
         double lowestBuy = DBL_MAX;
         for(int i = 0; i < buyLevels; i++)
            if(buyGrid[i].openPrice < lowestBuy) lowestBuy = buyGrid[i].openPrice;

         double nextLevel = lowestBuy - gridStep;
         string lineName = prefix + "NextBuy";
         CreateHLine(lineName, nextLevel, clrAqua, STYLE_DASH, 1);

         string labelName = prefix + "LblNextBuy";
         double nextLot = CalculateLotSize(buyLevels);
         CreatePriceLabel(labelName, nextLevel, ">>> NEXT BUY L" + IntegerToString(buyLevels) + " | " + DoubleToString(nextLot, 2) + " lot (caka na cenu)", clrAqua);
      }

      //--- Nakresli TP úroveň (priemerná cena + TP)
      double avgPrice = 0;
      double totalLots = 0;
      for(int i = 0; i < buyLevels; i++)
      {
         avgPrice += buyGrid[i].openPrice * buyGrid[i].lots;
         totalLots += buyGrid[i].lots;
      }
      if(totalLots > 0)
      {
         avgPrice /= totalLots;
         int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
         double tpPips = InpTakeProfitPips * ((digits == 3 || digits == 5) ? 10 : 1) * point;
         double tpPrice = avgPrice + tpPips;
         double currentBid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
         double pipsToTP = (tpPrice - currentBid) / (point * ((digits == 3 || digits == 5) ? 10 : 1));

         string lineNameAvg = prefix + "AvgBuy";
         CreateHLine(lineNameAvg, avgPrice, clrYellow, STYLE_DASHDOT, 1);
         CreatePriceLabel(prefix + "LblAvgBuy", avgPrice, "PRIEMER (breakeven) | Total: " + DoubleToString(totalLots, 2) + " lot", clrYellow);

         string lineNameTP = prefix + "TPBuy";
         CreateHLine(lineNameTP, tpPrice, clrLime, STYLE_SOLID, 2);
         CreatePriceLabel(prefix + "LblTPBuy", tpPrice, "*** TAKE PROFIT *** | " + DoubleToString(pipsToTP, 1) + " pips to go", clrLime);
      }
   }

   //--- Ak máme SELL grid
   if(sellLevels > 0)
   {
      //--- Nakresli otvorené pozície
      for(int i = 0; i < sellLevels; i++)
      {
         string lineName = prefix + "Sell_" + IntegerToString(i);
         CreateHLine(lineName, sellGrid[i].openPrice, clrOrangeRed, STYLE_SOLID, 2);

         string labelName = prefix + "LblSellOpen_" + IntegerToString(i);
         string lotText = "OPEN SELL L" + IntegerToString(i) + " | " + DoubleToString(sellGrid[i].lots, 2) + " lot @ " + DoubleToString(sellGrid[i].openPrice, 5);
         CreatePriceLabel(labelName, sellGrid[i].openPrice, lotText, clrOrangeRed, false);
      }

      //--- Nakresli nasledujúcu grid úroveň
      if(sellLevels < InpMaxGridLevels)
      {
         double highestSell = 0;
         for(int i = 0; i < sellLevels; i++)
            if(sellGrid[i].openPrice > highestSell) highestSell = sellGrid[i].openPrice;

         double nextLevel = highestSell + gridStep;
         string lineName = prefix + "NextSell";
         CreateHLine(lineName, nextLevel, clrPink, STYLE_DASH, 1);

         string labelName = prefix + "LblNextSell";
         double nextLot = CalculateLotSize(sellLevels);
         CreatePriceLabel(labelName, nextLevel, ">>> NEXT SELL L" + IntegerToString(sellLevels) + " | " + DoubleToString(nextLot, 2) + " lot (caka na cenu)", clrPink, false);
      }

      //--- Nakresli TP úroveň
      double avgPrice = 0;
      double totalLots = 0;
      for(int i = 0; i < sellLevels; i++)
      {
         avgPrice += sellGrid[i].openPrice * sellGrid[i].lots;
         totalLots += sellGrid[i].lots;
      }
      if(totalLots > 0)
      {
         avgPrice /= totalLots;
         int digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);
         double tpPips = InpTakeProfitPips * ((digits == 3 || digits == 5) ? 10 : 1) * point;
         double tpPrice = avgPrice - tpPips;
         double currentAsk = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
         double pipsToTP = (currentAsk - tpPrice) / (point * ((digits == 3 || digits == 5) ? 10 : 1));

         string lineNameAvg = prefix + "AvgSell";
         CreateHLine(lineNameAvg, avgPrice, clrYellow, STYLE_DASHDOT, 1);
         CreatePriceLabel(prefix + "LblAvgSell", avgPrice, "PRIEMER (breakeven) | Total: " + DoubleToString(totalLots, 2) + " lot", clrYellow, false);

         string lineNameTP = prefix + "TPSell";
         CreateHLine(lineNameTP, tpPrice, clrLime, STYLE_SOLID, 2);
         CreatePriceLabel(prefix + "LblTPSell", tpPrice, "*** TAKE PROFIT *** | " + DoubleToString(pipsToTP, 1) + " pips to go", clrLime, false);
      }
   }

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| VYTVORENIE HORIZONTÁLNEJ ČIARY                                   |
//+------------------------------------------------------------------+
void CreateHLine(string name, double price, color clr, ENUM_LINE_STYLE style, int width)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);

   ObjectSetDouble(0, name, OBJPROP_PRICE, price);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE, style);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| VYTVORENIE PRICE LABELU NA PRAVEJ STRANE GRAFU                   |
//| isBuy = true: label NAD čiarou, false: label POD čiarou          |
//+------------------------------------------------------------------+
void CreatePriceLabel(string name, double price, string text, color clr, bool isBuy = true)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);

   int yPos = PriceToY(price);

   //--- BUY labely nad čiarou (-12px), SELL labely pod čiarou (+2px)
   if(isBuy)
      yPos -= 12;  // Nad čiarou
   else
      yPos += 2;   // Pod čiarou

   //--- Ak je Y mimo obrazovky, uprav
   if(yPos < 0) yPos = 2;
   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(yPos > chartHeight - 10) yPos = chartHeight - 10;

   //--- X pozícia za info panelom
   int xPos = 240;

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xPos);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yPos);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

//+------------------------------------------------------------------+
//| KONVERZIA CENY NA Y SÚRADNICU                                    |
//+------------------------------------------------------------------+
int PriceToY(double price)
{
   double priceMax = ChartGetDouble(0, CHART_PRICE_MAX);
   double priceMin = ChartGetDouble(0, CHART_PRICE_MIN);
   int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);

   if(priceMax == priceMin) return chartHeight / 2;

   double ratio = (priceMax - price) / (priceMax - priceMin);
   return (int)(ratio * chartHeight);
}

//+------------------------------------------------------------------+
