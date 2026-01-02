# Trading Robots - MetaTrader 5 Expert Advisors

Kolekcia automatizovaných obchodných robotov (Expert Advisors) pre MetaTrader 5.

---

## Roboty v projekte

### 1. AUDCAD Grid EA (Claude_Like_NoPain)
**Adresár:** `AUDCAD_GridEA/`

Grid trading stratégia s RSI signálmi pre AUDCAD.

| Vlastnosť | Hodnota |
|-----------|---------|
| Symbol | AUDCAD |
| Stratégia | Grid + Martingale |
| Verzia | 4.30 |
| Risk Management | DD%, Equity $, Breakeven |

**Funkcie:**
- Multi-Timeframe RSI analýza (D1/H4/H1)
- Trailing Stop s dynamickým krokom
- Dynamic TP podľa ATR
- Spread filter
- Equity protection ($ limit)
- Breakeven protection
- Discord/Push notifikácie
- Info panel s live dátami

---

### 2. SP500 Multi-Regime EA
**Adresár:** `SP500_MultiRegime/`

Multi-režimový robot pre S&P 500 index s vysokou pákou.

| Vlastnosť | Hodnota |
|-----------|---------|
| Symbol | US500 (IC Markets) |
| Stratégie | Mean Reversion, ORB, Trend Following |
| Verzia | 1.00 |
| Páka | 1:100+ |

**3 stratégie v jednom:**

1. **VWAP Mean Reversion (50-60%)** - Core stratégia
   - Obchoduje návrat ceny k VWAP
   - RSI < 30 = BUY, RSI > 70 = SELL
   - TP na VWAP úrovni

2. **Opening Range Breakout (20-25%)** - High R:R
   - Prvých 15 min definuje range
   - Breakout = vstup s 2:1 R:R
   - Max 1 ORB trade denne

3. **Trend Following (15-20%)** - PnL booster
   - Detekcia trend dňa (60+ min nad VWAP)
   - Entry na pullback k EMA/VWAP
   - Trailing stop

**Funkcie:**
- Automatická detekcia režimu trhu
- Custom VWAP výpočet
- Auto lot sizing (škáluje s účtom)
- Trading session filter (US market hours)
- Vizualizácia: VWAP, ORB levels, Regime panel
- Discord/Push notifikácie
- End of Day auto-close

---

## Štruktúra projektu

```
Trading robot/
├── README.md                      # Tento súbor
├── .gitignore
│
├── AUDCAD_GridEA/                 # Grid robot pre AUDCAD
│   ├── Claude_Like_NoPain.mq5     # Hlavný EA súbor
│   ├── Claude_Like_NoPain.ex5     # Skompilovaný
│   ├── INSTALLATION.md            # Návod na inštaláciu
│   ├── create_documentation.py    # PDF generátor
│   └── Claude_Like_NoPain_Documentation.pdf
│
└── SP500_MultiRegime/             # Multi-regime robot pre S&P 500
    └── SP500_MultiRegime.mq5      # Hlavný EA súbor
```

---

## Inštalácia

### Požiadavky
- MetaTrader 5 (IC Markets alebo iný broker)
- Účet s prístupom k AUDCAD a US500
- Windows/Mac s MT5

### Kroky

1. **Skopíruj EA súbory do MT5:**
   ```bash
   # macOS - IC Markets
   cp AUDCAD_GridEA/Claude_Like_NoPain.mq5 \
      ~/Library/Application\ Support/net.metaquotes.wine.metatrader5/drive_c/Program\ Files/MetaTrader\ 5/MQL5/Experts/

   cp SP500_MultiRegime/SP500_MultiRegime.mq5 \
      ~/Library/Application\ Support/net.metaquotes.wine.metatrader5/drive_c/Program\ Files/MetaTrader\ 5/MQL5/Experts/
   ```

2. **Kompiluj v MetaEditore:**
   - Otvor MetaEditor (F4 v MT5)
   - File → Open → vyber .mq5 súbor
   - Compile (F7)

3. **Spusti EA:**
   - Pretiahni EA na chart
   - Nastav parametre
   - Zapni "Algo Trading"

---

## Risk Management

### AUDCAD Grid EA
| Parameter | Default | Popis |
|-----------|---------|-------|
| Risk % | 2% | Risk na grid sériu |
| Max DD % | 15% | Zatvorí všetko |
| Max Loss $ | 0 | Equity protection (0=off) |
| Max Spread | 3 pips | Blokuje obchody |

### SP500 Multi-Regime EA
| Parameter | Default | Popis |
|-----------|---------|-------|
| Risk % | 1% | Risk na 1 trade |
| Max Daily Loss | 3% | Denný strop |
| Max Trades/Day | 5 | Prevencia overtrading |
| Max Spread | 5 pts | Filter |

---

## Backtesting

### AUDCAD Grid EA
```
Symbol: AUDCAD
Timeframe: H1
Period: 2+ rokov
Model: Every tick
Deposit: $1000-5000
Leverage: 1:100
```

### SP500 Multi-Regime EA
```
Symbol: US500
Timeframe: M5 (EA použije M5 automaticky)
Period: 1+ rok
Model: Every tick
Deposit: $1000-5000
Leverage: 1:100
```

---

## Upozornenia

**VAROVANIE:**
- Obchodovanie je vysoko rizikové
- Vysoká páka znásobuje zisky AJ straty
- Grid/Martingale stratégie môžu viesť k vysokým drawdownom
- Minulé výsledky nezaručujú budúce zisky
- Vždy testuj na DEMO účte najprv
- NIKDY neriskuj peniaze ktoré si nemôžeš dovoliť stratiť

---

## Changelog

### AUDCAD Grid EA
- **v4.30** - Spread filter, Equity protection, Breakeven
- **v4.20** - MTF analysis (D1/H4/H1)
- **v4.10** - Trailing stop, Dynamic TP
- **v4.00** - Auto-optimized pre IC Markets

### SP500 Multi-Regime EA
- **v1.00** - Initial release
  - 3 stratégie (Mean Reversion, ORB, Trend Following)
  - VWAP custom implementation
  - Auto lot sizing
  - Vizualizácia

---

## Autor

Vyvinuté s pomocou Claude AI.

---

## Licencia

Voľne dostupné pre osobné použitie.
