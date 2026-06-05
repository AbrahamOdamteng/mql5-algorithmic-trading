# Open Questions

These are the decisions that should be clarified before larger refactors or strategy changes.

## Strategy Definition

1. Should the active high/low period remain fixed as `PERIOD_W1`, or should the period be configurable?
2. If made configurable, should names stay weekly-specific or be generalized from `Week*` to `Period*`?

## Indicator Alignment

1. Should the indicator mirror the EA's active `DetectClusteredImpulseContinuationSignal()` path?
2. Should the indicator process only closed bars to match EA behavior?
3. Should indicator object deletion be limited to this project's object prefixes?

## Pullback Rule

1. The active V2 strategy treats pullback as a minimum required pullback: `actualPullback >= requiredPullback`.
2. V1 used a maximum-pullback interpretation: `actualPullback <= maxPullback`.
3. If V1 is revived, keep its maximum-pullback names separate from V2's minimum-pullback names.

## Lookback Units

1. Should impulse and pullback lookbacks be true hours across timeframes?
2. Or should they be explicitly named as bar counts?
3. If true hours are intended, buffer sizes need to account for `_Period` or `PeriodSeconds(_Period)`.

## Risk And Execution

1. What default value should `g_Risk_Percentage` use for future tests and live simulations?
2. Should the EA set and filter by magic number?
3. Should the EA block duplicate pending orders for the same symbol/signal?
4. Should the EA ignore signals when there is already an open position or pending order?

## Logging

1. Should trade CSV logging be re-enabled?
2. Should trade comments include enough information to reconstruct signal parameters?
3. Should logs be split by symbol or kept in one shared file?

## Backtesting And Optimization

1. Are current tester presets targeting the intended strategy version?
2. Should optimizer inputs include ATR period and min cluster size, or are those intentionally fixed?
3. Should M15 tests use adjusted lookback values if inputs remain bar counts?
4. What aggregate trade-count threshold should be required for multi-symbol FTMO-style validation?
5. Which symbol basket should be used to prove that a single manifold is robust across FX, metals, and indices?
6. What per-symbol loss or drawdown cap should be used so one symbol cannot dominate portfolio risk?
