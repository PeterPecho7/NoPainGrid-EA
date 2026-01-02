//+------------------------------------------------------------------+
//|                                               NoPainGrid_EA.mq5  |
//|                                                                   |
//|  POPIS STRATÉGIE:                                                |
//|  =================                                                |
//|  Tento Expert Advisor (EA) implementuje GRID TRADING stratégiu   |
//|  s prvkami MARTINGALE na menovom páre AUDCAD.                    |
//|                                                                   |
//|  Stratégia bola reverse-engineerovaná z úspešného signálu        |
//|  "NoPain MT5" (https://www.mql5.com/en/signals/2262642)          |
//|  ktorý dosiahol rast 1,651% s win rate 63.67%.                   |
//|                                                                   |
//|  AKO FUNGUJE GRID TRADING:                                       |
//|  -------------------------                                        |
//|  1. EA otvorí prvú pozíciu na základe RSI signálu                |
//|  2. Ak cena ide proti nám, otvorí ďalšiu pozíciu v rovnakom      |
//|     smere s väčším lotom (martingale)                            |
//|  3. Pozície sú rozmiestnené v "mriežke" (grid) po 20 pipsoch     |
//|  4. Keď celkový profit dosiahne cieľ, zatvoria sa všetky pozície |
//|                                                                   |
//|  RIZIKÁ:                                                         |
//|  -------                                                          |
//|  - Vysoký drawdown pri silnom trende                             |
//|  - Potrebný väčší kapitál pre prežitie drawdownu                 |
//|  - Odporúčané: min. $1000-2000 na 0.01 lot                       |
//|                                                                   |
//|  Autor: Vytvorené pomocou analýzy signálu NoPain MT5             |
//|  Verzia: 1.00                                                    |
//+------------------------------------------------------------------+
#property copyright "Based on NoPain MT5 Signal"
#property version   "1.00"
#property description "Grid/Martingale EA pre AUDCAD"
#property strict

//+------------------------------------------------------------------+
//| INCLUDE KNIŽNICE                                                  |
//| Trade.mqh - štandardná MT5 knižnica pre obchodovanie             |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| VSTUPNÉ PARAMETRE - tieto môžeš meniť v nastaveniach EA          |
//+------------------------------------------------------------------+

//--- Hlavné nastavenia gridu
input group "=== HLAVNÉ NASTAVENIA GRIDU ==="
input double   InpLotSize        = 0.13;          // Počiatočná veľkosť lotu (0.13 = hodnota zo signálu)
input double   InpLotMultiplier  = 1.5;           // Násobič lotu pre ďalšie úrovne (1.5 = 50% navýšenie)
input int      InpGridStepPips   = 20;            // Rozostup mriežky v pipsoch (20 = štandard zo signálu)
input int      InpMaxGridLevels  = 10;            // Maximálny počet úrovní gridu (ochrana pred prílišným rizikom)
input double   InpTakeProfitPips = 15;            // Take Profit pre jednotlivé pozície v pipsoch
input double   InpTotalTPPercent = 1.0;           // Celkový TP ako % zostatku (zatvorí všetky pozície)

//--- Časové filtre pre obchodovanie
input group "=== ČASOVÉ FILTRE ==="
input int      InpStartHour      = 0;             // Začiatok obchodovania (hodina, 0-23)
input int      InpEndHour        = 23;            // Koniec obchodovania (hodina, 0-23)
input bool     InpTradeFriday    = true;          // Obchodovať v piatok? (riziko weekend gapu)

//--- Nastavenia riadenia rizika
input group "=== RIADENIE RIZIKA ==="
input double   InpMaxDrawdownPct = 20.0;          // Max drawdown % (núdzové zatvorenie všetkých pozícií)
input double   InpMaxLotSize     = 5.0;           // Maximálna celková veľkosť lotov (ochrana)
input int      InpMagicNumber    = 2262642;       // Magické číslo (identifikátor EA, použité ID signálu)

//--- Nastavenia vstupných signálov
input group "=== VSTUPNÉ SIGNÁLY ==="
input int      InpRSIPeriod      = 14;            // Perióda RSI indikátora
input int      InpRSIOverbought  = 70;            // RSI prekúpená úroveň (nad = sell signál)
input int      InpRSIOversold    = 30;            // RSI prepredaná úroveň (pod = buy signál)
input ENUM_TIMEFRAMES InpTimeframe = PERIOD_H1;   // Časový rámec pre signály

//+------------------------------------------------------------------+
//| GLOBÁLNE PREMENNÉ                                                 |
//| Tieto premenné existujú počas celého behu EA                     |
//+------------------------------------------------------------------+
CTrade         trade;            // Objekt pre vykonávanie obchodov
int            handleRSI;        // Handle (ukazovateľ) na RSI indikátor
double         gridStep;         // Vypočítaný grid step v cenových bodoch
double         point;            // Hodnota jedného bodu pre daný symbol
string         symbol = "AUDCAD";// Symbol na ktorom obchodujeme
double         initialBalance;   // Počiatočný zostatok pri štarte EA

//+------------------------------------------------------------------+
//| ŠTRUKTÚRA PRE SLEDOVANIE GRID POZÍCIÍ                            |
//| Uchováva informácie o každej otvorenej pozícii v mriežke         |
//+------------------------------------------------------------------+
struct GridPosition
{
   ulong    ticket;      // Unikátny identifikátor pozície
   double   openPrice;   // Cena otvorenia
   double   lots;        // Veľkosť pozície v lotoch
   int      type;        // Typ: 0=buy, 1=sell
   int      level;       // Úroveň v mriežke (0=prvá, 1=druhá, atď.)
};

//--- Polia pre ukladanie informácií o buy a sell pozíciách
GridPosition   buyGrid[];        // Pole buy pozícií
GridPosition   sellGrid[];       // Pole sell pozícií
int            buyLevels = 0;    // Počet otvorených buy úrovní
int            sellLevels = 0;   // Počet otvorených sell úrovní

//+------------------------------------------------------------------+
//| FUNKCIA ONINIT - Inicializácia EA                                |
//| Volá sa raz pri spustení EA alebo zmene parametrov               |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Overenie dostupnosti symbolu AUDCAD
   //    Ak symbol nie je dostupný u brokera, EA sa nespustí
   if(!SymbolSelect(symbol, true))
   {
      Print("CHYBA: Symbol ", symbol, " nie je dostupný u vášho brokera!");
      return(INIT_FAILED);
   }

   //--- Nastavenie obchodného objektu
   trade.SetExpertMagicNumber(InpMagicNumber);  // Nastaví magic number pre identifikáciu obchodov
   trade.SetDeviationInPoints(30);               // Povolený sklz 30 bodov
   trade.SetTypeFilling(ORDER_FILLING_IOC);      // Typ plnenia príkazov

   //--- Výpočet hodnoty bodu a grid stepu
   //    Pre 5-miestne symboly (napr. 0.88123) je pip = 10 bodov
   point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);

   if(digits == 3 || digits == 5)
      gridStep = InpGridStepPips * 10 * point;  // 5-miestny symbol
   else
      gridStep = InpGridStepPips * point;       // 4-miestny symbol

   //--- Vytvorenie RSI indikátora
   handleRSI = iRSI(symbol, InpTimeframe, InpRSIPeriod, PRICE_CLOSE);
   if(handleRSI == INVALID_HANDLE)
   {
      Print("CHYBA: Nepodarilo sa vytvoriť RSI indikátor!");
      return(INIT_FAILED);
   }

   //--- Uloženie počiatočného zostatku pre výpočet drawdownu
   initialBalance = AccountInfoDouble(ACCOUNT_BALANCE);

   //--- Inicializácia polí pre grid pozície
   ArrayResize(buyGrid, InpMaxGridLevels);
   ArrayResize(sellGrid, InpMaxGridLevels);

   //--- Výpis informácií o inicializácii
   Print("====================================");
   Print("NoPain Grid EA úspešne inicializovaný");
   Print("Symbol: ", symbol);
   Print("Grid step: ", InpGridStepPips, " pips (", gridStep, " v bodoch)");
   Print("Počiatočný lot: ", InpLotSize);
   Print("Max úrovní: ", InpMaxGridLevels);
   Print("====================================");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| FUNKCIA ONDEINIT - Ukončenie EA                                  |
//| Volá sa pri vypnutí EA, zmene timeframe, atď.                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Uvoľnenie RSI indikátora z pamäte
   if(handleRSI != INVALID_HANDLE)
      IndicatorRelease(handleRSI);

   Print("NoPain Grid EA ukončený. Dôvod: ", reason);
}

//+------------------------------------------------------------------+
//| FUNKCIA ONTICK - Hlavná obchodná logika                          |
//| Volá sa pri každej zmene ceny (tick)                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- KROK 1: Kontrola obchodných hodín
   //    Ak nie sme v obchodnom čase, nerob nič
   if(!IsTradingTime())
      return;

   //--- KROK 2: Kontrola drawdownu
   //    Ak prekročíme maximálny drawdown, zatvor všetky pozície
   if(CheckDrawdown())
   {
      CloseAllPositions();
      return;
   }

   //--- KROK 3: Aktualizácia informácií o grid pozíciách
   //    Prejde všetky otvorené pozície a aktualizuje naše polia
   UpdateGridInfo();

   //--- KROK 4: Kontrola celkového profitu
   //    Ak celkový profit dosiahol cieľ, zatvor všetky pozície
   if(CheckTotalProfit())
   {
      CloseAllPositions();
      return;
   }

   //--- KROK 5: Získanie obchodného signálu z RSI
   int signal = GetSignal();

   //--- KROK 6: Rozhodovacia logika
   //    A) Ak nemáme žiadne pozície - hľadaj nový vstup podľa signálu
   //    B) Ak máme pozície - spravuj grid (pridávaj úrovne ak treba)
   if(buyLevels == 0 && sellLevels == 0)
   {
      //--- Žiadne pozície - čakáme na signál
      if(signal == 1) // RSI ukazuje prepredanosť = BUY signál
         OpenGridPosition(ORDER_TYPE_BUY, 0);
      else if(signal == -1) // RSI ukazuje prekúpenosť = SELL signál
         OpenGridPosition(ORDER_TYPE_SELL, 0);
   }
   else
   {
      //--- Máme otvorené pozície - spravuj grid
      ManageGrid();
   }
}

//+------------------------------------------------------------------+
//| KONTROLA OBCHODNÉHO ČASU                                         |
//| Vráti true ak je vhodný čas na obchodovanie                      |
//+------------------------------------------------------------------+
bool IsTradingTime()
{
   MqlDateTime dt;
   TimeCurrent(dt);  // Získaj aktuálny serverový čas

   //--- Kontrola piatku
   if(dt.day_of_week == 5 && !InpTradeFriday)
      return false;

   //--- Preskočenie víkendov (sobota=6, nedeľa=0)
   if(dt.day_of_week == 0 || dt.day_of_week == 6)
      return false;

   //--- Kontrola hodín
   if(dt.hour < InpStartHour || dt.hour > InpEndHour)
      return false;

   return true;
}

//+------------------------------------------------------------------+
//| KONTROLA DRAWDOWNU                                               |
//| Vráti true ak bol prekročený maximálny povolený drawdown         |
//+------------------------------------------------------------------+
bool CheckDrawdown()
{
   double equity = AccountInfoDouble(ACCOUNT_EQUITY);   // Aktuálne equity (vrátane otvorených pozícií)
   double balance = AccountInfoDouble(ACCOUNT_BALANCE); // Zostatok na účte

   if(balance <= 0)
      return false;

   //--- Výpočet drawdownu v percentách
   //    Drawdown = (Balance - Equity) / Balance * 100
   double drawdown = (balance - equity) / balance * 100;

   if(drawdown >= InpMaxDrawdownPct)
   {
      Print("VAROVANIE: Maximálny drawdown dosiahnutý: ", drawdown, "%");
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| ZÍSKANIE OBCHODNÉHO SIGNÁLU Z RSI                                |
//| Vráti: 1 = BUY, -1 = SELL, 0 = žiadny signál                    |
//+------------------------------------------------------------------+
int GetSignal()
{
   double rsi[];
   ArraySetAsSeries(rsi, true);  // Nastaví pole ako časovú radu (najnovšia hodnota = index 0)

   //--- Skopíruj posledné 3 hodnoty RSI
   if(CopyBuffer(handleRSI, 0, 0, 3, rsi) < 3)
      return 0;

   //--- BUY signál: RSI prekročí prepredanú úroveň zdola nahor
   //    Alebo je RSI pod prepredanou úrovňou (extrémna prepredanosť)
   if(rsi[1] < InpRSIOversold && rsi[0] >= InpRSIOversold)
      return 1;

   if(rsi[0] < InpRSIOversold)
      return 1;

   //--- SELL signál: RSI prekročí prekúpenú úroveň zhora nadol
   //    Alebo je RSI nad prekúpenou úrovňou (extrémna prekúpenosť)
   if(rsi[1] > InpRSIOverbought && rsi[0] <= InpRSIOverbought)
      return -1;

   if(rsi[0] > InpRSIOverbought)
      return -1;

   return 0;  // Žiadny signál
}

//+------------------------------------------------------------------+
//| AKTUALIZÁCIA INFORMÁCIÍ O GRID POZÍCIÁCH                         |
//| Prejde všetky otvorené pozície a aktualizuje naše sledovacie polia|
//+------------------------------------------------------------------+
void UpdateGridInfo()
{
   //--- Vynuluj počítadlá
   buyLevels = 0;
   sellLevels = 0;

   //--- Prejdi všetky otvorené pozície (od konca pre bezpečnosť)
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;

      //--- Kontrola či je to naša pozícia (podľa magic number)
      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      //--- Kontrola či je to správny symbol
      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      //--- Získanie informácií o pozícii
      ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      double lots = PositionGetDouble(POSITION_VOLUME);

      //--- Uloženie do príslušného poľa
      if(posType == POSITION_TYPE_BUY)
      {
         if(buyLevels < InpMaxGridLevels)
         {
            buyGrid[buyLevels].ticket = ticket;
            buyGrid[buyLevels].openPrice = openPrice;
            buyGrid[buyLevels].lots = lots;
            buyGrid[buyLevels].type = 0;
            buyGrid[buyLevels].level = buyLevels;
            buyLevels++;
         }
      }
      else if(posType == POSITION_TYPE_SELL)
      {
         if(sellLevels < InpMaxGridLevels)
         {
            sellGrid[sellLevels].ticket = ticket;
            sellGrid[sellLevels].openPrice = openPrice;
            sellGrid[sellLevels].lots = lots;
            sellGrid[sellLevels].type = 1;
            sellGrid[sellLevels].level = sellLevels;
            sellLevels++;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| OTVORENIE NOVEJ GRID POZÍCIE                                     |
//| orderType: ORDER_TYPE_BUY alebo ORDER_TYPE_SELL                  |
//| level: úroveň v mriežke (0 = prvá pozícia)                       |
//+------------------------------------------------------------------+
bool OpenGridPosition(ENUM_ORDER_TYPE orderType, int level)
{
   //--- Výpočet veľkosti lotu pre danú úroveň
   double lotSize = CalculateLotSize(level);

   //--- Kontrola maximálnej celkovej veľkosti lotov
   double totalLots = GetTotalLots() + lotSize;
   if(totalLots > InpMaxLotSize)
   {
      Print("VAROVANIE: Dosiahnutý maximálny limit lotov: ", totalLots);
      return false;
   }

   //--- Získanie aktuálnych cien
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);  // Cena pre BUY
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);  // Cena pre SELL

   double price = (orderType == ORDER_TYPE_BUY) ? ask : bid;

   //--- Výpočet Take Profit pre jednotlivú pozíciu
   double tp = 0;
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double tpPips = InpTakeProfitPips * ((digits == 3 || digits == 5) ? 10 : 1) * point;

   if(orderType == ORDER_TYPE_BUY)
      tp = price + tpPips;  // TP je nad vstupnou cenou
   else
      tp = price - tpPips;  // TP je pod vstupnou cenou

   //--- Otvorenie pozície
   bool result = false;
   string comment = "NoPain Grid L" + IntegerToString(level);  // Komentár pre identifikáciu úrovne

   if(orderType == ORDER_TYPE_BUY)
      result = trade.Buy(lotSize, symbol, price, 0, tp, comment);
   else
      result = trade.Sell(lotSize, symbol, price, 0, tp, comment);

   //--- Výpis výsledku
   if(result)
   {
      Print("OTVORENÁ POZÍCIA: ", (orderType == ORDER_TYPE_BUY ? "BUY" : "SELL"),
            " | Úroveň: ", level,
            " | Loty: ", lotSize,
            " | Cena: ", price,
            " | TP: ", tp);
   }
   else
   {
      Print("CHYBA OTVORENIA: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }

   return result;
}

//+------------------------------------------------------------------+
//| VÝPOČET VEĽKOSTI LOTU PRE DANÚ ÚROVEŇ                           |
//| Implementuje martingale - každá ďalšia úroveň má väčší lot       |
//+------------------------------------------------------------------+
double CalculateLotSize(int level)
{
   double lots = InpLotSize;

   //--- Pre každú úroveň vynásob lotom multiplierom
   //    Úroveň 0: 0.13
   //    Úroveň 1: 0.13 * 1.5 = 0.195
   //    Úroveň 2: 0.195 * 1.5 = 0.29
   //    atď.
   for(int i = 0; i < level; i++)
   {
      lots *= InpLotMultiplier;
   }

   //--- Normalizácia lotu podľa požiadaviek brokera
   double minLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MIN);   // Minimálny lot
   double maxLot = SymbolInfoDouble(symbol, SYMBOL_VOLUME_MAX);   // Maximálny lot
   double lotStep = SymbolInfoDouble(symbol, SYMBOL_VOLUME_STEP); // Krok lotu

   lots = MathFloor(lots / lotStep) * lotStep;  // Zaokrúhlenie na platný krok
   lots = MathMax(minLot, MathMin(maxLot, lots)); // Orezanie na min/max

   return lots;
}

//+------------------------------------------------------------------+
//| ZÍSKANIE CELKOVÝCH LOTOV V TRHU                                  |
//| Spočíta všetky naše otvorené pozície                             |
//+------------------------------------------------------------------+
double GetTotalLots()
{
   double totalLots = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      totalLots += PositionGetDouble(POSITION_VOLUME);
   }

   return totalLots;
}

//+------------------------------------------------------------------+
//| SPRÁVA GRIDU                                                      |
//| Pridáva nové úrovne keď cena ide proti nám                       |
//+------------------------------------------------------------------+
void ManageGrid()
{
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);

   //=== SPRÁVA BUY GRIDU ===
   //    Pridávame buy pozície keď cena KLESÁ
   if(buyLevels > 0 && buyLevels < InpMaxGridLevels)
   {
      //--- Nájdi najnižšiu buy pozíciu
      double lowestBuy = DBL_MAX;
      for(int i = 0; i < buyLevels; i++)
      {
         if(buyGrid[i].openPrice < lowestBuy)
            lowestBuy = buyGrid[i].openPrice;
      }

      //--- Ak cena klesla o grid step, pridaj ďalšiu buy pozíciu
      if(ask <= lowestBuy - gridStep)
      {
         OpenGridPosition(ORDER_TYPE_BUY, buyLevels);
      }
   }

   //=== SPRÁVA SELL GRIDU ===
   //    Pridávame sell pozície keď cena STÚPA
   if(sellLevels > 0 && sellLevels < InpMaxGridLevels)
   {
      //--- Nájdi najvyššiu sell pozíciu
      double highestSell = 0;
      for(int i = 0; i < sellLevels; i++)
      {
         if(sellGrid[i].openPrice > highestSell)
            highestSell = sellGrid[i].openPrice;
      }

      //--- Ak cena stúpla o grid step, pridaj ďalšiu sell pozíciu
      if(bid >= highestSell + gridStep)
      {
         OpenGridPosition(ORDER_TYPE_SELL, sellLevels);
      }
   }
}

//+------------------------------------------------------------------+
//| KONTROLA CELKOVÉHO PROFITU                                       |
//| Vráti true ak celkový profit dosiahol cieľ                       |
//+------------------------------------------------------------------+
bool CheckTotalProfit()
{
   double totalProfit = GetTotalProfit();
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);

   //--- Výpočet cieľového profitu v peniazoch
   double targetProfit = balance * InpTotalTPPercent / 100.0;

   if(totalProfit >= targetProfit)
   {
      Print("CIEĽOVÝ PROFIT DOSIAHNUTÝ: ", totalProfit, " >= ", targetProfit);
      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| ZÍSKANIE CELKOVÉHO FLOATING PROFITU                              |
//| Spočíta profit všetkých našich otvorených pozícií                |
//+------------------------------------------------------------------+
double GetTotalProfit()
{
   double totalProfit = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      //--- Pripočítaj profit a swap
      totalProfit += PositionGetDouble(POSITION_PROFIT);
      totalProfit += PositionGetDouble(POSITION_SWAP);
   }

   return totalProfit;
}

//+------------------------------------------------------------------+
//| ZATVORENIE VŠETKÝCH POZÍCIÍ                                      |
//| Zatvorí všetky naše otvorené pozície                             |
//+------------------------------------------------------------------+
void CloseAllPositions()
{
   int closedCount = 0;
   double closedProfit = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      //--- Zaznamenaj profit pred zatvorením
      closedProfit += PositionGetDouble(POSITION_PROFIT);
      closedProfit += PositionGetDouble(POSITION_SWAP);

      //--- Zatvor pozíciu
      if(trade.PositionClose(ticket))
         closedCount++;
   }

   Print("ZATVORENÉ ", closedCount, " POZÍCIÍ | Celkový profit: ", closedProfit);
}

//+------------------------------------------------------------------+
//| ZÍSKANIE POČTU POZÍCIÍ                                           |
//| Pomocná funkcia pre ladenie                                      |
//+------------------------------------------------------------------+
int GetPositionCount()
{
   int count = 0;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket <= 0)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
         continue;

      if(PositionGetString(POSITION_SYMBOL) != symbol)
         continue;

      count++;
   }

   return count;
}

//+------------------------------------------------------------------+
