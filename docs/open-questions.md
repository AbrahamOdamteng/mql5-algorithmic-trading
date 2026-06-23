# Open Questions

These are the decisions that should be clarified before larger refactors or strategy changes.

## Strategy Definition

1. The active high/low period is now configurable and optimizer-selectable through `g_HighLowPeriodOptimizationIndex`. Supported optimizer values are `0 -> 5` for `H4`, `H6`, `H8`, `H12`, `D1`, and `W1`; `-1` preserves fixed `g_HighLowPeriod` behavior.
2. Open naming question: should weekly-specific names such as `WeekData`, `WeekHighLow`, `detectWeeks()`, and `detectWeekHighLows()` be generalized from `Week*` to `Period*` in a future refactor?

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

1. For the OANDA personal-account `OANDA-EURXAU-P2012` deployment track, practical live risk is currently framed as `0.50% -> 0.75%` per trade on a `10,000` account. `0.75%` is the benchmark-beating target setting; `1.00%` is aggressive and should wait until live/demo execution behavior is confirmed.
2. What default value should `g_Risk_Percentage` use for final live presets: start at `0.50%`, start at `0.75%`, or use a staged ramp from `0.50%` to `0.75%` after forward validation?
3. Should the EA set and filter by magic number?
4. Should the EA block duplicate pending orders for the same symbol/signal?
5. Should the EA ignore signals when there is already an open position or pending order?
6. For OANDA live deployment, should duplicate-order and existing-position guards be treated as mandatory before real capital is used?
7. What news-event pause policy should be used for `EURUSD` and `XAUUSD`: NFP only, NFP/CPI/FOMC, all high-impact USD events, or no automated pause initially?
8. Should the tiny live/demo forward test use `0.50%` risk, lower than `0.50%`, or fixed minimum lot sizing until execution behavior is confirmed?

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
4. For genetic period optimization, should `g_HighLowPeriodOptimizationIndex=4||0||1||5||Y` become the standard preset line for new discovery runs, or should period optimization be enabled only for specific hypotheses?
5. Current candidate-promotion workflow: use the EURUSD genetic backtest to select top `N` candidates, run those candidates across all target symbols in in-sample plus validation, define `S*` as the successful cross-symbol subset, run only `S*` in OOS, and keep `S^`, the subset of `S*` that passes OOS.
6. Current trade-count rule: do not eliminate individual candidates only because they have fewer than `100` trades. Evaluate trade count using the aggregate trade count of `S^`, the final OOS-passing subset.
7. Current phase-1 basket decision: use `EURUSD`, `GBPUSD`, `USDJPY`, `EURJPY`, `XAUUSD`, `XAGUSD`, `US500`, `US30`, `US100`, `UK100`, `USOIL`, and `UKOIL`. Only the FX symbols showed effective full `2000 -> 2012` start coverage in the start-date probe. Treat `US30`, `US500`, `UK100`, `XAUUSD`, `XAGUSD`, `USOIL`, and `UKOIL` as partial-history IS symbols. Treat `US100` as validation/OOS-only from available history and do not use it for optimization.
8. What per-symbol loss or drawdown cap should be used so one symbol cannot dominate portfolio risk?
9. How large must `S^` be before it is considered more than a lucky survivor set: at least `2`, `3`, or more independent candidates?
10. What concentration cap should be used so one symbol cannot dominate `S^` aggregate profit, trade count, or drawdown?
11. What concentration cap should be used so one candidate cannot dominate `S^` aggregate profit, trade count, or drawdown?
12. How should EURUSD-source selection bias be measured after cross-symbol `IS + VAL` and OOS filtering?
13. For FTMO evaluation, should report-level max drawdown remain only a coarse sanity filter while final ranking comes from rolling challenge simulations?
14. Provisional FTMO grading decision: rank by single-stage pass rate first, then breach behavior, consistency warnings, median pass duration, average pass duration, fee economics, and losing-streak distribution. Minimum viable evaluation pass rate is currently `>= 75%`, with `>= 85%` preferred because challenge and verification pass rates compound. Funded-stage payout should be evaluated as survival/profitability rather than another `+10%` first-passage target.
15. Goal realignment set on `2026-06-14` and refined on `2026-06-21`: evaluation/challenge mode and funded mode may use different strategies. Challenge mode should be treated as account acquisition, targeting `+10%` before breach with pass rate prioritized over raw speed. Funded mode should target lower-risk `1% -> 3%` monthly extraction and account survival.
16. Challenge-mode analysis should report expected challenge-fee cost per pass, losing-streak distribution over `10` attempts, unresolved starts, daily/global breach frequency, and consistency-rule warnings. Current fixed assumptions are `100,000` account size, `GBP 500` challenge fee, refund on first payout, and maximum modeled retries/loss streak of `10`.
17. Funded-mode analysis should report monthly return distribution, payout survival, and breach probability over `3`, `6`, and `12` months instead of using fast `+10%` pass speed.
18. Promising `S^` portfolios should be stress-tested with cost/spread assumptions, trade-skip or Monte Carlo perturbations, and shifted windows before being treated as robust.
19. OANDA personal-account track decision: `OANDA-EURXAU-P2012` is the current lead same-manifold candidate for `EURUSD + XAUUSD`. Its source optimizer identity is pass `2012`. Remaining work is operational validation rather than broad optimization: tiny live/demo forward test, deployment preset check, lot-step feasibility, news pause policy, and duplicate-order guard review.

## Behavior Cluster Research

1. Should the next research phase shift from one global manifold to symbol-specific behavior clusters, or run both approaches in parallel?
2. What minimum cluster count should a symbol require for core status: `2`, `3`, or higher?
3. Initial proposed classification: `0` behavior clusters rejects a symbol, `1` cluster makes it a specialist, `2` clusters makes it support/minimum robust, and `3+` clusters makes it core.
4. Initial proposed distinctness thresholds: separate behavior clusters require `OverlapCoverage < 60%` and `JaccardOverlap < 40%`; stricter portfolio independence may require `OverlapCoverage < 40%` and `JaccardOverlap < 25%`.
5. How should matching trades be defined: same symbol and direction with entry time within `3` H1 bars, within `24` hours, or another tolerance?
6. What price tolerance should be used for trade matching: fixed points, ATR fraction such as `0.25 ATR`, R-multiple fraction such as `0.25R`, or no price tolerance initially?
7. Should representatives be selected randomly from each accepted behavior cluster, or should median-quality representatives be used for deterministic reproducibility?
8. How many random portfolio samples are needed before judging a symbol-specific cluster family robust?
9. For the pass-rate-first FTMO objective, should two-stage challenge-plus-verification promotion require a minimum compounded success probability beyond the single-stage `>= 75%` hard gate and `>= 85%` preferred gate?
10. How should evaluation-mode risk differ from funded-mode risk, given the funded-stage target is steady `1% -> 3%` monthly profit rather than another fast `+10%` first-passage target?
