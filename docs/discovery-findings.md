# Discovery Findings

## High Priority

### Weekly Period Detection

The active code now detects period changes with `PERIOD_W1`.

This affects:

- `detectWeeks()`
- `detectWeekHighLows()`
- `detectCluster()`
- `detectImpulseSignal()`
- `detectImpulseContinuationSignalV1()`
- `DetectClusteredImpulseContinuationSignal()`

This matches the weekly terminology used by the main data structures and helper names.

### EA And Indicator Do Not Show The Same Strategy

The EA uses `DetectClusteredImpulseContinuationSignal()`.

The indicator uses `detectImpulseSignal()`.

This means chart drawings/signals may not represent what the EA actually trades.

### Active Pullback Rule Requires Minimum Pullback

`DetectClusteredImpulseContinuationSignal()` delegates validation to `IsImpulseContinuationLevelQualified()`.

`IsImpulseContinuationLevelQualified()` validates:

```text
actualImpulse >= requiredImpulse
actualPullback >= requiredPullback
```

V1 used:

```text
actualImpulse >= requiredImpulse
actualPullback <= maxPullback
```

This is intentional for the active V2 strategy: the pullback ATR multiplier is a minimum required pullback threshold, not a maximum allowed pullback.

### Active Order Risk Is Percentage Based

The active order path now uses:

```text
Calculate_Lot_Size_V3(g_Risk_Percentage, entryPrice, stopLoss)
```

This means risk is based on current account equity rather than a fixed account-currency amount.

### No Duplicate Order Or Position Guard

When a signal is detected, the EA places a pending order without checking for:

- Existing pending orders from the same signal.
- Existing positions on the symbol.
- Existing EA orders by magic number.
- Existing order comments.
- Whether the same week/period signal was already traded.

This can create repeated exposure if signal conditions are met more than once.

For the current OANDA `OANDA-EURXAU-P2012` personal-account deployment track, this should be treated as a live-readiness blocker or at least a high-priority safety review. Before real capital deployment, decide whether to block duplicate pending orders by symbol/signal, block new orders when there is an existing position, and/or filter all EA-managed orders by magic number.

## Medium Priority

### Lookback Inputs Are Bar Counts, Not Hours

Inputs are named:

- `g_impulse_lookback_hours`
- `g_pullback_lookforward_hours`

They are passed directly to `RatesCircularBuffer(size)`, so they represent number of bars, not number of hours.

On H1 this happens to match hours. On M15, 48 means 12 hours, not 48 hours.

### Signals Can Validate Before ATR Exists

`WeekData.weeklyATR` is initialized to `-1`.

If signal code runs before ATR is calculated, required impulse, required pullback, and cluster size can become negative.

This can make validation pass unexpectedly once pullback fields are available.

### Indicator Processes The Forming Candle

The indicator processes index `0` in `OnCalculate`, which is the current forming candle.

The EA processes `rates[1]`, the latest closed candle.

This can cause repainting and chart/EA disagreement.

### Indicator Full Rebuild Does Not Reset All State

On full recalculation, the indicator resets:

- `g_weekData`
- `g_weekHighs`
- `g_weekLows`

It does not reset:

- `g_clusterHighs`
- `g_clusterLows`
- `g_ImpulseBuffer`
- `g_pullbackBuffer`

This can leave stale cluster and buffer state after history reloads.

### Indicator Deletes All Chart Objects

The indicator uses `ObjectsDeleteAll(0, 0, -1)` during full rebuild.

That can delete unrelated user or indicator objects from the chart.

Object deletion should ideally be scoped to this indicator's prefixes.

### Trade Logger Is Guarded By Input

`TradeLogger.mqh` exists and the EA now controls CSV logging with:

- `g_EnableTradeCsvLogging`

When enabled, the EA deletes and opens the CSV in `OnInit()`, forwards `OnTradeTransaction()` events to the logger helper, and closes the CSV in `OnDeinit()`. When disabled, the EA leaves the CSV logger inactive without requiring code comments to be changed.

## Lower Priority Cleanup

### Old Strategy Functions Remain In EA Utilities

`EA_Utils.mqh` contains older strategy functions that are not called by `PlacePendingOrder()`.

Examples:

- `breakoutStrategy()`
- `reverseOnStopStrategy()`
- `reverseOnStopStrategyV222222233()`

Keeping them may be useful while experimenting, but they add noise and increase maintenance burden.

### Heavy Debug Printing

The active order path prints many symbol properties every time an order is attempted.

This is useful during debugging but may be too noisy for optimization or live testing.

## Environment Note

No MetaEditor compiler executable was found on PATH during discovery, so compile verification was not run from this session.
