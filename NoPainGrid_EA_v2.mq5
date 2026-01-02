//+------------------------------------------------------------------+
//|                                            NoPainGrid_EA_v2.mq5  |
//|                                Based on NoPain MT5 Signal Analysis|
//|                                                                   |
//|  Strategy (from analysis of 412 trades):                          |
//|  - Grid trading exclusively on AUDCAD                            |
//|  - Win rate: 82.5%, Profit Factor: 1.69                          |
//|  - Grid step: ~20 pips, Volume mult: ~1.2-1.5x                   |
//|  - TP: ~17 pips avg, SL: none (grid recovery)                    |
//|  - Closes basket when total TP reached                           |
//+------------------------------------------------------------------+
#property copyright "Based on NoPain MT5 Signal Analysis"
#property version   "2.00"
#property strict

#include <Trade\Trade.mqh>

//--- Input parameters
input group "=== Grid Settings ==="
input double   InpBaseLot         = 0.13;         // Base lot size (0.13 from signal)
input double   InpLotMultiplier   = 1.2;          // Lot multiplier per level
input int      InpGridStepPips    = 20;           // Grid step (pips)
input int      InpMaxGridLevels   = 8;            // Max grid levels
input double   InpTPPips          = 17.0;         // Take profit per trade (pips)

input group "=== Basket Management ==="
input double   InpBasketTPPips    = 50.0;         // Basket TP in pips (close all)
input double   InpBasketTPMoney   = 0;            // Basket TP in money (0=disabled)
input double   InpBasketTPPercent = 1.5;          // Basket TP as % of balance
input bool     InpUseBasketTP     = true;         // Use basket TP (close all together)

input group "=== Entry Conditions ==="
input bool     InpUseRSI          = true;         // Use RSI for entries
input int      InpRSIPeriod       = 14;           // RSI period
input int      InpRSIOversold     = 30;           // RSI oversold (buy zone)
input int      InpRSIOverbought   = 70;           // RSI overbought (sell zone)
input bool     InpUseBB           = true;         // Use Bollinger Bands
input int      InpBBPeriod        = 20;           // BB period
input double   InpBBDeviation     = 2.0;          // BB deviation
input ENUM_TIMEFRAMES InpTF       = PERIOD_H1;    // Signal timeframe

input group "=== Time Filter ==="
input bool     InpUseTimeFilter   = false;        // Use time filter
input int      InpStartHour       = 1;            // Start hour (server time)
input int      InpEndHour         = 22;           // End hour (server time)
input bool     InpTradeFriday     = true;         // Trade on Friday
input bool     InpCloseOnFriday   = false;        // Close all Friday evening

input group "=== Risk Management ==="
input double   InpMaxDrawdownPct  = 25.0;         // Max drawdown % (emergency close)
input double   InpMaxLots         = 10.0;         // Max total lots
input double   InpMaxSpread       = 30;           // Max spread (points)
input int      InpMagic           = 2262642;      // Magic number

//--- Global objects and handles
CTrade      trade;
int         hRSI;
int         hBB;
string      Symbol_Name = "AUDCAD";
double      Point_Value;
int         Digits_Value;

//--- Grid tracking
double      buyGridPrices[];
double      sellGridPrices[];
double      buyGridLots[];
double      sellGridLots[];
ulong       buyGridTickets[];
ulong       sellGridTickets[];
int         buyCount = 0;
int         sellCount = 0;

//--- Statistics
int         totalTrades = 0;
int         totalWins = 0;
double      totalProfit = 0;

//+------------------------------------------------------------------+
//| Expert initialization                                              |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Validate symbol
   if(!SymbolSelect(Symbol_Name, true))
   {
      Print("ERROR: ", Symbol_Name, " not available!");
      return INIT_FAILED;
   }

   //--- Get symbol info
   Point_Value = SymbolInfoDouble(Symbol_Name, SYMBOL_POINT);
   Digits_Value = (int)SymbolInfoInteger(Symbol_Name, SYMBOL_DIGITS);

   //--- Configure trade object
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(50);
   trade.SetTypeFilling(ORDER_FILLING_IOC);

   //--- Initialize indicators
   if(InpUseRSI)
   {
      hRSI = iRSI(Symbol_Name, InpTF, InpRSIPeriod, PRICE_CLOSE);
      if(hRSI == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create RSI indicator");
         return INIT_FAILED;
      }
   }

   if(InpUseBB)
   {
      hBB = iBands(Symbol_Name, InpTF, InpBBPeriod, 0, InpBBDeviation, PRICE_CLOSE);
      if(hBB == INVALID_HANDLE)
      {
         Print("ERROR: Failed to create BB indicator");
         return INIT_FAILED;
      }
   }

   //--- Resize arrays
   ArrayResize(buyGridPrices, InpMaxGridLevels);
   ArrayResize(sellGridPrices, InpMaxGridLevels);
   ArrayResize(buyGridLots, InpMaxGridLevels);
   ArrayResize(sellGridLots, InpMaxGridLevels);
   ArrayResize(buyGridTickets, InpMaxGridLevels);
   ArrayResize(sellGridTickets, InpMaxGridLevels);

   //--- Print initialization info
   Print("=== NoPain Grid EA v2 Initialized ===");
   Print("Symbol: ", Symbol_Name);
   Print("Base Lot: ", InpBaseLot);
   Print("Grid Step: ", InpGridStepPips, " pips");
   Print("Max Levels: ", InpMaxGridLevels);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                            |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(hRSI != INVALID_HANDLE) IndicatorRelease(hRSI);
   if(hBB != INVALID_HANDLE) IndicatorRelease(hBB);

   Print("=== EA Statistics ===");
   Print("Total Trades: ", totalTrades);
   Print("Wins: ", totalWins);
   Print("Win Rate: ", (totalTrades > 0 ? (double)totalWins/totalTrades*100 : 0), "%");
   Print("Total Profit: ", totalProfit);
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check time filter
   if(InpUseTimeFilter && !IsTradeTime())
      return;

   //--- Friday close
   if(InpCloseOnFriday && IsFridayEvening())
   {
      CloseAllPositions("Friday Close");
      return;
   }

   //--- Check drawdown
   if(IsMaxDrawdown())
   {
      CloseAllPositions("Max Drawdown");
      return;
   }

   //--- Check spread
   if(!IsSpreadOK())
      return;

   //--- Update position info
   UpdateGridInfo();

   //--- Check basket TP
   if(InpUseBasketTP && CheckBasketTP())
   {
      CloseAllPositions("Basket TP");
      return;
   }

   //--- Trading logic
   if(buyCount == 0 && sellCount == 0)
   {
      //--- No positions - look for new entry
      int signal = GetEntrySignal();
      if(signal == 1)
         OpenPosition(ORDER_TYPE_BUY, 0);
      else if(signal == -1)
         OpenPosition(ORDER_TYPE_SELL, 0);
   }
   else
   {
      //--- Manage existing grid
      ManageBuyGrid();
      ManageSellGrid();
   }
}

//+------------------------------------------------------------------+
//| Check if within trading hours                                      |
//+------------------------------------------------------------------+
bool IsTradeTime()
{
   MqlDateTime dt;
   TimeCurrent(dt);

   //--- Weekend
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;

   //--- Friday check
   if(dt.day_of_week == 5 && !InpTradeFriday)
      return false;

   //--- Hour check
   if(dt.hour < InpStartHour || dt.hour > InpEndHour)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| Check if Friday evening                                            |
//+------------------------------------------------------------------+
bool IsFridayEvening()
{
   MqlDateTime dt;
   TimeCurrent(dt);
   return (dt.day_of_week == 5 && dt.hour >= 20);
}

//+------------------------------------------------------------------+
//| Check max drawdown                                                 |
//+------------------------------------------------------------------+
bool IsMaxDrawdown()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   if(balance <= 0) return false;

   double dd = (balance - equity) / balance * 100;
   return (dd >= InpMaxDrawdownPct);
}

//+------------------------------------------------------------------+
//| Check spread                                                       |
//+------------------------------------------------------------------+
bool IsSpreadOK()
{
   double spread = SymbolInfoInteger(Symbol_Name, SYMBOL_SPREAD);
   return (spread <= InpMaxSpread);
}

//+------------------------------------------------------------------+
//| Get entry signal                                                   |
//+------------------------------------------------------------------+
int GetEntrySignal()
{
   int rsiSignal = 0;
   int bbSignal = 0;

   //--- RSI Signal
   if(InpUseRSI && hRSI != INVALID_HANDLE)
   {
      double rsi[];
      ArraySetAsSeries(rsi, true);
      if(CopyBuffer(hRSI, 0, 0, 3, rsi) >= 3)
      {
         if(rsi[0] < InpRSIOversold)
            rsiSignal = 1; // Oversold - buy
         else if(rsi[0] > InpRSIOverbought)
            rsiSignal = -1; // Overbought - sell
      }
   }

   //--- BB Signal
   if(InpUseBB && hBB != INVALID_HANDLE)
   {
      double upper[], lower[], middle[];
      ArraySetAsSeries(upper, true);
      ArraySetAsSeries(lower, true);
      ArraySetAsSeries(middle, true);

      if(CopyBuffer(hBB, 1, 0, 2, upper) >= 2 &&
         CopyBuffer(hBB, 2, 0, 2, lower) >= 2)
      {
         double bid = SymbolInfoDouble(Symbol_Name, SYMBOL_BID);

         if(bid <= lower[0])
            bbSignal = 1; // Below lower band - buy
         else if(bid >= upper[0])
            bbSignal = -1; // Above upper band - sell
      }
   }

   //--- Combine signals
   if(InpUseRSI && InpUseBB)
   {
      // Both must agree
      if(rsiSignal == 1 && bbSignal == 1) return 1;
      if(rsiSignal == -1 && bbSignal == -1) return -1;
      return 0;
   }
   else if(InpUseRSI)
   {
      return rsiSignal;
   }
   else if(InpUseBB)
   {
      return bbSignal;
   }

   //--- No filter - always trade (mean reversion assumption)
   return 0;
}

//+------------------------------------------------------------------+
//| Update grid position info                                          |
//+------------------------------------------------------------------+
void UpdateGridInfo()
{
   buyCount = 0;
   sellCount = 0;

   //--- Clear arrays
   ArrayInitialize(buyGridPrices, 0);
   ArrayInitialize(sellGridPrices, 0);
   ArrayInitialize(buyGridLots, 0);
   ArrayInitialize(sellGridLots, 0);
   ArrayInitialize(buyGridTickets, 0);
   ArrayInitialize(sellGridTickets, 0);

   //--- Scan positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != Symbol_Name) continue;

      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double price = PositionGetDouble(POSITION_PRICE_OPEN);
      double lots = PositionGetDouble(POSITION_VOLUME);

      if(type == POSITION_TYPE_BUY && buyCount < InpMaxGridLevels)
      {
         buyGridPrices[buyCount] = price;
         buyGridLots[buyCount] = lots;
         buyGridTickets[buyCount] = ticket;
         buyCount++;
      }
      else if(type == POSITION_TYPE_SELL && sellCount < InpMaxGridLevels)
      {
         sellGridPrices[sellCount] = price;
         sellGridLots[sellCount] = lots;
         sellGridTickets[sellCount] = ticket;
         sellCount++;
      }
   }
}

//+------------------------------------------------------------------+
//| Open position                                                      |
//+------------------------------------------------------------------+
bool OpenPosition(ENUM_ORDER_TYPE type, int level)
{
   //--- Calculate lot size
   double lots = CalculateLots(level);

   //--- Check max lots
   double totalLots = GetTotalLots();
   if(totalLots + lots > InpMaxLots)
   {
      Print("Max lots limit reached");
      return false;
   }

   //--- Get prices
   double ask = SymbolInfoDouble(Symbol_Name, SYMBOL_ASK);
   double bid = SymbolInfoDouble(Symbol_Name, SYMBOL_BID);
   double price = (type == ORDER_TYPE_BUY) ? ask : bid;

   //--- Calculate TP
   double tp = 0;
   double tpDistance = InpTPPips * GetPipValue();

   if(!InpUseBasketTP) // Individual TP only if not using basket
   {
      if(type == ORDER_TYPE_BUY)
         tp = price + tpDistance;
      else
         tp = price - tpDistance;
   }

   //--- Open trade
   bool result = false;
   string comment = "NoPain Grid L" + IntegerToString(level);

   if(type == ORDER_TYPE_BUY)
      result = trade.Buy(lots, Symbol_Name, price, 0, tp, comment);
   else
      result = trade.Sell(lots, Symbol_Name, price, 0, tp, comment);

   if(result)
   {
      Print((type == ORDER_TYPE_BUY ? "BUY" : "SELL"),
            " opened: Level=", level,
            " Lots=", DoubleToString(lots, 2),
            " Price=", DoubleToString(price, Digits_Value));
      totalTrades++;
   }
   else
   {
      Print("Order failed: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }

   return result;
}

//+------------------------------------------------------------------+
//| Calculate lot size for level                                       |
//+------------------------------------------------------------------+
double CalculateLots(int level)
{
   double lots = InpBaseLot;

   for(int i = 0; i < level; i++)
      lots *= InpLotMultiplier;

   //--- Normalize
   double minLot = SymbolInfoDouble(Symbol_Name, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(Symbol_Name, SYMBOL_VOLUME_MAX);
   double step = SymbolInfoDouble(Symbol_Name, SYMBOL_VOLUME_STEP);

   lots = MathFloor(lots / step) * step;
   lots = MathMax(minLot, MathMin(maxLot, lots));

   return lots;
}

//+------------------------------------------------------------------+
//| Get pip value in points                                            |
//+------------------------------------------------------------------+
double GetPipValue()
{
   if(Digits_Value == 3 || Digits_Value == 5)
      return 10 * Point_Value;
   return Point_Value;
}

//+------------------------------------------------------------------+
//| Get total lots                                                     |
//+------------------------------------------------------------------+
double GetTotalLots()
{
   double total = 0;

   for(int i = 0; i < buyCount; i++)
      total += buyGridLots[i];

   for(int i = 0; i < sellCount; i++)
      total += sellGridLots[i];

   return total;
}

//+------------------------------------------------------------------+
//| Manage buy grid                                                    |
//+------------------------------------------------------------------+
void ManageBuyGrid()
{
   if(buyCount == 0 || buyCount >= InpMaxGridLevels)
      return;

   double ask = SymbolInfoDouble(Symbol_Name, SYMBOL_ASK);
   double gridStep = InpGridStepPips * GetPipValue();

   //--- Find lowest buy price
   double lowestBuy = DBL_MAX;
   for(int i = 0; i < buyCount; i++)
   {
      if(buyGridPrices[i] < lowestBuy)
         lowestBuy = buyGridPrices[i];
   }

   //--- Add position if price dropped
   if(ask <= lowestBuy - gridStep)
   {
      OpenPosition(ORDER_TYPE_BUY, buyCount);
   }
}

//+------------------------------------------------------------------+
//| Manage sell grid                                                   |
//+------------------------------------------------------------------+
void ManageSellGrid()
{
   if(sellCount == 0 || sellCount >= InpMaxGridLevels)
      return;

   double bid = SymbolInfoDouble(Symbol_Name, SYMBOL_BID);
   double gridStep = InpGridStepPips * GetPipValue();

   //--- Find highest sell price
   double highestSell = 0;
   for(int i = 0; i < sellCount; i++)
   {
      if(sellGridPrices[i] > highestSell)
         highestSell = sellGridPrices[i];
   }

   //--- Add position if price rose
   if(bid >= highestSell + gridStep)
   {
      OpenPosition(ORDER_TYPE_SELL, sellCount);
   }
}

//+------------------------------------------------------------------+
//| Check basket TP                                                    |
//+------------------------------------------------------------------+
bool CheckBasketTP()
{
   double profit = GetTotalProfit();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   //--- Money target
   if(InpBasketTPMoney > 0 && profit >= InpBasketTPMoney)
      return true;

   //--- Percent target
   if(InpBasketTPPercent > 0)
   {
      double target = balance * InpBasketTPPercent / 100.0;
      if(profit >= target)
         return true;
   }

   //--- Pips target (approximate based on total lots)
   if(InpBasketTPPips > 0)
   {
      double totalLots = GetTotalLots();
      if(totalLots > 0)
      {
         double pipValue = SymbolInfoDouble(Symbol_Name, SYMBOL_TRADE_TICK_VALUE);
         double targetProfit = InpBasketTPPips * totalLots * pipValue * 10; // Approximate
         if(profit >= targetProfit)
            return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Get total floating profit                                          |
//+------------------------------------------------------------------+
double GetTotalProfit()
{
   double profit = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != Symbol_Name) continue;

      profit += PositionGetDouble(POSITION_PROFIT);
      profit += PositionGetDouble(POSITION_SWAP);
   }

   return profit;
}

//+------------------------------------------------------------------+
//| Close all positions                                                |
//+------------------------------------------------------------------+
void CloseAllPositions(string reason)
{
   double closedProfit = 0;
   int closedCount = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagic) continue;
      if(PositionGetString(POSITION_SYMBOL) != Symbol_Name) continue;

      double posProfit = PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);

      if(trade.PositionClose(ticket))
      {
         closedProfit += posProfit;
         closedCount++;
         if(posProfit > 0) totalWins++;
      }
   }

   totalProfit += closedProfit;
   Print("Closed ", closedCount, " positions | Reason: ", reason, " | Profit: ", DoubleToString(closedProfit, 2));
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                          |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      if(trans.deal_type == DEAL_TYPE_BUY || trans.deal_type == DEAL_TYPE_SELL)
      {
         // Position opened or closed
      }
   }
}

//+------------------------------------------------------------------+
