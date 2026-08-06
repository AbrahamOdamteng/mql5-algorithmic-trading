# Open Questions

These are the decisions that should be clarified before larger refactors or strategy changes.

## Three Day Trend Signal

1. Confirm the visual marker placement should remain above bullish momentum bars and below bearish momentum bars, matching the PineScript's relative locations.
2. Relative volume is currently implemented with tick volume, matching the practical MT5 `volume` equivalent for FX/CFD symbols. Revisit only if a specific symbol has reliable real volume and should differ from the current behavior.
3. Confirm how strictly relative volume should match the PineScript's same-intraday-bar lookback calculation across broker sessions and DST changes.
4. Confirm whether final long/short signals should fire only on the first bar of a new broker day, matching `ta.change(time("D"))`, or on another session boundary.
5. Confirm whether the EA should continue using closed candles only, even if the PineScript indicator plots on the currently forming bar in TradingView.
6. Square-marker order placement, requiring ATR momentum plus relative volume, has been explicitly enabled for genetic testing. Confirm whether final long/short signal order placement should remain disabled until all chart markers visually match the PineScript.

## Legacy WeekHighLow Strategy Definition

1. The active high/low period is now configurable and optimizer-selectable through `g_HighLowPeriodOptimizationIndex`. Supported optimizer values are `0 -> 5` for `H4`, `H6`, `H8`, `H12`, `D1`, and `W1`; `-1` preserves fixed `g_HighLowPeriod` behavior.
2. Open naming question: should weekly-specific names such as `WeekData`, `WeekHighLow`, `detectWeeks()`, and `detectWeekHighLows()` be generalized from `Week*` to `Period*` in a future refactor?

## Legacy WeekHighLow Indicator Alignment

1. Should the indicator mirror the EA's active `DetectClusteredImpulseContinuationSignal()` path?
2. Should the indicator process only closed bars to match EA behavior?
3. Should indicator object deletion be limited to this project's object prefixes?

## Legacy WeekHighLow Pullback Rule

1. The active V2 strategy treats pullback as a minimum required pullback: `actualPullback >= requiredPullback`.
2. V1 used a maximum-pullback interpretation: `actualPullback <= maxPullback`.
3. If V1 is revived, keep its maximum-pullback names separate from V2's minimum-pullback names.

## Legacy WeekHighLow Lookback Units

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
5. Current candidate-promotion workflow: use the Ephemeral Manifold Generator process in `ephemeral-manifold-generator.md`; do not use the older EURUSD-source `S*` -> `S^` cross-symbol promotion workflow unless explicitly revisiting legacy research.
6. What trade-count floor or penalty should be included in fixed IS filters, fixed validation filters, or deterministic scoring before OOS is measured?
7. What initial symbol universe should be used for per-symbol generator runs, given different symbols have different history availability?
8. What per-symbol loss or drawdown cap should be used inside selection and portfolio evaluation?
9. How should `no selection` windows be scored in generator-level statistics?
10. What concentration cap should be used so one symbol cannot dominate aggregate generator profit, trade count, or drawdown?
11. What concentration cap should be used so one monthly selected manifold cannot dominate aggregate generator profit or drawdown?
12. How should deployment-date robustness be measured across monthly rolling starts?
13. For FTMO evaluation, should report-level max drawdown remain only a coarse sanity filter while final ranking comes from rolling challenge simulations?
14. Provisional FTMO grading decision: rank by single-stage pass rate first, then breach behavior, consistency warnings, median pass duration, average pass duration, fee economics, and losing-streak distribution. Minimum viable evaluation pass rate is currently `>= 75%`, with `>= 85%` preferred because challenge and verification pass rates compound. Funded-stage payout should be evaluated as survival/profitability rather than another `+10%` first-passage target.
15. Goal realignment set on `2026-06-14` and refined on `2026-06-21`: evaluation/challenge mode and funded mode may use different strategies. Challenge mode should be treated as account acquisition, targeting `+10%` before breach with pass rate prioritized over raw speed. Funded mode should target lower-risk `1% -> 3%` monthly extraction and account survival.
16. Challenge-mode analysis should report expected challenge-fee cost per pass, losing-streak distribution over `10` attempts, unresolved starts, daily/global breach frequency, and consistency-rule warnings. Current fixed assumptions are `100,000` account size, `GBP 500` challenge fee, refund on first payout, and maximum modeled retries/loss streak of `10`.
17. Funded-mode analysis should report monthly return distribution, payout survival, and breach probability over `3`, `6`, and `12` months instead of using fast `+10%` pass speed.
18. Promising generator-selected portfolios should be stress-tested with cost/spread assumptions, trade-skip or Monte Carlo perturbations, and shifted windows before being treated as robust.
19. OANDA personal-account track decision: `OANDA-EURXAU-P2012` is the current lead same-manifold candidate for `EURUSD + XAUUSD`. Its source optimizer identity is pass `2012`. Remaining work is operational validation rather than broad optimization: tiny live/demo forward test, deployment preset check, lot-step feasibility, news pause policy, and duplicate-order guard review.
20. Planned next generator-selection approach after reviewing the completed EMA forward-validation diagnostic: keep validation, group successful validation candidates by normalized parameter similarity, choose each group's medoid, run fixed non-optimizer perturbation tests on medoids only, and promote robust medoids to OOS.
21. Initial perturbation pass rule to test: at least `70%` of variants profitable, median perturbation profit `> 0`, median perturbation ratio `> 0`, and no catastrophic drawdown variant.
22. Preferred first grouped-perturbation process version: `24m IS / 24m VAL / 3m OOS / 1m step`. Compare later against `24m/12m/3m`, `24m/48m/3m`, `36m/12m/3m`, and `36m/24m/3m`.
23. For MRV EMA and future multi-symbol generator work, should `g_RiskPercentOfBalance` remain part of the optimized manifold, or should selection first identify signal parameters and then run a separate portfolio-level risk/margin feasibility sweep?
24. What portfolio margin model should be used for generator validation: FTMO-style `100x`, OANDA-style `30x`, both as separate deployment profiles, or a stricter stress-test leverage?
25. What shared-margin guardrails should be applied during portfolio replay: maximum used margin, minimum free-margin percentage, per-symbol exposure cap, total exposure cap, per-hour new-trade cap, or symbol-group concentration cap?
26. How repeatable are MT5 genetic optimizer selections for the exact same real-tick window, inputs, and selection rule? If reruns select different manifolds with materially different OOS, should process scoring require repeated optimizer runs, candidate-pool unioning, or region/cluster selection before OOS?

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

## Rolling Manifold Research

1. The active research direction is now the Ephemeral Manifold Generator. The baseline process is per-symbol rolling `36`-month IS, `3`-month validation, monthly step, deterministic selection of exactly one frozen manifold, and one OOS measurement through `90` days; these are generator hyperparameters to test empirically, not settled optimal values. The next planned process after the current EMA diagnostic is grouped validation-survivor perturbation before OOS selection.
2. Which IS durations should be compared first: `2y`, `3y`, `4y`, `5y`, `6y`, or another grid?
3. Which validation durations should be compared first: `3m`, `6m`, `9m`, `12m`, or another grid?
4. What OOS deployment and decay horizons should be compared when measuring manifold lifespan?
5. What rolling step sizes should be compared, such as `1m`, `2m`, or `3m`?
6. How many validation survivors should be retained before final ranking?
7. What exact fixed IS filters should be applied after genetic optimisation?
8. What exact fixed validation filters should be applied before deterministic ranking?
9. What deterministic scoring algorithms should be compared for ranking validation survivors and selecting the single manifold per symbol?
10. How should scoring handle low-trade validation survivors without using OOS information?
11. How should skipped windows be scored when no candidate survives validation?
12. Which initial symbol universe should be used for the first full generator run?
13. Should challenge-mode and funded-mode generator variants use separate filters, scoring, and risk settings?
14. What risk setting or risk sweep should be used when measuring `+5%`, `+10%`, daily breach, and `-10% first` outcomes for each OOS slice?
15. How should portfolio-level FTMO replay combine one selected manifold per symbol while respecting the rule to never deploy multiple manifolds on the same symbol?
16. What guardrails prevent the generator from becoming optimizer noise chasing, especially if the selected manifold changes every month?
