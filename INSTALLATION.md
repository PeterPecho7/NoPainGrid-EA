# Návod na inštaláciu NoPain Grid EA

Tento návod ťa prevedie kompletnou inštaláciou a spustením EA v MetaTrader 5.

---

## Obsah

1. [Požiadavky](#požiadavky)
2. [Inštalácia MetaTrader 5](#inštalácia-metatrader-5)
3. [Kopírovanie EA súborov](#kopírovanie-ea-súborov)
4. [Kompilácia EA](#kompilácia-ea)
5. [Spustenie EA](#spustenie-ea)
6. [Nastavenie parametrov](#nastavenie-parametrov)
7. [Testovanie na Demo účte](#testovanie-na-demo-účte)
8. [Riešenie problémov](#riešenie-problémov)

---

## Požiadavky

### Softvér
- **MetaTrader 5** (MT5) - stiahnuť z [metatrader5.com](https://www.metatrader5.com/en/download)
- Broker s podporou MT5 a symbolom **AUDCAD**

### Odporúčaní brokeri (s AUDCAD)
- IC Markets
- Pepperstone
- FP Markets
- XM
- FXCM

### Hardvér
- Windows 10/11 alebo macOS (cez Wine/CrossOver)
- Minimálne 4GB RAM
- Stabilné internetové pripojenie

---

## Inštalácia MetaTrader 5

### Windows

1. Stiahni MT5 z [metatrader5.com](https://www.metatrader5.com/en/download)
2. Spusti inštalátor `mt5setup.exe`
3. Sleduj inštrukcie inštalátora
4. Po inštalácii sa MT5 automaticky spustí

### macOS

1. Stiahni MT5 z App Store alebo [metatrader5.com](https://www.metatrader5.com/en/download)
2. Ak sťahuješ z webu, otvor `.dmg` súbor
3. Presuň MetaTrader 5 do Applications
4. Pri prvom spustení klikni pravým tlačidlom → Open

---

## Kopírovanie EA súborov

### Krok 1: Nájdi Data Folder

1. Otvor MetaTrader 5
2. Klikni `File` → `Open Data Folder`
3. Otvorí sa priečinok s dátami MT5

### Krok 2: Naviguj do Experts priečinka

V Data Folder prejdi do:
```
MQL5/
  └── Experts/
```

### Krok 3: Skopíruj EA súbory

Skopíruj tieto súbory do `MQL5/Experts/`:
- `NoPainGrid_EA.mq5`
- `NoPainGrid_EA_v2.mq5`

### Alternatíva: Príkazový riadok (macOS)

```bash
# Nájdi Data Folder
cd ~/Library/Application\ Support/MetaTrader\ 5/Bottles/*/drive_c/Program\ Files/MetaTrader\ 5/MQL5/Experts/

# Skopíruj EA
cp /Users/peterpecho/Desktop/Trading\ robot/NoPainGrid_EA.mq5 .
cp /Users/peterpecho/Desktop/Trading\ robot/NoPainGrid_EA_v2.mq5 .
```

---

## Kompilácia EA

EA súbor (.mq5) musí byť skompilovaný do .ex5 formátu, aby mohol byť spustený.

### Krok 1: Otvor MetaEditor

- V MT5 stlač `F4` alebo klikni `Tools` → `MetaQuotes Language Editor`

### Krok 2: Otvor EA súbor

1. V MetaEditor klikni `File` → `Open`
2. Naviguj do `MQL5/Experts/`
3. Vyber `NoPainGrid_EA.mq5`

### Krok 3: Kompiluj

1. Stlač `F7` alebo klikni `Compile`
2. V spodnej časti obrazovky uvidíš výsledok
3. **Úspech**: `0 error(s), 0 warning(s)`

### Chyby pri kompilácii

Ak vidíš chyby:
- **'Trade.mqh' not found**: Skontroluj, či máš správnu verziu MT5
- **Syntax error**: Skontroluj, či sa súbor správne skopíroval

---

## Spustenie EA

### Krok 1: Otvor AUDCAD chart

1. V MT5 klikni `File` → `New Chart` → `AUDCAD`
2. Alebo nájdi AUDCAD v Market Watch (Ctrl+M) a dvojklikni

### Krok 2: Pridaj EA na chart

1. Otvor `Navigator` panel (Ctrl+N)
2. Rozbaľ `Expert Advisors`
3. Nájdi `NoPainGrid_EA`
4. Pretiahni EA na AUDCAD chart

### Krok 3: Nastav parametre

V dialógovom okne:

1. **Tab "Common"**:
   - ☑ Allow Algo Trading
   - ☑ Allow DLL imports (ak potrebné)

2. **Tab "Inputs"**:
   - Nastav parametre podľa tvojho účtu (viď nižšie)

3. Klikni `OK`

### Krok 4: Zapni Algo Trading

1. Na toolbare nájdi tlačidlo `Algo Trading`
2. Klikni naň, aby bolo zelené (zapnuté)
3. EA by mal byť teraz aktívny

---

## Nastavenie parametrov

### Pre Demo účet ($1000)

```
=== HLAVNÉ NASTAVENIA GRIDU ===
Počiatočná veľkosť lotu    = 0.02
Násobič lotu               = 1.3
Rozostup mriežky           = 20
Max úrovní gridu           = 8
Take Profit                = 15
Celkový TP %               = 1.0

=== RIADENIE RIZIKA ===
Max Drawdown %             = 20.0
Max Loty                   = 2.0
```

### Pre Live účet (konzervatívne)

```
=== HLAVNÉ NASTAVENIA GRIDU ===
Počiatočná veľkosť lotu    = 0.01
Násobič lotu               = 1.2
Rozostup mriežky           = 25
Max úrovní gridu           = 6
Take Profit                = 20
Celkový TP %               = 0.5

=== RIADENIE RIZIKA ===
Max Drawdown %             = 15.0
Max Loty                   = 1.0
```

---

## Testovanie na Demo účte

### Vytvorenie Demo účtu

1. V MT5 klikni `File` → `Open an Account`
2. Vyber svojho brokera
3. Vyber `Open a demo account`
4. Vyplň údaje a vyber:
   - **Deposit**: $1000-10000
   - **Leverage**: 1:100

### Testovanie EA

1. Pridaj EA na AUDCAD chart
2. Nechaj bežať minimálne 1-2 týždne
3. Sleduj:
   - Počet obchodov
   - Win rate
   - Maximálny drawdown
   - Celkový profit

### Backtest v Strategy Tester

1. Otvor `Strategy Tester` (Ctrl+R)
2. Nastav:
   - **Expert**: NoPainGrid_EA
   - **Symbol**: AUDCAD
   - **Period**: H1
   - **Date**: Posledný 1 rok
   - **Model**: Every tick based on real ticks
   - **Deposit**: 1000
   - **Leverage**: 1:100
3. Klikni `Start`

---

## Riešenie problémov

### EA sa nezobrazuje v Navigator

1. Skontroluj, či je súbor v správnom priečinku
2. Reštartuj MT5
3. Skompiluj EA znovu

### EA neobchoduje

Skontroluj:
1. ☑ Je `Algo Trading` zapnuté? (zelené tlačidlo)
2. ☑ Je správny symbol (AUDCAD)?
3. ☑ Je RSI v extrémnej zóne?
4. ☑ Sú obchodné hodiny?
5. Pozri záložku `Experts` pre chybové správy

### Chyba "Trade context busy"

- EA sa pokúša obchodovať príliš rýchlo
- Počkaj niekoľko sekúnd a skús znova

### Chyba "Not enough money"

- Nedostatok marginov pre otvorenie pozície
- Zníž lot size alebo doplň účet

### Chyba "Invalid stops"

- TP/SL sú príliš blízko aktuálnej ceny
- Zväčši vzdialenosť TP v nastaveniach

### EA sa zastavil

1. Skontroluj `Journal` záložku pre chyby
2. Skontroluj `Experts` záložku pre EA logy
3. Skontroluj, či je účet stále aktívny

---

## Kontrolný zoznam pred spustením na Live účte

- [ ] Úspešný backtest minimálne 1 rok
- [ ] Demo test minimálne 2 týždne
- [ ] Pochopenie všetkých parametrov
- [ ] Správne nastavený lot size pre tvoj zostatok
- [ ] Max drawdown nastavený konzervatívne (15-20%)
- [ ] Záloha pre prípad straty
- [ ] Pripravený na dlhodobé držanie pozícií

---

## Podpora

Ak máš problémy:
1. Skontroluj záložku `Experts` v MT5 pre logy
2. Skontroluj záložku `Journal` pre systémové správy
3. Otvor issue na GitHub s:
   - Screenshotom chyby
   - Nastaveniami EA
   - Verziou MT5
