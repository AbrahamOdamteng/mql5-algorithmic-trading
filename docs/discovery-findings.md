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
- `detectImpulseContinuationSignalV2()`

This resolves the earlier discovery finding where the code was using `PERIOD_D1` despite weekly naming.

### EA And Indicator Do Not Show The Same Strategy

The EA uses `detectImpulseContinuationSignalV2()`.

The indicator uses `detectImpulseSignal()`.

This means chart drawings/signals may not represent what the EA actually trades.

### Pullback Direction May Be Wrong In V2

`detectImpulseContinuationSignalV2()` delegates validation to `helper()`.

`helper()` validates:

```text
actualImpulse >= requiredImpulse
actualPullback >= allowedPullback
```

V1 used:

```text
actualImpulse >= requiredImpulse
actualPullback <= allowedPullback
```

If `g_pullback_ATR_multiplier` represents a maximum allowed pullback, V2 is likely inverted.

### Active Order Risk Is Hardcoded

The active order path uses:

```text
Calculate_Lot_Size_V2(1000, entryPrice, stopLoss)
```

This means risk is a fixed amount of 1000 account currency units, not an EA input.

### No Duplicate Order Or Position Guard

When a signal is detected, the EA places a pending order without checking for:

- Existing pending orders from the same signal.
- Existing positions on the symbol.
- Existing EA orders by magic number.
- Existing order comments.
- Whether the same week/period signal was already traded.

This can create repeated exposure if signal conditions are met more than once.

## Medium Priority

### Lookback Inputs Are Bar Counts, Not Hours

Inputs are named:

- `g_impulse_lookback_hours`
- `g_pullback_lookforward_hours`

They are passed directly to `RatesCircularBuffer(size)`, so they represent number of bars, not number of hours.

On H1 this happens to match hours. On M15, 48 means 12 hours, not 48 hours.

### Signals Can Validate Before ATR Exists

`WeekData.weeklyATR` is initialized to `-1`.

If signal code runs before ATR is calculated, required impulse, allowed pullback, and cluster size can become negative.

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

### Trade Logger Is Inactive

`TradeLogger.mqh` exists, but the EA comments out:

- CSV delete/open in `OnInit()`.
- CSV close in `OnDeinit()`.
- `OnTradeTransaction()` forwarding to the logger helper.

The logger will not currently record trades.

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
