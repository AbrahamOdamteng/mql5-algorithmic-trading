# Architecture

## EA

`Experts/WeekHighLow/WeekHighLowEA.mq5` is the trading entry point.

It includes:

- `<Trade/Trade.mqh>` for `CTrade`.
- `<WeekHighLows/datatypes.mqh>` for `WeekData`, `WeekHighLow`, and `PriceCluster`.
- `<WeekHighLows/cluster_logic.mqh>` for signal detection.
- `<WeekHighLows/week_functions.mqh>` for period detection, high/low creation, ATR, impulse, and pullback updates.
- `EA_Utils.mqh` for pending order placement and lot sizing.
- `TradeLogger.mqh` for trade event logging, though it is currently not activated by the EA.

On initialization, the EA:

- Resolves the active high/low period from `g_HighLowPeriodOptimizationIndex` and `g_HighLowPeriod`.
- Allocates impulse and pullback circular buffers.
- Loads up to 70,000 historical bars with `CopyRates`.
- Processes historical closed bars from oldest to newest.
- Builds `g_weekData`, `g_weekHighs`, `g_weekLows`, `g_clusterHighs`, and `g_clusterLows`.
- Sets `lastProcessedBarTime` to avoid processing the same bar repeatedly.

On each tick, the EA:

- Returns immediately unless a new bar has opened.
- Loads the latest three bars.
- Processes `rates[1]` as the latest closed bar and `rates[2]` as the previous closed bar.
- Updates buffers and shared strategy state.
- Calls `DetectClusteredImpulseContinuationSignal()` for highs and lows.
- Places a pending order when a signal is detected.

## Indicator

`Indicators/WeekHighLow/WeekHighLowIndicator.mq5` is the chart visualization entry point.

It includes the same shared WeekHighLows modules, plus direct inclusion of `rates_circular_buffer.mqh`.

On initialization, the indicator:

- Resolves the active high/low period from `g_HighLowPeriodOptimizationIndex` and `g_HighLowPeriod`.
- Allocates impulse and pullback buffers.
- Does not pre-load history itself; it works from `OnCalculate` arrays.

On calculation, the indicator:

- Sets chart arrays as series.
- Performs a full rebuild when `prev_calculated == 0` or when more history has loaded.
- Deletes chart objects during full rebuild.
- Processes bars in reverse index order.
- Updates period/high/low state.
- Calls `detectImpulseSignal()` rather than the EA's active `DetectClusteredImpulseContinuationSignal()`.

## Shared Include Modules

`Include/WeekHighLows/datatypes.mqh` defines core structs:

- `WeekData`: period state, high/low values, ATR, impulse, pullback, and calculation timestamps.
- `WeekHighLow`: a high or low level derived from a completed period.
- `PriceCluster`: a detected cluster/signal containing a seed level and related levels.

`Include/WeekHighLows/week_functions.mqh` handles:

- Mapping the optimizer-safe high/low period index to the active `ENUM_TIMEFRAMES` value.
- Creating new period data.
- Detecting a new period.
- Updating current period high/low/close.
- Calculating ATR across completed periods.
- Creating high/low level objects from the finished period.
- Calculating delayed pullback values using a circular buffer.

`Include/WeekHighLows/cluster_logic.mqh` handles:

- Cluster distance tests.
- Older cluster detection variants.
- Impulse-only detection.
- Impulse-continuation detection and the active clustered continuation trigger.

`Include/WeekHighLows/rates_circular_buffer.mqh` stores recent `MqlRates` bars and calculates:

- High impulse.
- Low impulse.
- High pullback.
- Low pullback.

`Include/WeekHighLows/drawing_functions.mqh` handles chart objects:

- Vertical period boundary lines.
- High/low trend lines.
- Signal arrows.
- Deactivation of level rays after price hits them.

`Include/WeekHighLows/utils.mqh` provides append helpers and simple array access helpers.

## High/Low Period Selection

The EA and indicator keep `g_HighLowPeriod` as the fixed-period input. They also expose `g_HighLowPeriodOptimizationIndex` so MT5 genetic optimization can sweep a contiguous integer range instead of raw `ENUM_TIMEFRAMES` values.

Mapping:

| Index | Active period |
| ---: | --- |
| `-1` | Use fixed `g_HighLowPeriod` |
| `0` | `PERIOD_H4` |
| `1` | `PERIOD_H6` |
| `2` | `PERIOD_H8` |
| `3` | `PERIOD_H12` |
| `4` | `PERIOD_D1` |
| `5` | `PERIOD_W1` |

For genetic optimization over the supported periods, use `g_HighLowPeriodOptimizationIndex=4||0||1||5||Y`. For fixed legacy presets, leave it disabled at `-1`.

## EA Utilities

`Experts/WeekHighLow/EA_Utils.mqh` contains several strategy/order helper versions, but the active path is:

- `PlacePendingOrder()`
- `placeImpulseContinuationOrders()`

The active order path calculates entry, stop, and take profit around the seed level using `atrVal`, normalizes prices, checks minimum stop distances, calculates volume, and places `BuyStop` or `SellStop` orders.

## Trade Logger

`Experts/WeekHighLow/TradeLogger.mqh` can open a common CSV file, write trade events, and flush output.

Current EA code has logger calls commented out:

- `DeleteTradeCsv()`
- `OpenTradeCsv()`
- `CloseTradeCsv()`
- `OnTradeTransaction()` forwarding to `OnTradeTransactionHelper()`
