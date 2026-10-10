# Wise Fractal — MetaTrader 5 Expert Advisor

[English](README.en.md) | [فارسی](README.md)

**Wise Fractal** is an **MQL5** Expert Advisor that examines fractals and price swings within a configured trading session, determines a Buyer/Seller direction, and manages trades using retracement entries, stop loss, take profit, position sizing, and reverse orders. It also displays relevant levels and signals on the chart.

This README documents the source files available in the project folder. Last reviewed: **2026-10-11**.

> **Current execution status:** The source has a hardcoded expiration time of `2025.06.30 23:59:59`. When chart time passes this date, the EA prints an expiration message and removes itself using `ExpertRemove()`. The `Expiration` input is display text only; changing it in Inputs or a `.set` file does not change the actual expiration time.

## Main version

The only published source is [Wise_Fractal.mq5](Wise_Fractal.mq5). Its `#property version` is `5.60`; the filename stays fixed to avoid multiple versioned source files.

This publication aligns the project name, source header, and version metadata. The selected source's trading logic is unchanged.

## Features

- Upper and lower fractals from the built-in `iFractals` indicator on the current symbol and timeframe.
- Evaluation of pre-session fractal levels and visualization of swings and valid swings.
- Buyer, Seller, and Both direction states with chart arrows.
- Retracement entry calculation using `Retracement`, followed by `BuyLimit` or `SellLimit` placement.
- A market-entry fallback when a Limit order fails with error `4756`.
- Position sizing based on a percentage of account Balance and the entry-to-stop-loss distance.
- Main-trade take profit using `RiskOnReward` and stop-loss adjustment at the `RiskFree` threshold.
- Optional reverse `BuyStop` or `SellStop` orders at the main trade's stop-loss level.
- An entry-to-stop-loss distance filter using a 50-period ATR on H1.
- Time-based pending-order management and a holiday list defined in the source.
- A custom optimization score in `OnTester()`.

## Project files

The repository contains one main source file and documentation in two languages.

| File or group | Purpose |
| --- | --- |
| `Wise_Fractal.mq5` | Main EA source; includes `OnTester()` |
| `README.md` | Persian documentation |
| `README.en.md` | English documentation |

No `.set` preset is included in this publication. If you use your own saved settings, check the actual input names and values after loading them.

## Requirements and installation

MetaTrader 5 and MetaEditor are required. The baseline source uses the standard `<Trade/Trade.mqh>` library and built-in Fractals and ATR indicators. No dependency on a DLL, custom indicator, or external API was found in that source.

1. In MetaTrader 5, select **File → Open Data Folder**.
2. Create a folder such as `WiseFractal` under `MQL5/Experts` and place `Wise_Fractal.mq5` there.
3. Open the source in MetaEditor and select **Compile / F7**. Review compilation errors and warnings.
4. Refresh the Expert Advisors list in MetaTrader's Navigator and select the compiled EA.
5. Evaluate it in the Strategy Tester first, then on a demo account. The existing source stops on a chart with current dates because of its expiration restriction. Execution after expiration requires a separate source change and recompilation.
6. For demo execution after addressing that restriction, attach the EA to a chart, review Inputs, and enable **Algo Trading** in both the EA settings and the platform.

MetaEditor is the official MQL5 editing and compilation environment. See the official [EA creation and compilation guide](https://www.metatrader5.com/en/terminal/help/algotrading/autotrading) and [EA settings and Algo Trading guide](https://www.metatrader5.com/en/terminal/help/algotrading/trade_robots_indicators).

### Symbol, timeframe, and session time

The source uses `_Symbol` rather than a hardcoded symbol. Fractals and swings use the chart's `_Period`; ATR is calculated separately on `PERIOD_H1`.

Parts of the algorithm use differences in minutes as bar counts and compare session boundaries against exact bar-opening times. Therefore, **M1 is a reasonable starting point for evaluating this source**; other timeframes require separate verification.

Session start and end use the broker's chart time, rather than Tehran time. Only the seconds-based `SecondOffset` condition uses `TimeLocal()`. Align session settings with broker server time and activate the EA before the session starts so that it can perform its daily reset.

## Strategy workflow

1. **Initialization:** `OnInit()` calculates the internal Pip unit, prepares session times and the Fractals indicator, and draws fractals and swings.
2. **Session start:** Direction, valid-swing state, entry permission, and trade lines are reset at the configured start time.
3. **Direction selection:** In `SetTarget()`, a closed candle's High reaching the upper fractal level creates a Seller target; its Low reaching the lower fractal level creates a Buyer target. If a valid fractal is unavailable, the pre-session High/Low is used. If both targets appear in the same candle, the candle body's direction determines which target is selected and locked.
4. **Structure validation:** `ValidSwing()` evaluates a valid swing using fractal structure and Open/Close and High/Low prices.
5. **Entry:** After more than one minute has elapsed from session start, `CheckToSetOrder()` checks entry conditions, stop-loss distance, and the retracement level before sending an order. `UpdateOrder()` can adjust orders through the paths defined in the source.
6. **Management:** The EA manages stop loss, take profit, reverse orders, and stop-loss movement toward entry. At session end, it checks whether to delete the main pending order. Reverse-order deletion depends on trade state, with another deletion path at 23:00. Session end does not automatically close an open position.

### Retracement entry and take profit

For the initial Limit-order path, let `P` be the reference price and `SL` the stop-loss price:

```text
Sell: Entry = SL - (SL - P) × Retracement / 100
Buy:  Entry = SL + (P - SL) × Retracement / 100

Sell: TP = Entry - abs(Entry - SL) × RiskOnReward
Buy:  TP = Entry + abs(Entry - SL) × RiskOnReward
```

Thus, `Retracement=40` places entry at a distance from SL equal to 40% of the reference-price-to-SL distance. Do not interpret it simply as a 40% retracement measured from the reference price. In the market-entry fallback, volume and TP are recalculated using Bid/Ask.

### Position sizing, break even, and reverse orders

The nominal risk budget is `ACCOUNT_BALANCE × RiskPercent / 100`. `CalculateLotSize()` uses entry-to-SL distance, Tick Size, and Contract Size to calculate volume, then constrains it to the symbol's minimum and maximum volume. This is a nominal target; monetary price-movement conversion, minimum lot size, and volume rounding require verification for each symbol.

When favorable price movement reaches `RiskFree` times the original entry-to-SL distance, the code attempts to move SL to `Entry + RiskFreeSLOffset × Pip` for a buy or `Entry - RiskFreeSLOffset × Pip` for a sell. A zero offset means the entry price; trading costs are not included in this calculation.

With `ReversePositionEN` enabled, an opposite pending order is placed at the main trade's SL. Its stop-loss distance is controlled by `DownLimit`, `UpLimit`, and `UpLimitForSet`. The reverse order's take profit is one stop-loss distance away and does not use the main trade's `RiskOnReward`. Under specific conditions, the code also attempts to delete the reverse order after a new deal appears in account history.

## Main inputs

These are defaults from the baseline source. Loading a `.set` file may change them.

| Input | Default | Purpose |
| --- | --- | --- |
| `RiskPercent` | `1.0` | Percentage of Balance used as the nominal risk budget |
| `RiskOnReward` | `3.0` | Main-trade TP multiplier of entry-to-SL distance |
| `RiskFree` | `1.8` | Favorable movement threshold for SL adjustment, in multiples of original SL distance |
| `RiskFreeSLOffset` | `0` | New SL offset from entry, in internal Pip units |
| `StopLossOffset` | `0` | Structural SL adjustment, in internal Pip units |
| `PipAlertX` | `7.47` | ATR multiplier for the distance filter; the code checks `distance < PipAlertX × ATR(H1,50) × Pip` |
| `Retracement` | `40.0` | Percentage of reference-price-to-SL distance used to calculate entry |
| `SecondOffset` | `0` | Minimum local-clock second value for the scheduled processing block |
| `ReversePositionEN` | `true` | Enables reverse orders |
| `DownLimit` | `50` | Minimum reverse-order SL distance, in internal Pip units |
| `UpLimit` | `285` | Upper distance threshold that triggers reverse-order adjustment |
| `UpLimitForSet` | `185` | Replacement distance when the original distance exceeds `UpLimit` |
| `FractalsNumber` | `14` | Target number of valid fractals searched for on each side |
| `DayNumber` | `1` | Number of days searched for fractals |
| `StartHour` / `StartMinute` | `16` / `30` | Session start in broker chart time |
| `EndHour` / `EndMinute` | `18` / `0` | End of the entry-evaluation session |
| `CandleNumber` | `0` | Distance threshold in some swing construction/update conditions; dependent on the code's minute-based logic |
| `DrawingStartOffset` | `2` | Moves the swing search start back by two hours |

Visual settings include `UpFractalClr`, `DownFractalClr`, `WithFractal`, `StyleFractal`, `SwingLinesClr`, `ValidSwingUpClr`, `ValidSwingDownClr`, `TargetSellerArrowClr`, and `TargetBuyerArrowClr`. `WithFractal` is the actual spelling of the width input in the source.

`BuyPosition`, `SellPosition`, `ReverseBuyPosition`, and `ReverseSellPosition` set order comments. String inputs used as group separators, such as `RiskManagement` and `Expiration`, are not operational settings.

## Backtesting and optimization

1. In the Strategy Tester, select the compiled build of your chosen source.
2. Record the symbol, timeframe, account configuration, and test dates. The current source does not run past its expiration time; historical tests must use dates before that limit.
3. **Load** your `.set` file in Inputs and check parameter names and values.
4. To evaluate entries and reverse orders, use **Every tick based on real ticks** when suitable data is available. Enable Visual Mode to compare chart levels and orders.
5. Review Experts/Journal output, trades, actual volume, SL/TP, order deletion, and behavior at session boundaries.
6. For reproducibility, keep the source version, preset, broker, full symbol name, timeframe, data range, initial balance, and test report together.

See the official [Strategy Tester documentation](https://www.metatrader5.com/en/terminal/help/algotrading/testing) for test settings and tick data, and the [optimization guide](https://www.metatrader5.com/en/terminal/help/algotrading/strategy_optimization) for optimization settings and saved parameters.

In the baseline source, `OnTester()` returns this score for the **Custom max** criterion:

```text
If Equity Drawdown Percent > 9.5: Score = 0
Otherwise: Score = Profit / Equity Drawdown Percent
If Drawdown <= 0: use 0.0001 as the denominator
```

Win Rate, Recovery Factor, Profit Factor, and Sharpe Ratio are read in the function but are not used in the active score formula. This function ranks optimization runs; it does not enforce a drawdown limit during live trading.

## Known limitations

- **Expiration:** The actual date is hardcoded in `ExpirationTime`. The published source is expired as of the review date.
- **Price units:** The code defines `Pip = point × (digits == 2 ? 10 : 1)`. Do not assume this matches the conventional pip definition for every symbol.
- **Trade isolation:** No dedicated Magic Number is configured. Some checks of `PositionsTotal()` and the latest historical deal operate across the entire account; manual trades or another EA may affect this EA's state.
- **Volume and risk:** Some order paths round volume to two decimal places. Compatibility with Volume Step, account currency, Tick Value, and minimum volume requires symbol-specific verification.
- **Scheduling:** Resets and order deletion depend on ticks arriving with the expected bar time. Late activation, missing ticks, or a different timeframe may change execution paths.
- **Holidays:** `BankHolidays` is a fixed list of dates in 2025, rather than a live broker calendar.
- **Chart objects:** `OnDeinit()` calls `ObjectsDeleteAll(0)`, which can also delete other objects on the same chart.
- **State recovery:** Internal state and tickets are mostly held in memory variables. Full recovery after a restart or reattachment was not verified in this review.

This documentation is based on source and file inspection. Compilation, backtesting, and demo execution were not performed when it was written. This review does not establish profitability or readiness for live trading.

## Development and licensing

When reporting an issue, provide the exact source filename and version, Inputs or the `.set` file, symbol and timeframe, server time, reproduction steps, and relevant Experts/Journal output. Remove sensitive account information from reports.

The source header declares `Copyright 2024, M.H.B`. No `LICENSE` file exists in the current folder. Permission to publish, use, or redistribute cannot be inferred from the project name or access to its source; the copyright holder should select an appropriate license before public release.

**Algorithm developed by M.H.B**
