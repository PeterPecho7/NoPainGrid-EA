# NoPain Grid EA - Trading Robot pre MetaTrader 5

## O projekte

Tento Expert Advisor (EA) implementuje **Grid Trading** stratégiu s prvkami **Martingale** na menovom páre **AUDCAD**.

Stratégia bola **reverse-engineerovaná** z úspešného obchodného signálu [NoPain MT5](https://www.mql5.com/en/signals/2262642), ktorý dosiahol:
- **Rast: 1,651%**
- **Win Rate: 63.67%** (5,544 obchodov)
- **Profit Factor: 1.69**
- **Priemerný zisk na obchod: $0.67**

---

## Ako stratégia funguje

### Grid Trading (Mriežkové obchodovanie)

```
Cena stúpa ↑         Cena klesá ↓

SELL 3  ════════     ════════  BUY 1 (vstup)
SELL 2  ════════     ════════  BUY 2 (+20 pips)
SELL 1  ════════     ════════  BUY 3 (+40 pips)
        (vstup)      ════════  BUY 4 (+60 pips)
```

1. **Vstup**: EA čaká na signál z RSI indikátora
2. **Grid**: Ak cena ide proti nám, otvárame ďalšie pozície každých 20 pipsov
3. **Martingale**: Každá ďalšia pozícia má väčší lot (1.2-1.5x)
4. **Výstup**: Keď celkový profit dosiahne cieľ (napr. 1% balance), zatvoríme všetko

### Kľúčové parametre zo signálu

| Parameter | Hodnota | Popis |
|-----------|---------|-------|
| Symbol | AUDCAD | Jediný obchodovaný pár |
| Grid Step | 20 pips | Vzdialenosť medzi pozíciami |
| Lot Multiplier | 1.2-1.5x | Navýšenie lotu pre ďalšie úrovne |
| Priemerný TP | 17 pips | Take profit pre jednotlivé obchody |
| Max Drawdown | 20.63% | Maximálny zaznamenaný drawdown |

---

## Súbory v projekte

| Súbor | Popis |
|-------|-------|
| `NoPainGrid_EA.mq5` | Základná verzia EA s RSI signálmi |
| `NoPainGrid_EA_v2.mq5` | Pokročilá verzia s BB + RSI a basket TP |
| `README.md` | Táto dokumentácia |
| `INSTALLATION.md` | Podrobný návod na inštaláciu |
| `ReportHistory-7024848.xlsx` | Historické obchody pre analýzu |

---

## Rýchly štart

### 1. Inštalácia

```bash
# Skopíruj EA súbor do MT5
cp NoPainGrid_EA.mq5 ~/Library/Application\ Support/MetaTrader\ 5/Bottles/*/drive_c/Program\ Files/MetaTrader\ 5/MQL5/Experts/
```

Alebo manuálne:
1. Otvor MetaTrader 5
2. Klikni `File` → `Open Data Folder`
3. Prejdi do `MQL5/Experts/`
4. Skopíruj tam `.mq5` súbor

### 2. Kompilácia

1. V MT5 otvor `MetaEditor` (F4)
2. Otvor súbor `NoPainGrid_EA.mq5`
3. Stlač `Compile` (F7)
4. Skontroluj, že nie sú žiadne chyby

### 3. Spustenie

1. V MT5 otvor chart **AUDCAD** (akýkoľvek timeframe)
2. V `Navigator` paneli nájdi EA pod `Expert Advisors`
3. Pretiahni EA na chart
4. Nastav parametre a klikni `OK`
5. Zapni `Algo Trading` tlačidlo v toolbare

---

## Nastavenia EA

### Hlavné parametre

```
=== HLAVNÉ NASTAVENIA GRIDU ===
Počiatočná veľkosť lotu    = 0.13   (pre $1000+ účet)
Násobič lotu               = 1.5    (50% navýšenie každú úroveň)
Rozostup mriežky           = 20     (pips medzi pozíciami)
Max úrovní gridu           = 10     (ochrana pred extrémom)
Take Profit                = 15     (pips na pozíciu)
Celkový TP %               = 1.0    (zatvorí všetko pri 1% zisku)

=== RIADENIE RIZIKA ===
Max Drawdown %             = 20.0   (núdzové zatvorenie)
Max Loty                   = 5.0    (limit celkovej expozície)
```

### Odporúčané nastavenia podľa účtu

| Zostatok | Lot Size | Grid Step | Max Levels |
|----------|----------|-----------|------------|
| $500     | 0.01     | 25        | 6          |
| $1,000   | 0.02     | 20        | 8          |
| $2,000   | 0.05     | 20        | 8          |
| $5,000   | 0.10     | 20        | 10         |
| $10,000  | 0.20     | 15        | 10         |

---

## Backtesting

### Ako spustiť backtest

1. V MT5 otvor `Strategy Tester` (Ctrl+R)
2. Nastav:
   - **Expert**: NoPainGrid_EA
   - **Symbol**: AUDCAD
   - **Period**: H1
   - **Model**: Every tick
   - **Deposit**: 1000
   - **Leverage**: 1:100
3. Klikni `Start`

### Odporúčané obdobie pre test

- **Minimálne**: 1 rok
- **Optimálne**: 2-3 roky
- **Zahrni**: Rôzne trhové podmienky (trending, ranging)

---

## Riziká a varovania

### Hlavné riziká Grid/Martingale stratégie

1. **Vysoký drawdown**: Pri silnom trende môže drawdown prekročiť 50%
2. **Margin call**: Nedostatočný kapitál = strata celého účtu
3. **Weekend gap**: Cena môže otvoriť ďaleko od piatkovej ceny

### Ako minimalizovať riziká

- Používaj na **demo účte** minimálne 1 mesiac
- Začni s **minimálnym lotom** (0.01)
- Nastav **max drawdown** na 15-20%
- **Neobchoduj** pred dôležitými správami (NFP, Fed, atď.)
- Maj vždy **zálohu kapitálu** pre krytie drawdownu

### Disclaimer

```
VAROVANIE: Obchodovanie na Forexe je vysoko rizikové.
Tento EA môže spôsobiť stratu celého vášho kapitálu.
Minulé výsledky nezaručujú budúce zisky.
Používajte na vlastné riziko.
```

---

## Rozdiely medzi verziami

### NoPainGrid_EA.mq5 (v1)
- Jednoduchý RSI signál pre vstup
- Základný grid management
- Individuálny TP pre každú pozíciu
- Vhodné pre začiatočníkov

### NoPainGrid_EA_v2.mq5 (v2)
- RSI + Bollinger Bands signály
- Basket TP (zatvorí všetko spolu)
- Viac možností TP (pips, peniaze, %)
- Time filter
- Spread filter
- Štatistiky obchodovania
- Vhodné pre pokročilých

---

## Často kladené otázky

### Q: Môžem použiť EA na iných pároch?
**A:** EA je optimalizovaný pre AUDCAD. Na iných pároch treba upraviť grid step a lot size.

### Q: Aký minimálny zostatok potrebujem?
**A:** Minimum $500 s lotom 0.01. Odporúčané $1000+ pre bezpečnú prevádzku.

### Q: Môže EA bežať 24/7?
**A:** Áno, ale odporúčam vypnúť pred víkendom (piatok večer) kvôli weekend gapu.

### Q: Prečo EA neobchoduje?
**A:** Skontroluj:
- Je zapnutý "Algo Trading"?
- Je správny symbol (AUDCAD)?
- Je v obchodných hodinách?
- RSI nie je v neutrálnej zóne?

---

## Podpora a kontribúcie

### Nahlásenie chyby
Otvor issue na GitHub s popisom problému a logom z MT5.

### Vylepšenia
Pull requesty sú vítané! Prosím dodržuj existujúci štýl kódu.

---

## Licencia

Tento projekt je voľne dostupný pre osobné použitie.
Komerčné použitie vyžaduje povolenie autora.

---

## Changelog

### v1.00 (Január 2025)
- Prvé vydanie
- Grid trading s RSI signálmi
- Martingale lot sizing
- Základný risk management
