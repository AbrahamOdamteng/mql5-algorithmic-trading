# Architecture

## Current Active EA

`Experts/ThreeDayTrendSignal/ThreeDayTrendSignalEA.mq5` is the active entry point for new strategy work.

It currently implements ATR momentum chart drawing, relative-volume chart drawing, and optional market-order execution:

- Creates an ATR handle with `iATR(_Symbol, _Period, g_ATR_Period)`.
- Draws historical ATR momentum and relative-volume markers during `OnInit()`.
- On each new bar, evaluates the latest closed candle and draws a marker if the momentum or relative-volume condition passes.
- Uses `CTrade` to place buy market orders from new bullish ATR momentum plus relative-volume squares and sell market orders from new bearish ATR momentum plus relative-volume squares when `g_EnableTrading` is true.
- Does not place trades from momentum-only circles or relative-volume-only orange diamonds.
- Sets stop loss from `ATR * g_StopLossATRMultiple` and take profit from stop distance times `g_TakeProfitSLMultiple`.
- Calculates lot size from fixed starting-balance risk: `g_StartingBalance * g_RiskPercentOfBalance / 100.0`, divided by the one-lot loss at the stop price.
- Does not trade historical markers drawn during initialization.

Current implemented momentum condition:

```text
abs(current close - open from contiguousCandles - 1 bars ago) >= ATR(14) * ATR Multiplier
```

When building the contiguous candle block, the EA excludes older candles beyond the first adjacent high/low range gap greater than `ATR * GAP_ATR_SKIP_FRACTION`, with `GAP_ATR_SKIP_FRACTION = 0.1` hardcoded in the EA.

Current implemented relative-volume condition:

```text
sum(current-bar tick volume / average same-intraday-slot tick volume over g_RelVolLength prior days, g_RelVolCandles bars) >= g_RelVolThreshold
```

The genetic optimizer currently enables `g_RelVolLength`, `g_RelVolCandles`, and `g_RelVolThreshold`; fixed validation and OOS tests carry those optimized values forward.

## Experimental EMA-Filtered EA

`Experts/ATRMomentumRelVolEMAFilter/ATRMomentumRelVolEMAFilterEA.mq5` is a separate experimental A/B variant, not a replacement for the active TDTS baseline yet.

It currently:

- Creates ATR, fast EMA, and slow EMA handles on the chart timeframe.
- Draws historical and latest closed-bar ATR momentum and relative-volume markers using object prefix `MRV_EMA_`.
- Draws slow EMA chart segments in blue and fast EMA chart segments in red.
- Preserves the existing marker mapping for momentum circles, relative-volume diamonds, and momentum plus relative-volume squares.
- Counts closed candles since the fast and slow EMAs last crossed or touched using copied EMA buffers, not a persistent global counter.
- Places trades only from newly closed-bar square conditions when `g_EnableTrading` is true and the EMA/price gate passes.
- Determines trade direction from current bid/ask and fast EMA position relative to slow EMA, not from square color.
- Uses the slow EMA value from the closed signal candle as stop loss.
- Skips trades when the slow-EMA stop distance exceeds `ATR * g_MaxStopLossATRMultiple` or broker stop-distance requirements.
- Sets take profit from stop distance times `g_TakeProfitSLMultiple`.
- Calculates lot size from fixed starting-balance risk: `g_StartingBalance * g_RiskPercentOfBalance / 100.0`, divided by one-lot loss at the slow-EMA stop.
- Does not trade historical markers drawn during initialization.

Legacy WeekHighLow architecture is retained below for reference only.

## Legacy WeekHighLow EA

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

## Legacy WeekHighLow Indicator

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

## Legacy WeekHighLow Shared Include Modules

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

## Legacy High/Low Period Selection

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

## Legacy WeekHighLow EA Utilities

`Experts/WeekHighLow/EA_Utils.mqh` contains several strategy/order helper versions, but the active path is:

- `PlacePendingOrder()`
- `placeImpulseContinuationOrders()`

The active order path calculates entry, stop, and take profit around the seed level using `atrVal`, normalizes prices, checks minimum stop distances, calculates volume, and places `BuyStop` or `SellStop` orders.

## Legacy WeekHighLow Trade Logger

`Experts/WeekHighLow/TradeLogger.mqh` can open a common CSV file, write trade events, and flush output.

Current EA code has logger calls commented out:

- `DeleteTradeCsv()`
- `OpenTradeCsv()`
- `CloseTradeCsv()`
- `OnTradeTransaction()` forwarding to `OnTradeTransactionHelper()`
