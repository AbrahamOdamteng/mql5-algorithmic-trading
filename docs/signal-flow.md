# Signal Flow

## Current Three Day Trend Signal Flow

The active new EA is `Experts/ThreeDayTrendSignal/ThreeDayTrendSignalEA.mq5`.

Current implemented flow:

1. Create an ATR indicator handle on initialization.
2. Optionally delete prior objects with the `TDTS_Momentum_` prefix.
3. Scan recent historical bars and draw ATR momentum and relative-volume markers.
4. On each new chart bar, evaluate the latest closed bar.
5. Draw a blue circle above the bar for bullish ATR momentum without relative volume.
6. Draw a red circle below the bar for bearish ATR momentum without relative volume.
7. Draw an orange diamond above the bar for relative volume without ATR momentum.
8. Draw an aqua square above the bar for bullish ATR momentum plus relative volume.
9. Draw a purple square below the bar for bearish ATR momentum plus relative volume.
10. If trading is enabled and a new square marker was drawn, place a matching market order.
11. Set stop loss from `ATR * g_StopLossATRMultiple`.
12. Set take profit from stop distance times `g_TakeProfitSLMultiple`.
13. Calculate volume from fixed starting-balance risk using `g_StartingBalance` and `g_RiskPercentOfBalance`.

Current momentum condition:

```text
abs(current close - open from contiguousCandles - 1 bars ago) >= ATR(14) * ATR Multiplier
```

Before drawing a marker, the EA builds the contiguous candle block from newest to oldest and stops before the first adjacent high/low range gap greater than `ATR * GAP_ATR_SKIP_FRACTION`. The fraction is a hardcoded named constant set to `0.1`.

Relative volume condition:

```text
sum(current-bar tick volume / average same-intraday-slot tick volume over relVolLength prior days, relVolCandles bars) >= relVolThreshold
```

Not implemented yet:

- Three-day trend filter.
- Final long/short signal triangles.
- Final-signal order placement.

The older WeekHighLow signal flow below is legacy reference only.

## Legacy WeekHighLow EA Flow

The active EA signal path is clustered impulse continuation.

1. Push the latest closed bar into `g_ImpulseBuffer` and `g_pullbackBuffer`.
2. Call `calculatePullbacks()` to fill pullback values once the relevant bar ages out to the oldest buffer position.
3. Call `detectWeeks()` to either create a new period or update the current period.
4. Call `detectWeekHighLows()` to create high/low levels for the completed period or update active line status.
5. Call `DetectClusteredImpulseContinuationSignal()` separately for highs and lows.
6. If a high signal is detected, take the last high cluster and call `PlacePendingOrder()`.
7. If a low signal is detected, take the last low cluster and call `PlacePendingOrder()`.

## Legacy WeekHighLow Period Detection

The code detects new periods using `IsNewPeriod(..., g_ActiveHighLowPeriod)`.

`g_ActiveHighLowPeriod` is resolved in `OnInit()` from `g_HighLowPeriodOptimizationIndex` and `g_HighLowPeriod`. The default fixed period is `PERIOD_D1`; optimizer index values can select `H4`, `H6`, `H8`, `H12`, `D1`, or `W1`.

Supported optimizer mapping:

| Index | Active period |
| ---: | --- |
| `-1` | Use fixed `g_HighLowPeriod` |
| `0` | `PERIOD_H4` |
| `1` | `PERIOD_H6` |
| `2` | `PERIOD_H8` |
| `3` | `PERIOD_H12` |
| `4` | `PERIOD_D1` |
| `5` | `PERIOD_W1` |

Relevant locations:

- `Include/WeekHighLows/week_functions.mqh`: `detectWeeks()`
- `Include/WeekHighLows/week_functions.mqh`: `detectWeekHighLows()`
- `Include/WeekHighLows/cluster_logic.mqh`: cluster and signal functions

## Legacy WeekHighLow Impulse Logic

The circular buffer calculates impulse from recent bars.

For a high impulse:

- Start at the current bar high.
- Walk backward through stored bars.
- Stop when an older bar already exceeded that high.
- Track the lowest low seen before that break.
- Impulse is current high minus that lowest low.

For a low impulse:

- Start at the current bar low.
- Walk backward through stored bars.
- Stop when an older bar already reached or broke that low.
- Track the highest high seen before that break.
- Impulse is highest high minus current low.

## Legacy WeekHighLow Pullback Logic

Pullbacks are calculated when a prior high or low reaches the oldest position in the pullback buffer.

For a high pullback:

- The oldest bar is assumed to be the period-high candle.
- Walk forward from oldest to newest.
- Stop if the high is breached.
- Track the maximum drop from the high to a later low.

For a low pullback:

- The oldest bar is assumed to be the period-low candle.
- Walk forward from oldest to newest.
- Stop if the low is breached.
- Track the maximum rise from the low to a later high.

## Legacy WeekHighLow Active Clustered Signal Logic

`DetectClusteredImpulseContinuationSignal()` works from the last completed period.

It:

- Gets the matching `WeekData` and `WeekHighLow` entry.
- Computes required impulse, required minimum pullback, and cluster size from ATR multipliers.
- Uses `IsImpulseContinuationLevelQualified()` to validate the seed level's impulse/pullback conditions.
- Builds a `PriceCluster` from the seed level and older nearby levels until a level breaks the cluster.
- Requires `ArraySize(priceCluster) >= g_MinClusterSize` before returning a tradeable signal.
- Draws a signal arrow.
- Appends the cluster to the relevant cluster array.
- Returns `true` to the EA.

Important note: the active path requires a minimum pullback with `actualPullback >= requiredPullback`, while V1 used a maximum pullback rule with `actualPullback <= maxPullback`.

## Legacy WeekHighLow Active Order Logic

`PlacePendingOrder()` delegates to `placeImpulseContinuationOrders()`.

For a high signal:

- Entry is seed price plus cluster height.
- Stop loss is seed price.
- Take profit is based on entry-to-stop distance times `g_TakeProfitMultiplier`.
- A `BuyStop` order is placed.

For a low signal:

- Entry is seed price minus cluster height.
- Stop loss is seed price.
- Take profit is based on entry-to-stop distance times `g_TakeProfitMultiplier`.
- A `SellStop` order is placed.

The active lot sizing call uses `g_Risk_Percentage` via `Calculate_Lot_Size_V3()`.

## Legacy WeekHighLow Indicator Flow Difference

The indicator currently calls `detectImpulseSignal()` rather than the EA's active `DetectClusteredImpulseContinuationSignal()`.

The indicator also processes chart array index `0`, which is the currently forming candle. The EA processes only closed bars.
