# BE MarginLevel Lines — MT4 Expert Advisor

An MT4 trade-management tool that shows **where your account breaks even** and **where margin gets dangerous**, right on the chart, plus one-click buttons to manage TPs and close positions.

The lines update in real time: open, close or resize a position and they move to the new levels within a second.

---

## Features

### Chart lines
| Line | Meaning |
|---|---|
| **Equity = Balance** (blue) | The price where total floating P/L is zero and your account is back to breakeven |
| **GAME OVER X%** (red, thick) | The price where margin level hits your danger level (default 120%), as a warning before a margin call or stop-out |
| **Custom ML %** (gold) | The price where margin level reaches the % you type in the on-chart box, with the **equity at that level** and the change from now |

Each line shows its price and its distance in pips from the current price.

### Info panel
Net lots, money per pip, balance, equity and current margin level. It also warns you when:
- the position is **fully hedged** (net 0 lots, so there's no breakeven price), or
- **other symbols** have open orders (they're assumed to stay fixed).

### Buttons
| Button | What it does |
|---|---|
| **Set BE TP** | Sets each order's TP to the Equity = Balance level, **only if that level is a valid TP** for the order (above price for buys, below for sells). Orders where it would act as an SL are skipped. |
| **Auto TP: ON/OFF** | Keeps the TPs following the breakeven line automatically as it moves. |
| **Close Profit** | Closes every position with net profit > 0 (profit + swap + commission). Losing positions are ignored. |
| **Half Profit** | Closes **half the lots** of every profitable position, rounded to the broker's lot step. Positions too small to split are skipped. |
| **Half Loss** | Closes **half the lots** of every losing position. Profitable positions are ignored. Always shows a **warning window** first, including the approximate loss that will be realized. |
| **Risk Tool: ON/OFF + Mode + Risk box** | Position sizing from a fixed money risk. Drag the red SL line (and the turquoise Entry line in PENDING mode); lots are calculated so the loss at SL is at most your risk (rounded down, spread and optional commission included). Direction and LIMIT/STOP type are chosen from the line positions. The trade button (e.g. "BUY LIMIT 0.37") asks for confirmation unless **Confirm: OFF** (one-click trading, with a warning when switching off). |
| **N box + Close Last N** | Closes the N most recently opened positions (newest open time first). Always shows a confirmation listing each ticket, side, lots, entry and P/L, with "No" as default. |
| **CLOSE ALL** | Force-closes every position. Opens a **confirmation window** first, showing the count, lots and P/L, with "No" selected by default. |
| **Daily %: ON/OFF** | Toggles dark-green percentage lines around the day's open (01:00 server time by default): 0% at the open, then ±1% … ±7%. Re-anchors automatically each new day and remembers its state across timeframe changes. |
| **NY Levels: ON/OFF** | Toggles NY-session reference levels for the last N days: Overnight high/low (00:00–05:00 NY), PreMarket high/low (07:00–09:00 NY), Midnight Open, Previous Day Regular Close (16:14 NY candle) and Extended Hour Open (18:00 NY). Times, colors and the NY→server offset (default +7h) are inputs. Refreshes every new M1 bar. Drawing only, never touches orders. |
| **ML % box + Set ML SL/TP** | Puts the custom margin-level line on every open order as **SL or TP**, following MT4's rules (above price: TP for buys, SL for sells; below: the opposite), so the whole basket closes together at that equity. Warns if the level is at or below the broker's stop-out. |
| **Drag the gold line** | Select the gold line (double-click) and drag it: the margin level % is recalculated from the new price and the box updates. Orders only change when you press Set ML SL/TP (or when ML Auto is ON). |
| **ML Auto: ON/OFF** | Keeps the SL/TP following the custom margin-level line as it moves. Can't run together with Auto BE TP. |
| **Set TP (pts)** + input box | Sets TP on **open and pending** orders to entry ± N points (default 6000). You can edit the value on the chart; the price equivalent is shown live. Switches Auto BE TP off automatically. |

---

## How it works

For one symbol, equity changes linearly with price:

```
Equity(P) = E0 + V × (P − Bid)
V = net lots × TickValue / TickSize
```

From that:

```
Equity = Balance   →  P = Bid + (Balance − Equity) / V
Margin Level = X%  →  P = Bid + (X/100 × Margin − Equity) / V
```

It recalculates on every tick **and** on a 500 ms timer, so the lines update even when the market is quiet.

---

## Installation

1. In MT4: **File → Open Data Folder → MQL4 → Experts**
2. Copy `BE_MarginLevel_Lines.mq4` into that folder
3. Open MetaEditor and compile it (F7), or restart MT4
4. Drag the EA onto a chart and tick **Allow live trading**
5. Make sure **AutoTrading** is enabled in the toolbar

---

## Inputs

| Input | Default | Description |
|---|---|---|
| `MarginLevelTarget` | 120.0 | Margin level % for the red line |
| `MagicFilter` | -1 | Only manage orders with this magic number (-1 = all) |
| `AutoSetTP` | false | Start with Auto BE TP on |
| `BasketCloseAtBE` | false | Close all symbol orders when equity climbs back up to balance |
| `MinTPChangePoints` | 3 | Minimum TP change (points) before re-modifying |
| `Slippage` | 5 | Max slippage for closing (points) |
| `CloseAllSymbols` | false | Close buttons act on all symbols instead of the chart symbol only |
| `ConfirmProfitClose` | false | Also ask for confirmation on Close Profit / Half Profit |
| `FixedTPPoints` | 6000 | Default distance for the Set TP button |
| `DailyOpenHour` | 1 | Hour (server time) of the day open used as the 0% line |
| `DailyPctStep` | 1.0 | % step between daily lines |
| `DailyPctCount` | 7 | Number of daily lines above and below the open |
| `DailyPctColor` | DarkGreen | Daily line color |
| `DailyPctFullWidth` | false | Full-width lines instead of starting at the day open |
| `TimerMs` | 500 | Refresh interval |
| Colors / styles / font size | — | Appearance of the lines and labels |

---

## Notes & limitations

- **Points vs price:** a "point" is the symbol's smallest price step. On a 2-digit NAS100 (27000.00), 5000 points = 50.00 in price. Check the label next to the Set TP box.
- **Mixed buys and sells:** if the buys hit the breakeven TP and the sells were skipped, the sells stay open at a loss. Use `BasketCloseAtBE` if you want the whole basket closed flat together.
- **Other symbols:** the lines are exact for the chart symbol. P/L on other symbols is treated as constant.
- **Pending orders** are only touched by the Set TP (pts) button. The close buttons act on open positions only.
- The breakeven and margin-level lines are estimates. Tick value on cross pairs, swaps and changing margin can shift them slightly; they're recalculated continuously.

---

## Disclaimer

This software is provided as-is, with no warranty. Trading leveraged products carries a high level of risk. **Test on a demo account first.** The author is not responsible for any financial loss caused by using this tool.
