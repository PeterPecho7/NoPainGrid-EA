//+------------------------------------------------------------------+
//|                                          SP500_MultiRegime.mq5   |
//|                         Multi-Regime Trading Robot pre S&P 500   |
//|                                                                  |
//|  STRATÉGIE:                                                      |
//|  1. VWAP Mean Reversion (50-60%) - core stratégia                |
//|  2. Opening Range Breakout (20-25%) - high R:R                   |
//|  3. Trend Following (15-20%) - PnL booster                       |
//|                                                                  |
//|  VLASTNOSTI:                                                     |
//|  - Auto lot sizing (škáluje s účtom)                            |
//|  - Automatická detekcia režimu trhu                              |
//|  - VWAP výpočet (custom)                                         |
//|  - Vizualizácia nad grafom                                       |
//|  - Discord notifikácie                                           |
//+------------------------------------------------------------------+
#property copyright "SP500 Multi-Regime EA"
#property version   "1.00"
#property description "Multi-Regime Trading Robot for S&P 500"
#property strict

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| VSTUPNÉ PARAMETRE                                                |
//+------------------------------------------------------------------+
//--- SYMBOL & ZÁKLADNÉ
input group "=== SYMBOL & ZÁKLADNÉ ==="
input string InpSymbol         = "US500";          // Symbol (US500, US500.cash, SPX500)
input int    InpMagicNumber    = 5005001;          // Magické číslo

//--- RISK MANAGEMENT
input group "=== RISK MANAGEMENT ==="
input double InpRiskPercent    = 1.0;              // Risk % na trade
input double InpMaxDailyLoss   = 3.0;              // Max denná strata %
input int    InpMaxTradesDay   = 5;                // Max trades za deň
input double InpMaxSpread      = 5.0;              // Max spread (body)

//--- VWAP MEAN REVERSION
input group "=== VWAP MEAN REVERSION ==="
input bool   InpUseMeanRev     = true;             // Používať Mean Reversion
input double InpVWAPDistance   = 0.5;              // Vzdialenosť od VWAP (x ATR)
input int    InpMRStopLoss     = 15;               // Mean Reversion SL (body)
input int    InpMRRSIOver      = 70;               // RSI prekúpené
input int    InpMRRSIUnder     = 30;               // RSI prepredané

//--- OPENING RANGE BREAKOUT
input group "=== OPENING RANGE BREAKOUT ==="
input bool   InpUseORB         = true;             // Používať ORB stratégiu
input int    InpORBMinutes     = 15;               // Opening range trvanie (min)
input int    InpORBBuffer      = 3;                // Buffer pre breakout (body)
input int    InpMaxORBTrades   = 1;                // Max ORB trades za deň
input double InpORBRRRatio     = 2.0;              // R:R pomer pre ORB

//--- TREND FOLLOWING
input group "=== TREND FOLLOWING ==="
input bool   InpUseTrend       = true;             // Používať Trend Following
input int    InpTrendMinMin    = 60;               // Min minút nad VWAP pre trend
input int    InpTrendTrailing  = 30;               // Trailing pre trend (body)
input int    InpTrendSL        = 25;               // Trend SL (body)

//--- INDIKÁTORY
input group "=== INDIKÁTORY ==="
input int    InpRSIPeriod      = 5;                // RSI perióda
input int    InpFastEMA        = 9;                // Rýchla EMA
input int    InpMidEMA         = 21;               // Stredná EMA
input int    InpSlowEMA        = 50;               // Pomalá EMA
input int    InpATRPeriod      = 14;               // ATR perióda

//--- TRADING SESSIONS (Server time = UTC+2/+3)
input group "=== TRADING SESSIONS ==="
input int    InpSessionStartH  = 15;               // Session štart hodina (server time)
input int    InpSessionStartM  = 30;               // Session štart minúta
input int    InpSessionEndH    = 22;               // Session koniec hodina
input int    InpSessionEndM    = 0;                // Session koniec minúta
input bool   InpCloseEOD       = true;             // Zatvoriť všetko pred koncom dňa

//--- VIZUALIZÁCIA
input group "=== VIZUALIZÁCIA ==="
input bool   InpShowPanel      = true;             // Zobraziť info panel
input bool   InpShowVWAP       = true;             // Zobraziť VWAP čiaru
input bool   InpShowORB        = true;             // Zobraziť Opening Range
input color  InpVWAPColor      = clrDodgerBlue;    // VWAP farba
input color  InpORBHighColor   = clrLime;          // ORB High farba
input color  InpORBLowColor    = clrRed;           // ORB Low farba
input color  InpPanelColor     = C'32,32,32';      // Panel farba
input color  InpTextColor      = clrWhite;         // Text farba

//--- NOTIFIKÁCIE
input group "=== NOTIFIKÁCIE ==="
input bool   InpUsePush        = true;             // MT5 Push notifikácie
input string InpDiscordWebhook = "";               // Discord Webhook URL

//+------------------------------------------------------------------+
//| GLOBÁLNE PREMENNÉ                                                |
//+------------------------------------------------------------------+
CTrade         trade;
string         g_symbol;
double         point;
int            digits;

//--- Indikátor handles
int            handleRSI;
int            handleEMA_Fast;
int            handleEMA_Mid;
int            handleEMA_Slow;
int            handleATR;

//--- Indikátor hodnoty
double         rsi = 50;
double         emaFast = 0;
double         emaMid = 0;
double         emaSlow = 0;
double         atr = 0;

//--- VWAP premenné
double         vwap = 0;
double         cumulativeTPV = 0;     // Total Price × Volume
double         cumulativeVolume = 0;
datetime       vwapResetTime = 0;

//--- Opening Range premenné
double         orbHigh = 0;
double         orbLow = 0;
bool           orbDefined = false;
datetime       orbStartTime = 0;
int            orbTradestoday = 0;

//--- Trend premenné
int            minutesAboveVWAP = 0;
int            minutesBelowVWAP = 0;
datetime       lastMinuteCheck = 0;

//--- Denné štatistiky
datetime       currentDay = 0;
int            tradesToday = 0;
double         dailyPL = 0;
double         initialDayBalance = 0;

//--- Režim trhu
enum MARKET_REGIME {
    REGIME_WAITING,      // Čakáme na session
    REGIME_ORB_FORMING,  // Opening Range sa formuje
    REGIME_ORB_READY,    // ORB pripravené na breakout
    REGIME_RANGING,      // Mean Reversion mode
    REGIME_TRENDING_UP,  // Trend Following UP
    REGIME_TRENDING_DOWN // Trend Following DOWN
};
MARKET_REGIME currentRegime = REGIME_WAITING;

//--- Trade tracking
bool           hasOpenPosition = false;
int            currentPositionType = -1;  // 0=buy, 1=sell
string         currentStrategy = "";

//+------------------------------------------------------------------+
//| INICIALIZÁCIA                                                    |
//+------------------------------------------------------------------+
int OnInit()
{
    //--- Nastavenie symbolu
    g_symbol = InpSymbol;
    if(!SymbolSelect(g_symbol, true))
    {
        Print("CHYBA: Symbol ", g_symbol, " nie je dostupný!");
        return(INIT_FAILED);
    }

    point = SymbolInfoDouble(g_symbol, SYMBOL_POINT);
    digits = (int)SymbolInfoInteger(g_symbol, SYMBOL_DIGITS);

    //--- Nastavenie CTrade
    trade.SetExpertMagicNumber(InpMagicNumber);
    trade.SetDeviationInPoints(30);
    trade.SetTypeFilling(ORDER_FILLING_IOC);

    //--- Vytvorenie indikátorov na M5 timeframe
    handleRSI = iRSI(g_symbol, PERIOD_M5, InpRSIPeriod, PRICE_CLOSE);
    handleEMA_Fast = iMA(g_symbol, PERIOD_M5, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
    handleEMA_Mid = iMA(g_symbol, PERIOD_M5, InpMidEMA, 0, MODE_EMA, PRICE_CLOSE);
    handleEMA_Slow = iMA(g_symbol, PERIOD_M5, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
    handleATR = iATR(g_symbol, PERIOD_M5, InpATRPeriod);

    if(handleRSI == INVALID_HANDLE || handleEMA_Fast == INVALID_HANDLE ||
       handleEMA_Mid == INVALID_HANDLE || handleEMA_Slow == INVALID_HANDLE ||
       handleATR == INVALID_HANDLE)
    {
        Print("CHYBA: Nepodarilo sa vytvoriť indikátory!");
        return(INIT_FAILED);
    }

    //--- Inicializácia denných premenných
    ResetDailyStats();

    //--- Nastavenie VWAP reset time
    ResetVWAP();

    //--- Vizualizácia
    if(InpShowPanel)
        CreateInfoPanel();

    Print("SP500 Multi-Regime EA v1.00 - inicializovaný");
    Print("Symbol: ", g_symbol, " | Magic: ", InpMagicNumber);
    Print("Stratégie: MR=", InpUseMeanRev, " | ORB=", InpUseORB, " | Trend=", InpUseTrend);

    //--- Notifikácia o štarte
    if(InpUsePush || StringLen(InpDiscordWebhook) > 0)
    {
        string msg = "EA SPUSTENÝ | " + g_symbol + " | Balance: $" +
                     DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
        SendNotification_All("SP500 Multi-Regime", msg);
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| DEINICIALIZÁCIA                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    //--- Uvoľnenie indikátorov
    if(handleRSI != INVALID_HANDLE) IndicatorRelease(handleRSI);
    if(handleEMA_Fast != INVALID_HANDLE) IndicatorRelease(handleEMA_Fast);
    if(handleEMA_Mid != INVALID_HANDLE) IndicatorRelease(handleEMA_Mid);
    if(handleEMA_Slow != INVALID_HANDLE) IndicatorRelease(handleEMA_Slow);
    if(handleATR != INVALID_HANDLE) IndicatorRelease(handleATR);

    //--- Vymazanie objektov
    ObjectsDeleteAll(0, "SP500_");

    Print("SP500 Multi-Regime EA - ukončený");
}

//+------------------------------------------------------------------+
//| HLAVNÁ SLUČKA                                                    |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Kontrola nového dňa
    datetime today = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    if(today != currentDay)
    {
        ResetDailyStats();
        ResetVWAP();
        currentDay = today;
    }

    //--- Aktualizácia indikátorov
    UpdateIndicators();

    //--- Aktualizácia VWAP
    UpdateVWAP();

    //--- Aktualizácia pozície info
    UpdatePositionInfo();

    //--- Vizualizácia
    if(InpShowVWAP) DrawVWAP();
    if(InpShowORB && orbDefined) DrawORB();
    if(InpShowPanel) UpdateInfoPanel();

    //--- Kontrola trading session
    if(!IsTradingSession())
    {
        currentRegime = REGIME_WAITING;

        //--- Close EOD
        if(InpCloseEOD && hasOpenPosition && IsNearSessionEnd())
        {
            CloseAllPositions("End of Day");
        }
        return;
    }

    //--- Kontrola denných limitov
    if(CheckDailyLimits())
        return;

    //--- Kontrola spread
    if(!CheckSpread())
        return;

    //--- Detekcia a aktualizácia režimu
    DetectMarketRegime();

    //--- Správa otvorených pozícií
    if(hasOpenPosition)
    {
        ManageOpenPosition();
        return;
    }

    //--- Hľadanie nových obchodov podľa režimu
    switch(currentRegime)
    {
        case REGIME_ORB_READY:
            if(InpUseORB) CheckORBBreakout();
            break;

        case REGIME_RANGING:
            if(InpUseMeanRev) CheckMeanReversion();
            break;

        case REGIME_TRENDING_UP:
            if(InpUseTrend) CheckTrendPullback(true);
            break;

        case REGIME_TRENDING_DOWN:
            if(InpUseTrend) CheckTrendPullback(false);
            break;
    }
}

//+------------------------------------------------------------------+
//| AKTUALIZÁCIA INDIKÁTOROV                                         |
//+------------------------------------------------------------------+
void UpdateIndicators()
{
    double rsiBuffer[1], emaFastBuffer[1], emaMidBuffer[1], emaSlowBuffer[1], atrBuffer[1];

    if(CopyBuffer(handleRSI, 0, 0, 1, rsiBuffer) > 0) rsi = rsiBuffer[0];
    if(CopyBuffer(handleEMA_Fast, 0, 0, 1, emaFastBuffer) > 0) emaFast = emaFastBuffer[0];
    if(CopyBuffer(handleEMA_Mid, 0, 0, 1, emaMidBuffer) > 0) emaMid = emaMidBuffer[0];
    if(CopyBuffer(handleEMA_Slow, 0, 0, 1, emaSlowBuffer) > 0) emaSlow = emaSlowBuffer[0];
    if(CopyBuffer(handleATR, 0, 0, 1, atrBuffer) > 0) atr = atrBuffer[0];
}

//+------------------------------------------------------------------+
//| VWAP VÝPOČET (Custom)                                            |
//+------------------------------------------------------------------+
void UpdateVWAP()
{
    static datetime lastBar = 0;
    datetime currentBar = iTime(g_symbol, PERIOD_M1, 0);

    if(currentBar == lastBar) return;
    lastBar = currentBar;

    //--- Reset VWAP na začiatku US session
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    if(dt.hour == InpSessionStartH && dt.min == InpSessionStartM && dt.sec < 60)
    {
        ResetVWAP();
    }

    //--- Získaj posledný uzavretý bar
    double typical = (iHigh(g_symbol, PERIOD_M1, 1) +
                     iLow(g_symbol, PERIOD_M1, 1) +
                     iClose(g_symbol, PERIOD_M1, 1)) / 3.0;
    long volume = iTickVolume(g_symbol, PERIOD_M1, 1);

    if(volume > 0)
    {
        cumulativeTPV += typical * volume;
        cumulativeVolume += volume;

        if(cumulativeVolume > 0)
            vwap = cumulativeTPV / cumulativeVolume;
    }
}

//+------------------------------------------------------------------+
//| RESET VWAP                                                       |
//+------------------------------------------------------------------+
void ResetVWAP()
{
    cumulativeTPV = 0;
    cumulativeVolume = 0;
    vwap = 0;
    vwapResetTime = TimeCurrent();

    //--- Reset trend tracking
    minutesAboveVWAP = 0;
    minutesBelowVWAP = 0;

    //--- Reset ORB
    orbHigh = 0;
    orbLow = 0;
    orbDefined = false;
    orbStartTime = 0;
    orbTradestoday = 0;
}

//+------------------------------------------------------------------+
//| RESET DENNÝCH ŠTATISTÍK                                          |
//+------------------------------------------------------------------+
void ResetDailyStats()
{
    tradesToday = 0;
    dailyPL = 0;
    initialDayBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    currentDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
}

//+------------------------------------------------------------------+
//| KONTROLA TRADING SESSION                                          |
//+------------------------------------------------------------------+
bool IsTradingSession()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    int currentMinutes = dt.hour * 60 + dt.min;
    int startMinutes = InpSessionStartH * 60 + InpSessionStartM;
    int endMinutes = InpSessionEndH * 60 + InpSessionEndM;

    return (currentMinutes >= startMinutes && currentMinutes < endMinutes);
}

//+------------------------------------------------------------------+
//| KONTROLA BLÍZKO KONCA SESSION                                    |
//+------------------------------------------------------------------+
bool IsNearSessionEnd()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    int currentMinutes = dt.hour * 60 + dt.min;
    int endMinutes = InpSessionEndH * 60 + InpSessionEndM;

    return (endMinutes - currentMinutes <= 15);  // 15 min pred koncom
}

//+------------------------------------------------------------------+
//| KONTROLA DENNÝCH LIMITOV                                          |
//+------------------------------------------------------------------+
bool CheckDailyLimits()
{
    //--- Max trades
    if(tradesToday >= InpMaxTradesDay)
    {
        return true;
    }

    //--- Max daily loss
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double lossPercent = (initialDayBalance - equity) / initialDayBalance * 100;

    if(lossPercent >= InpMaxDailyLoss)
    {
        if(hasOpenPosition)
            CloseAllPositions("Max Daily Loss");
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| KONTROLA SPREAD                                                   |
//+------------------------------------------------------------------+
bool CheckSpread()
{
    double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
    double spread = (ask - bid) / point;

    return (spread <= InpMaxSpread);
}

//+------------------------------------------------------------------+
//| DETEKCIA REŽIMU TRHU                                              |
//+------------------------------------------------------------------+
void DetectMarketRegime()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    int minutesSinceOpen = (dt.hour * 60 + dt.min) - (InpSessionStartH * 60 + InpSessionStartM);
    double currentPrice = SymbolInfoDouble(g_symbol, SYMBOL_BID);

    //--- 1. Opening Range Formation (prvých X minút)
    if(minutesSinceOpen < InpORBMinutes)
    {
        currentRegime = REGIME_ORB_FORMING;
        FormOpeningRange();
        return;
    }

    //--- 2. ORB práve dokončené
    if(minutesSinceOpen >= InpORBMinutes && minutesSinceOpen < InpORBMinutes + 5 && !orbDefined)
    {
        FinalizeOpeningRange();
    }

    //--- 3. Aktualizácia trend tracking
    UpdateTrendTracking(currentPrice);

    //--- 4. Detekcia režimu
    if(vwap == 0)
    {
        currentRegime = REGIME_RANGING;
        return;
    }

    //--- Trend detection
    bool priceAboveVWAP = currentPrice > vwap;
    bool emaTrendUp = emaFast > emaMid && emaMid > emaSlow;
    bool emaTrendDown = emaFast < emaMid && emaMid < emaSlow;

    //--- Strong trend UP
    if(minutesAboveVWAP >= InpTrendMinMin && emaTrendUp && priceAboveVWAP)
    {
        currentRegime = REGIME_TRENDING_UP;
        return;
    }

    //--- Strong trend DOWN
    if(minutesBelowVWAP >= InpTrendMinMin && emaTrendDown && !priceAboveVWAP)
    {
        currentRegime = REGIME_TRENDING_DOWN;
        return;
    }

    //--- ORB Breakout ready
    if(orbDefined && orbTradestoday < InpMaxORBTrades && minutesSinceOpen < 120)
    {
        currentRegime = REGIME_ORB_READY;
        return;
    }

    //--- Default: Mean Reversion
    currentRegime = REGIME_RANGING;
}

//+------------------------------------------------------------------+
//| FORMOVANIE OPENING RANGE                                          |
//+------------------------------------------------------------------+
void FormOpeningRange()
{
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    //--- Nastavenie štartu ORB
    if(orbStartTime == 0)
    {
        orbStartTime = TimeCurrent();
        orbHigh = SymbolInfoDouble(g_symbol, SYMBOL_BID);
        orbLow = orbHigh;
    }

    //--- Aktualizácia high/low
    double currentPrice = SymbolInfoDouble(g_symbol, SYMBOL_BID);
    if(currentPrice > orbHigh) orbHigh = currentPrice;
    if(currentPrice < orbLow) orbLow = currentPrice;
}

//+------------------------------------------------------------------+
//| FINALIZÁCIA OPENING RANGE                                        |
//+------------------------------------------------------------------+
void FinalizeOpeningRange()
{
    if(orbHigh > orbLow && orbHigh - orbLow > atr * 0.3)
    {
        orbDefined = true;
        Print("ORB Defined: High=", DoubleToString(orbHigh, digits),
              " Low=", DoubleToString(orbLow, digits),
              " Range=", DoubleToString((orbHigh - orbLow) / point, 1), " bodov");
    }
}

//+------------------------------------------------------------------+
//| AKTUALIZÁCIA TREND TRACKING                                       |
//+------------------------------------------------------------------+
void UpdateTrendTracking(double price)
{
    datetime currentMinute = iTime(g_symbol, PERIOD_M1, 0);

    if(currentMinute == lastMinuteCheck) return;
    lastMinuteCheck = currentMinute;

    if(vwap == 0) return;

    if(price > vwap)
    {
        minutesAboveVWAP++;
        minutesBelowVWAP = 0;
    }
    else
    {
        minutesBelowVWAP++;
        minutesAboveVWAP = 0;
    }
}

//+------------------------------------------------------------------+
//| KONTROLA ORB BREAKOUT                                             |
//+------------------------------------------------------------------+
void CheckORBBreakout()
{
    if(!orbDefined || orbTradestoday >= InpMaxORBTrades) return;

    double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
    double buffer = InpORBBuffer * point;

    double orbRange = orbHigh - orbLow;
    double tp = orbRange * InpORBRRRatio;

    //--- Breakout UP
    if(ask > orbHigh + buffer)
    {
        double sl = orbLow;
        double tpPrice = ask + tp;
        double lot = CalculateLot(InpRiskPercent, (ask - sl) / point);

        if(OpenPosition(ORDER_TYPE_BUY, lot, sl, tpPrice, "ORB_Breakout_UP"))
        {
            orbTradestoday++;
            currentStrategy = "ORB Breakout UP";
        }
        return;
    }

    //--- Breakout DOWN
    if(bid < orbLow - buffer)
    {
        double sl = orbHigh;
        double tpPrice = bid - tp;
        double lot = CalculateLot(InpRiskPercent, (sl - bid) / point);

        if(OpenPosition(ORDER_TYPE_SELL, lot, sl, tpPrice, "ORB_Breakout_DOWN"))
        {
            orbTradestoday++;
            currentStrategy = "ORB Breakout DOWN";
        }
    }
}

//+------------------------------------------------------------------+
//| KONTROLA MEAN REVERSION                                          |
//+------------------------------------------------------------------+
void CheckMeanReversion()
{
    if(vwap == 0 || atr == 0) return;

    double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
    double vwapDistance = InpVWAPDistance * atr;

    //--- LONG: Cena pod VWAP + RSI prepredané
    if(bid < vwap - vwapDistance && rsi < InpMRRSIUnder)
    {
        double sl = bid - InpMRStopLoss * point;
        double tp = vwap;  // TP na VWAP
        double lot = CalculateLot(InpRiskPercent, InpMRStopLoss);

        if(OpenPosition(ORDER_TYPE_BUY, lot, sl, tp, "MeanRev_Long"))
        {
            currentStrategy = "Mean Reversion LONG";
        }
        return;
    }

    //--- SHORT: Cena nad VWAP + RSI prekúpené
    if(ask > vwap + vwapDistance && rsi > InpMRRSIOver)
    {
        double sl = ask + InpMRStopLoss * point;
        double tp = vwap;  // TP na VWAP
        double lot = CalculateLot(InpRiskPercent, InpMRStopLoss);

        if(OpenPosition(ORDER_TYPE_SELL, lot, sl, tp, "MeanRev_Short"))
        {
            currentStrategy = "Mean Reversion SHORT";
        }
    }
}

//+------------------------------------------------------------------+
//| KONTROLA TREND PULLBACK                                          |
//+------------------------------------------------------------------+
void CheckTrendPullback(bool bullish)
{
    if(vwap == 0) return;

    double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);

    if(bullish)
    {
        //--- LONG: Pullback k EMA alebo VWAP v uptrende
        bool nearEMA = MathAbs(bid - emaMid) < atr * 0.3;
        bool nearVWAP = MathAbs(bid - vwap) < atr * 0.3;
        bool rsiBullish = rsi > 40 && rsi < 70;

        if((nearEMA || nearVWAP) && rsiBullish)
        {
            double sl = bid - InpTrendSL * point;
            double tp = bid + InpTrendTrailing * point;  // Initial TP, trailing sa postará
            double lot = CalculateLot(InpRiskPercent, InpTrendSL);

            if(OpenPosition(ORDER_TYPE_BUY, lot, sl, tp, "Trend_Long"))
            {
                currentStrategy = "Trend Following LONG";
            }
        }
    }
    else
    {
        //--- SHORT: Pullback k EMA alebo VWAP v downtrende
        bool nearEMA = MathAbs(ask - emaMid) < atr * 0.3;
        bool nearVWAP = MathAbs(ask - vwap) < atr * 0.3;
        bool rsiBearish = rsi > 30 && rsi < 60;

        if((nearEMA || nearVWAP) && rsiBearish)
        {
            double sl = ask + InpTrendSL * point;
            double tp = ask - InpTrendTrailing * point;
            double lot = CalculateLot(InpRiskPercent, InpTrendSL);

            if(OpenPosition(ORDER_TYPE_SELL, lot, sl, tp, "Trend_Short"))
            {
                currentStrategy = "Trend Following SHORT";
            }
        }
    }
}

//+------------------------------------------------------------------+
//| VÝPOČET LOT SIZE (Auto-scaling)                                  |
//+------------------------------------------------------------------+
double CalculateLot(double riskPercent, double slPoints)
{
    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = balance * riskPercent / 100.0;

    //--- Hodnota bodu pre US500
    double tickValue = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(g_symbol, SYMBOL_TRADE_TICK_SIZE);

    if(tickSize == 0 || tickValue == 0 || slPoints == 0)
        return SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);

    double pointValue = tickValue / tickSize * point;
    double lot = riskAmount / (slPoints * pointValue);

    //--- Normalizácia
    double minLot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_MAX);
    double stepLot = SymbolInfoDouble(g_symbol, SYMBOL_VOLUME_STEP);

    lot = MathMax(minLot, lot);
    lot = MathMin(maxLot, lot);
    lot = MathFloor(lot / stepLot) * stepLot;

    return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| OTVORENIE POZÍCIE                                                 |
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_ORDER_TYPE type, double lot, double sl, double tp, string comment)
{
    double price = (type == ORDER_TYPE_BUY) ?
                   SymbolInfoDouble(g_symbol, SYMBOL_ASK) :
                   SymbolInfoDouble(g_symbol, SYMBOL_BID);

    if(trade.PositionOpen(g_symbol, type, lot, price, sl, tp, comment))
    {
        tradesToday++;
        hasOpenPosition = true;
        currentPositionType = (type == ORDER_TYPE_BUY) ? 0 : 1;

        string direction = (type == ORDER_TYPE_BUY) ? "BUY" : "SELL";
        string msg = direction + " " + DoubleToString(lot, 2) + " lot @ " +
                     DoubleToString(price, digits) + " | SL: " + DoubleToString(sl, digits) +
                     " | TP: " + DoubleToString(tp, digits) + " | " + comment;

        Print(msg);
        SendNotification_All("TRADE OPEN", msg);

        return true;
    }
    else
    {
        Print("CHYBA: Nepodarilo sa otvoriť pozíciu! Error: ", GetLastError());
        return false;
    }
}

//+------------------------------------------------------------------+
//| AKTUALIZÁCIA INFO O POZÍCII                                      |
//+------------------------------------------------------------------+
void UpdatePositionInfo()
{
    hasOpenPosition = false;
    currentPositionType = -1;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != g_symbol) continue;

        hasOpenPosition = true;
        currentPositionType = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 0 : 1;
        break;
    }
}

//+------------------------------------------------------------------+
//| SPRÁVA OTVORENEJ POZÍCIE                                         |
//+------------------------------------------------------------------+
void ManageOpenPosition()
{
    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != g_symbol) continue;

        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentTP = PositionGetDouble(POSITION_TP);
        int posType = (int)PositionGetInteger(POSITION_TYPE);
        string comment = PositionGetString(POSITION_COMMENT);

        //--- Trailing stop pre Trend Following
        if(StringFind(comment, "Trend_") >= 0)
        {
            ManageTrailingStop(ticket, posType, openPrice, currentSL);
        }
    }
}

//+------------------------------------------------------------------+
//| TRAILING STOP MANAGEMENT                                          |
//+------------------------------------------------------------------+
void ManageTrailingStop(ulong ticket, int posType, double openPrice, double currentSL)
{
    double trailDistance = InpTrendTrailing * point;

    if(posType == POSITION_TYPE_BUY)
    {
        double bid = SymbolInfoDouble(g_symbol, SYMBOL_BID);
        double newSL = bid - trailDistance;

        if(newSL > currentSL && newSL > openPrice)
        {
            trade.PositionModify(ticket, newSL, 0);  // TP 0 = trailing bez limitu
        }
    }
    else
    {
        double ask = SymbolInfoDouble(g_symbol, SYMBOL_ASK);
        double newSL = ask + trailDistance;

        if(newSL < currentSL && newSL < openPrice)
        {
            trade.PositionModify(ticket, newSL, 0);
        }
    }
}

//+------------------------------------------------------------------+
//| ZATVORENIE VŠETKÝCH POZÍCIÍ                                       |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
    double closedProfit = 0;
    int closedCount = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket <= 0) continue;
        if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber) continue;
        if(PositionGetString(POSITION_SYMBOL) != g_symbol) continue;

        closedProfit += PositionGetDouble(POSITION_PROFIT);
        closedProfit += PositionGetDouble(POSITION_SWAP);

        if(trade.PositionClose(ticket))
            closedCount++;
    }

    if(closedCount > 0)
    {
        dailyPL += closedProfit;
        string msg = reason + " | Closed: " + IntegerToString(closedCount) +
                     " | Profit: " + DoubleToString(closedProfit, 2) + "$";
        Print(msg);
        SendNotification_All("POSITIONS CLOSED", msg);
    }

    hasOpenPosition = false;
    currentPositionType = -1;
    currentStrategy = "";
}

//+------------------------------------------------------------------+
//| KRESLENIE VWAP                                                    |
//+------------------------------------------------------------------+
void DrawVWAP()
{
    if(vwap == 0) return;

    string name = "SP500_VWAP";

    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, vwap);
        ObjectSetInteger(0, name, OBJPROP_COLOR, InpVWAPColor);
        ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
        ObjectSetString(0, name, OBJPROP_TEXT, "VWAP");
    }
    else
    {
        ObjectSetDouble(0, name, OBJPROP_PRICE, vwap);
    }
}

//+------------------------------------------------------------------+
//| KRESLENIE ORB                                                     |
//+------------------------------------------------------------------+
void DrawORB()
{
    string nameHigh = "SP500_ORB_High";
    string nameLow = "SP500_ORB_Low";

    //--- ORB High
    if(ObjectFind(0, nameHigh) < 0)
    {
        ObjectCreate(0, nameHigh, OBJ_HLINE, 0, 0, orbHigh);
        ObjectSetInteger(0, nameHigh, OBJPROP_COLOR, InpORBHighColor);
        ObjectSetInteger(0, nameHigh, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, nameHigh, OBJPROP_WIDTH, 1);
        ObjectSetString(0, nameHigh, OBJPROP_TEXT, "ORB High");
    }
    else
    {
        ObjectSetDouble(0, nameHigh, OBJPROP_PRICE, orbHigh);
    }

    //--- ORB Low
    if(ObjectFind(0, nameLow) < 0)
    {
        ObjectCreate(0, nameLow, OBJ_HLINE, 0, 0, orbLow);
        ObjectSetInteger(0, nameLow, OBJPROP_COLOR, InpORBLowColor);
        ObjectSetInteger(0, nameLow, OBJPROP_STYLE, STYLE_DASH);
        ObjectSetInteger(0, nameLow, OBJPROP_WIDTH, 1);
        ObjectSetString(0, nameLow, OBJPROP_TEXT, "ORB Low");
    }
    else
    {
        ObjectSetDouble(0, nameLow, OBJPROP_PRICE, orbLow);
    }
}

//+------------------------------------------------------------------+
//| VYTVORENIE INFO PANELU                                            |
//+------------------------------------------------------------------+
void CreateInfoPanel()
{
    string prefix = "SP500_Panel_";
    int x = 20;
    int y = 30;
    int lineHeight = 18;

    //--- Pozadie
    string bgName = prefix + "BG";
    ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x - 5);
    ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y - 5);
    ObjectSetInteger(0, bgName, OBJPROP_XSIZE, 250);
    ObjectSetInteger(0, bgName, OBJPROP_YSIZE, lineHeight * 16 + 10);
    ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, InpPanelColor);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| AKTUALIZÁCIA INFO PANELU                                          |
//+------------------------------------------------------------------+
void UpdateInfoPanel()
{
    string prefix = "SP500_Panel_";
    int x = 20;
    int y = 30;
    int lineHeight = 18;
    int line = 0;

    double balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double floatingPL = equity - balance;
    double spread = (SymbolInfoDouble(g_symbol, SYMBOL_ASK) -
                    SymbolInfoDouble(g_symbol, SYMBOL_BID)) / point;

    //--- Title
    CreateLabel(prefix + "Title", x, y + line * lineHeight,
                "=== SP500 MULTI-REGIME ===", clrGold, 9, true);
    line++;

    //--- Regime
    string regimeText = GetRegimeText();
    color regimeColor = GetRegimeColor();
    CreateLabel(prefix + "Regime", x, y + line * lineHeight,
                "Rezim:     " + regimeText, regimeColor, 8, true);
    line++;

    //--- Separator
    CreateLabel(prefix + "Sep1", x, y + line * lineHeight,
                "----------------------------", clrGray, 8, false);
    line++;

    //--- Account info
    CreateLabel(prefix + "Balance", x, y + line * lineHeight,
                "Balance:   $" + DoubleToString(balance, 2), InpTextColor, 8, false);
    line++;

    CreateLabel(prefix + "Equity", x, y + line * lineHeight,
                "Equity:    $" + DoubleToString(equity, 2), InpTextColor, 8, false);
    line++;

    color plColor = floatingPL >= 0 ? clrLime : clrRed;
    CreateLabel(prefix + "FloatPL", x, y + line * lineHeight,
                "Floating:  " + (floatingPL >= 0 ? "+" : "") + DoubleToString(floatingPL, 2) + "$",
                plColor, 8, false);
    line++;

    //--- Separator
    CreateLabel(prefix + "Sep2", x, y + line * lineHeight,
                "----------------------------", clrGray, 8, false);
    line++;

    //--- Indicators
    CreateLabel(prefix + "VWAP", x, y + line * lineHeight,
                "VWAP:      " + (vwap > 0 ? DoubleToString(vwap, digits) : "---"),
                InpVWAPColor, 8, false);
    line++;

    CreateLabel(prefix + "RSI", x, y + line * lineHeight,
                "RSI(5):    " + DoubleToString(rsi, 1),
                rsi > 70 ? clrRed : (rsi < 30 ? clrLime : InpTextColor), 8, false);
    line++;

    CreateLabel(prefix + "ATR", x, y + line * lineHeight,
                "ATR:       " + DoubleToString(atr / point, 1) + " pts",
                clrAqua, 8, false);
    line++;

    CreateLabel(prefix + "Spread", x, y + line * lineHeight,
                "Spread:    " + DoubleToString(spread, 1) + " pts",
                spread <= InpMaxSpread ? clrLime : clrRed, 8, false);
    line++;

    //--- Separator
    CreateLabel(prefix + "Sep3", x, y + line * lineHeight,
                "----------------------------", clrGray, 8, false);
    line++;

    //--- ORB info
    string orbText = orbDefined ?
                     "H:" + DoubleToString(orbHigh, 1) + " L:" + DoubleToString(orbLow, 1) :
                     "Forming...";
    CreateLabel(prefix + "ORB", x, y + line * lineHeight,
                "ORB:       " + orbText, clrYellow, 8, false);
    line++;

    //--- Trading info
    CreateLabel(prefix + "Trades", x, y + line * lineHeight,
                "Trades:    " + IntegerToString(tradesToday) + "/" + IntegerToString(InpMaxTradesDay),
                InpTextColor, 8, false);
    line++;

    CreateLabel(prefix + "DailyPL", x, y + line * lineHeight,
                "Daily P/L: " + (dailyPL >= 0 ? "+" : "") + DoubleToString(dailyPL, 2) + "$",
                dailyPL >= 0 ? clrLime : clrRed, 8, false);
    line++;

    //--- Strategy
    string stratText = currentStrategy != "" ? currentStrategy : "---";
    CreateLabel(prefix + "Strategy", x, y + line * lineHeight,
                "Strategy:  " + stratText, clrAqua, 8, false);
}

//+------------------------------------------------------------------+
//| ZÍSKANIE TEXTU REŽIMU                                             |
//+------------------------------------------------------------------+
string GetRegimeText()
{
    switch(currentRegime)
    {
        case REGIME_WAITING:       return "WAITING";
        case REGIME_ORB_FORMING:   return "ORB FORMING";
        case REGIME_ORB_READY:     return "ORB READY";
        case REGIME_RANGING:       return "MEAN REVERSION";
        case REGIME_TRENDING_UP:   return "TREND UP";
        case REGIME_TRENDING_DOWN: return "TREND DOWN";
    }
    return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| ZÍSKANIE FARBY REŽIMU                                             |
//+------------------------------------------------------------------+
color GetRegimeColor()
{
    switch(currentRegime)
    {
        case REGIME_WAITING:       return clrGray;
        case REGIME_ORB_FORMING:   return clrYellow;
        case REGIME_ORB_READY:     return clrOrange;
        case REGIME_RANGING:       return clrDodgerBlue;
        case REGIME_TRENDING_UP:   return clrLime;
        case REGIME_TRENDING_DOWN: return clrRed;
    }
    return clrWhite;
}

//+------------------------------------------------------------------+
//| VYTVORENIE LABEL                                                  |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize, bool bold)
{
    if(ObjectFind(0, name) < 0)
    {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
        ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    }

    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
}

//+------------------------------------------------------------------+
//| DISCORD WEBHOOK NOTIFIKÁCIA                                       |
//+------------------------------------------------------------------+
bool SendDiscord(string message)
{
    if(StringLen(InpDiscordWebhook) == 0)
        return false;

    string headers = "Content-Type: application/json\r\n";

    string cleanMsg = message;
    StringReplace(cleanMsg, "\"", "'");
    StringReplace(cleanMsg, "\n", "\\n");

    string jsonBody = "{\"content\": \"" + cleanMsg + "\"}";

    char postData[];
    char resultData[];
    string resultHeaders;

    StringToCharArray(jsonBody, postData, 0, StringLen(jsonBody), CP_UTF8);
    ArrayResize(postData, ArraySize(postData) - 1);

    int timeout = 5000;
    int res = WebRequest("POST", InpDiscordWebhook, headers, timeout, postData, resultData, resultHeaders);

    return (res == 200 || res == 204);
}

//+------------------------------------------------------------------+
//| PUSH NOTIFIKÁCIA                                                  |
//+------------------------------------------------------------------+
bool SendPush(string title, string message)
{
    if(!InpUsePush)
        return false;

    string fullMsg = title + ": " + message;
    return SendNotification(fullMsg);
}

//+------------------------------------------------------------------+
//| ODOSLANIE VŠETKÝCH NOTIFIKÁCIÍ                                    |
//+------------------------------------------------------------------+
void SendNotification_All(string title, string message)
{
    string fullMsg = "[SP500] " + title + "\n" + message;

    if(InpUsePush)
        SendPush(title, message);

    if(StringLen(InpDiscordWebhook) > 0)
        SendDiscord(fullMsg);
}

//+------------------------------------------------------------------+
