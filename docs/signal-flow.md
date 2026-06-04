# Signal Flow

## Current EA Flow

The active EA signal path is impulse continuation V2.

1. Push the latest closed bar into `g_ImpulseBuffer` and `g_pullbackBuffer`.
2. Call `calculatePullbacks()` to fill pullback values once the relevant bar ages out to the oldest buffer position.
3. Call `detectWeeks()` to either create a new period or update the current period.
4. Call `detectWeekHighLows()` to create high/low levels for the completed period or update active line status.
5. Call `detectImpulseContinuationSignalV2()` separately for highs and lows.
6. If a high signal is detected, take the last high cluster and call `PlacePendingOrder()`.
7. If a low signal is detected, take the last low cluster and call `PlacePendingOrder()`.

## Period Detection

The code currently detects new periods using `IsNewPeriod(..., PERIOD_W1)`.

This means the current implementation is weekly high/low logic.

Relevant locations:

- `Include/WeekHighLows/week_functions.mqh`: `detectWeeks()`
- `Include/WeekHighLows/week_functions.mqh`: `detectWeekHighLows()`
- `Include/WeekHighLows/cluster_logic.mqh`: cluster and signal functions

## Impulse Logic

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

## Pullback Logic

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

## Active V2 Signal Logic

`detectImpulseContinuationSignalV2()` works from the last completed period.

It:

- Gets the matching `WeekData` and `WeekHighLow` entry.
- Computes required impulse, allowed pullback, and cluster size from ATR multipliers.
- Uses `helper()` to validate impulse/pullback conditions.
- Builds a `PriceCluster` from the seed level and older qualifying levels.
- Draws a signal arrow.
- Appends the cluster to the relevant cluster array.
- Returns `true` to the EA.

Important note: V2 currently validates pullback with `actualPullback >= allowedPullback`, while V1 used `actualPullback <= allowedPullback`.

## Active Order Logic

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

## Indicator Flow Difference

The indicator currently calls `detectImpulseSignal()` rather than the EA's active `detectImpulseContinuationSignalV2()`.

The indicator also processes chart array index `0`, which is the currently forming candle. The EA processes only closed bars.
