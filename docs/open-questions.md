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
4. Planned next change: add manifold/test identity to CSV logging so each fixed manifold can be analyzed independently for FTMO first-passage behavior.
5. Planned CSV identity inputs: `g_TradeCsvManifoldId` and `g_TradeCsvTestId`.
6. Planned CSV file behavior: write one appendable CSV per manifold, with rows sorted by `deal_time` during analysis so MT5 execution order does not matter.
7. Planned duplicate handling: FTMO analysis should dedupe rows by a stable composite key such as `manifold_id + test_id + symbol + ticket + trade_id + entry_type + deal_time`.

## Backtesting And Optimization

1. Are current tester presets targeting the intended strategy version?
2. Should optimizer inputs include ATR period and min cluster size, or are those intentionally fixed?
3. Should M15 tests use adjusted lookback values if inputs remain bar counts?
4. Current candidate-promotion workflow: use the EURUSD genetic backtest to select top `N` candidates, run those candidates across all target symbols in in-sample plus validation, define `S*` as the successful cross-symbol subset, run only `S*` in OOS, and keep `S^`, the subset of `S*` that passes OOS.
5. Current trade-count rule: do not eliminate individual candidates only because they have fewer than `100` trades. Evaluate trade count using the aggregate trade count of `S^`, the final OOS-passing subset.
6. Current phase-1 basket decision: use `EURUSD`, `GBPUSD`, `USDJPY`, `EURJPY`, `XAUUSD`, `XAGUSD`, `US500`, `US30`, `US100`, `UK100`, `USOIL`, and `UKOIL`. Only the FX symbols showed effective full `2000 -> 2012` start coverage in the start-date probe. Treat `US30`, `US500`, `UK100`, `XAUUSD`, `XAGUSD`, `USOIL`, and `UKOIL` as partial-history IS symbols. Treat `US100` as validation/OOS-only from available history and do not use it for optimization.
7. What per-symbol loss or drawdown cap should be used so one symbol cannot dominate portfolio risk?
8. How large must `S^` be before it is considered more than a lucky survivor set: at least `2`, `3`, or more independent candidates?
9. What concentration cap should be used so one symbol cannot dominate `S^` aggregate profit, trade count, or drawdown?
10. What concentration cap should be used so one candidate cannot dominate `S^` aggregate profit, trade count, or drawdown?
11. How should EURUSD-source selection bias be measured after cross-symbol `IS + VAL` and OOS filtering?
12. For FTMO evaluation, should report-level max drawdown remain only a coarse sanity filter while final ranking comes from rolling challenge simulations?
13. Provisional FTMO grading decision: rank by pass rate first, median pass duration second, and average pass duration third. Minimum viable evaluation pass rate is currently `>= 80%`, with `>= 85%` preferred because challenge and verification pass rates compound. Funded-stage payout should be evaluated as survival/profitability rather than another `+10%` first-passage target.
14. Goal realignment set on `2026-06-14`: evaluation/challenge mode and funded mode may use different strategies. Challenge mode should be treated as account acquisition, targeting `+10%` before breach, preferably in `20 -> 30` trading days and with `40` trading days as the current upper acceptable limit. Funded mode should target lower-risk `1% -> 3%` monthly extraction and account survival.
15. Challenge-mode analysis should report expected challenge-fee cost per funded account and losing-streak distribution, because a high challenge-failure rate may be acceptable if the funded-mode economics remain positive.
16. Funded-mode analysis should report monthly return distribution, payout survival, and breach probability over `3`, `6`, and `12` months instead of using fast `+10%` pass speed.
17. Promising `S^` portfolios should be stress-tested with cost/spread assumptions, trade-skip or Monte Carlo perturbations, and shifted windows before being treated as robust.

## Behavior Cluster Research

1. Should the next research phase shift from one global manifold to symbol-specific behavior clusters, or run both approaches in parallel?
2. What minimum cluster count should a symbol require for core status: `2`, `3`, or higher?
3. Initial proposed classification: `0` behavior clusters rejects a symbol, `1` cluster makes it a specialist, `2` clusters makes it support/minimum robust, and `3+` clusters makes it core.
4. Initial proposed distinctness thresholds: separate behavior clusters require `OverlapCoverage < 60%` and `JaccardOverlap < 40%`; stricter portfolio independence may require `OverlapCoverage < 40%` and `JaccardOverlap < 25%`.
5. How should matching trades be defined: same symbol and direction with entry time within `3` H1 bars, within `24` hours, or another tolerance?
6. What price tolerance should be used for trade matching: fixed points, ATR fraction such as `0.25 ATR`, R-multiple fraction such as `0.25R`, or no price tolerance initially?
7. Should representatives be selected randomly from each accepted behavior cluster, or should median-quality representatives be used for deterministic reproducibility?
8. How many random portfolio samples are needed before judging a symbol-specific cluster family robust?
9. For the under-`90`-day FTMO objective, what is the minimum acceptable probability of completing challenge `+10%` plus verification `+5%` before daily/global breach?
10. How should evaluation-mode risk differ from funded-mode risk, given the funded-stage target is steady `1% -> 3%` monthly profit rather than another fast `+10%` first-passage target?
