# SP500 Multi-Regime Trading EA

Multi-režimový robot pre S&P 500 index s vysokou pákou. Automaticky detekuje režim trhu a vyberá najvhodnejšiu stratégiu.

## Stratégie

### 1. VWAP Mean Reversion (50-60% obchodov)
**Core stratégia** - obchoduje návrat ceny k VWAP.

| Podmienka | LONG | SHORT |
|-----------|------|-------|
| Vzdialenosť od VWAP | < VWAP - 0.5×ATR | > VWAP + 0.5×ATR |
| RSI(5) | < 30 | > 70 |
| Take Profit | VWAP | VWAP |
| Stop Loss | 15 bodov | 15 bodov |

**Edge:** Inštitúcie benchmarkujú VWAP → cena sa vracia "strojovo"

---

### 2. Opening Range Breakout (20-25% obchodov)
**High R:R stratégia** - zachytáva volatilné dni.

```
Setup:
├── Čakaj 15 min po US open (15:30 server time)
├── Zaznamenaj HIGH a LOW opening range
└── Čakaj na breakout

LONG: Cena > ORB High + 3 body
├── SL: ORB Low
├── TP: 2× vzdialenosť OR
└── Max 1 trade denne

SHORT: Cena < ORB Low - 3 body
├── SL: ORB High
├── TP: 2× vzdialenosť OR
```

---

### 3. Trend Following (15-20% obchodov)
**PnL booster** - využíva silné trend days.

```
Detekcia trend dňa:
├── Cena nad/pod VWAP 60+ minút
├── EMA(9) > EMA(21) > EMA(50) [alebo opačne]
└── RSI udržuje smer

Entry na pullback:
├── Cena dotkne EMA(21) alebo VWAP
├── SL: 25 bodov
└── TP: Trailing 30 bodov
```

---

## Parametre

### Risk Management
| Parameter | Default | Popis |
|-----------|---------|-------|
| InpRiskPercent | 1.0% | Risk na 1 trade |
| InpMaxDailyLoss | 3.0% | Denný strop straty |
| InpMaxTradesDay | 5 | Max trades za deň |
| InpMaxSpread | 5.0 | Max spread (body) |

### VWAP Mean Reversion
| Parameter | Default | Popis |
|-----------|---------|-------|
| InpUseMeanRev | true | Povoliť stratégiu |
| InpVWAPDistance | 0.5 | Vzdialenosť × ATR |
| InpMRStopLoss | 15 | SL v bodoch |
| InpMRRSIOver | 70 | RSI prekúpené |
| InpMRRSIUnder | 30 | RSI prepredané |

### Opening Range Breakout
| Parameter | Default | Popis |
|-----------|---------|-------|
| InpUseORB | true | Povoliť stratégiu |
| InpORBMinutes | 15 | Trvanie OR (min) |
| InpORBBuffer | 3 | Buffer pre breakout |
| InpMaxORBTrades | 1 | Max ORB trades/deň |
| InpORBRRRatio | 2.0 | R:R pomer |

### Trend Following
| Parameter | Default | Popis |
|-----------|---------|-------|
| InpUseTrend | true | Povoliť stratégiu |
| InpTrendMinMin | 60 | Min minút pre trend |
| InpTrendTrailing | 30 | Trailing (body) |
| InpTrendSL | 25 | SL v bodoch |

### Trading Session
| Parameter | Default | Popis |
|-----------|---------|-------|
| InpSessionStartH | 15 | Štart hodina (server) |
| InpSessionStartM | 30 | Štart minúta |
| InpSessionEndH | 22 | Koniec hodina |
| InpSessionEndM | 0 | Koniec minúta |
| InpCloseEOD | true | Auto-close EOD |

---

## Vizualizácia

EA zobrazuje na grafe:
- **VWAP línia** (modrá) - hlavný benchmark
- **ORB High** (zelená čiarkovaná) - opening range high
- **ORB Low** (červená čiarkovaná) - opening range low
- **Info panel** - aktuálny režim, indikátory, štatistiky

---

## Auto Lot Sizing

Robot automaticky vypočítava lot size podľa:
```
lot = (balance × risk%) / (SL_body × hodnota_bodu)
```

**Príklad pre $2000 účet, 1% risk, SL 20 bodov:**
- Lot ≈ 0.10 na US500

Pri raste účtu sa lot automaticky zväčšuje, pri poklese zmenšuje.

---

## Inštalácia

1. Skopíruj `SP500_MultiRegime.mq5` do MT5 Experts folder
2. V MT5 otvor MetaEditor (F4)
3. Kompiluj (F7)
4. Pretiahni EA na US500 chart
5. Nastav Symbol parameter ak treba (US500.cash, SPX500, atď.)
6. Zapni "Algo Trading"

---

## Bezpečnostné prvky

**Čo robot NEROBÍ:**
- ❌ Martingale - žiadne zdvojovanie po strate
- ❌ Averaging down - žiadne pridávanie do straty
- ❌ Overnight držanie - close pred koncom session
- ❌ Vysokofrekvenčný scalping - min M5 timeframe

**Ochranné mechanizmy:**
- ✅ Max 1% risk na trade
- ✅ Max 3% denná strata
- ✅ Max 5 trades denne
- ✅ Spread filter
- ✅ Session filter

---

## Backtesting

```
Symbol: US500 (alebo US500.cash)
Timeframe: M5
Period: minimálne 1 rok
Model: Every tick
Deposit: $1000-5000
Leverage: 1:100
```

---

## Changelog

### v1.00 (Január 2025)
- Initial release
- 3 stratégie: Mean Reversion, ORB, Trend Following
- Custom VWAP výpočet
- Auto lot sizing
- Vizualizácia (VWAP, ORB, Info panel)
- Discord/Push notifikácie
