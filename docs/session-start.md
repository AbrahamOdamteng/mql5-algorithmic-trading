# Session Start Context

Read this file first at the start of a new assistant session.

Do not echo file contents back to the user. After reading the required files, just confirm understanding unless the user asks for a summary.

## Required Reading For Current Work

Read these files first:

- `docs/README.md`
- `docs/three-day-trend-signal.md`
- `docs/ephemeral-manifold-generator.md`
- `docs/open-questions.md`

For FTMO challenge or funded-account analysis, also read:

- `docs/ftmo-challenge-requirements.md`

For legacy rolling-manifold work, also read:

- `docs/behavior-clusters.md`
- `docs/rolling-manifold-experiment-log.md`

For code changes to the EA, indicator, signal logic, or logging, also read the relevant lightweight architecture files:

- `docs/architecture.md`
- `docs/signal-flow.md`
- `docs/discovery-findings.md`

For PowerShell utility work, also read:

- `docs/utils/README.md`

## Large Files To Avoid By Default

Do not read these whole files by default because they are large or historical:

- `docs/experiment-log.md`

Only read `docs/experiment-log.md` if the user asks about legacy experiments, OANDA `OANDA-EURXAU-P2012`, old optimizer results, or historical decisions that are not captured in the current lightweight files. Prefer targeted `grep` searches or line-range reads instead of reading the whole file.

## Experiment Logs By Topic

Use the focused log that matches the task:

- Rolling short-horizon manifolds: `docs/rolling-manifold-experiment-log.md`
- FTMO challenge-stage pass-rate-first research: `docs/ftmo-challenge-experiment-log.md`
- FTMO funded-stage survival and payout research: `docs/ftmo-funded-experiment-log.md`
- Legacy mixed WeekHighLow and OANDA history: `docs/experiment-log.md`

## Current Main Research Direction

The current active strategy implementation is the Three Day Trend Signal strategy from the PineScript indicator in the terminal common files folder.

The current active research direction is the Ephemeral Manifold Generator. The generator/pipeline is the product; selected manifolds are disposable. The baseline process is per-symbol, monthly rolling `36`-month IS plus `3`-month validation, deterministic selection of exactly one frozen manifold per symbol, and a single `3`-month OOS measurement. Alpha-decay slices are disabled for the current run. These are generator hyperparameters to test empirically, not settled optimal values.

The previous day/week high-low strategy and the rolling-manifold branch are legacy research unless the user explicitly asks to revisit them.

Current implementation process:

1. Implement the PineScript strategy in MQL5 incrementally.
2. Draw chart markers first and do not place trades initially.
3. Implement ATR momentum candle markers first.
4. Relative volume markers have been added using tick volume.
5. Trade logic currently executes only when ATR momentum and RelVol occur together, producing square markers.
6. Add the daily trend filter and final signal triangles after visual marker behavior is confirmed.

Current MQL5 state: `Experts/ThreeDayTrendSignal/ThreeDayTrendSignalEA.mq5` implements ATR momentum candle markers, relative volume markers using tick volume, and optional market orders only when ATR momentum and relative volume occur together, producing square markers. Blue/red momentum-only circles and orange RelVol-only diamonds do not trade. Trade sizing uses fixed starting-balance risk via `g_StartingBalance=100000.0` and `g_RiskPercentOfBalance=1.0` by default, not fixed lots. Daily trend filter and final long/short signal triangles are not implemented yet.

Latest compile status: after square-only trade gating was added, MetaEditor compiled `ThreeDayTrendSignalEA.mq5` with `0 errors, 0 warnings`.

Latest EURUSD generator note: first six windows of `tdts_eg_eurusd_2017_is36m_val3m_oos3m_step1m` tested multiple validation selection modes. Current best remains `PositiveLowestTrades`, with `3 / 6` profitable OOS windows, net OOS `+9,214.41`, worst DD `22.65%`, and `465` trades. `PositiveLowestTradesFinalMonth`, requiring positive 3-month validation and positive final validation month, produced `3 / 6`, net OOS `+7,881.33`, worst DD `25.62%`, and `493` trades. `PositiveLowestTradesHardGates` using validation profit `> 0`, PF `>= 1.10`, DD `<= 15%`, and trades `>= 40` produced `2 / 6`, net OOS `+1,223.10`, worst DD `22.65%`, and `474` trades. `PositiveLowestTradesQualityFloor` using validation profit `> 0`, ratio `>= 0.50`, and PF `>= 1.10` produced `2 / 6`, net OOS `-6,558.80`, worst DD `25.62%`, and `491` trades. The shared pattern matters more than the exact ranking: W0001-W0002 are good, W0003 is usually good or near flat, and W0004-W0006 remain weak across modes. Next useful tests should shift from simple candidate-ranking filters to process-level hypotheses such as 1-month OOS deployment, explicit abstention/regime filters, different validation/deployment windows, implementing the daily trend filter/final signal logic, or checking another symbol.

Latest MRV EMA variant note: `Experts/ATRMomentumRelVolEMAFilter/ATRMomentumRelVolEMAFilterEA.mq5` was created as an experimental A/B EA with fast/slow EMA chart lines and EMA-gated square-marker trades. It compiled cleanly and visually looked correct, but the 3-window EURUSD 2025 throwaway-manifold diagnostic `mrv_ema_eg_eurusd_2025_is36m_val3m_oos3m_step1m` should be treated as a failed diagnostic, not a promotable strategy. The completed `24m IS / 48m VAL / 1m OOS` diagnostic `mrv_ema_eg_eurusd_2025_is24m_val48m_oos1m_step1m` also failed promotion; a key flaw was that validation only tested the top `25` IS candidates, and W0001's selected OOS candidate had roughly `63%` validation DD. The completed non-perturbation MT5-forward-validation process `mrv_ema_fwd_eurusd_2025_is24m_val24m_oos1m_step1m` used optimizer `ForwardMode=1` so IS and VAL were produced together before OOS selection. Its original `PositiveBestRatio` selection produced net OOS `+7,344.13`, `2 / 4` profitable windows, `1 / 4` zero-trade window, `22` OOS trades, and worst OOS DD `2.74%`. On `2026-08-03`, score-gated reselection modes were added using MT5 forward spreadsheet `Back Result` and `Forward Result` columns. Tested EURUSD four-window score-gated modes showed the current lead is `BackScore >= 90`, `ForwardScore >= 90`, then highest validation trades, with net OOS `+6,134.56`, `2 / 4` profitable windows, `1 / 4` zero-trade window, `13` OOS trades, and worst OOS DD `1.81%`. Highest validation profit was close at net `+5,184.96`; highest validation DD produced net `+5,601.09`; lowest validation DD produced net `+1,207.59`; lowest validation trades produced net `+1,399.06`; highest validation PF failed at net `-493.73`. Treat all of these as tiny-sample diagnostics, not promotions. The runner was then prepared for an overnight extension adding W0005 and W0006 with the same `24m IS / 24m VAL / 1m OOS` process, using `BackForwardScoreThenHighestTrades`, `MinBackScore=90`, `MinForwardScore=90`, `StartAtWindow=5`, `MaxWindows=2`, and `LastOosStart=2025-06-01`. Command to run/resume: `powershell -ExecutionPolicy Bypass -File .\Files\ATRMomentumRelVolEMAFilter\Run-MRV-EURUSD-ForwardValidationGenerator.ps1`. Grouped validation-survivor perturbation remains planned for later, after forward-validation selection and trade-frequency handling are reviewed.

Important testing note: the `2026-07-18` EURUSD H1 genetic results in `docs/experiment-log.md` used the older fixed `0.10` lot sizing and predate RelVol plus square-only trade gating. Treat those rankings as superseded historical evidence.

MRV EMA follow-up: the overnight extension for `mrv_ema_fwd_eurusd_2025_is24m_val24m_oos1m_step1m` completed W0005 and W0006 using `BackScore >= 90`, `ForwardScore >= 90`, then highest validation trades. W0005 had no selection because `207` candidates passed normal IS/VAL gates, `99` had `BackScore >= 90`, `6` had `ForwardScore >= 90`, and `0` had both score gates. W0006 selected `MRV_EMA_Pass2975` and produced OOS `+1,518.76`, DD `1.25%`, and `3` trades. Clean six-window aggregate for the `90/90` highest-validation-trades rule is net OOS `+7,653.32`, selected windows `5 / 6`, profitable selected windows `3`, losing selected windows `1`, zero-trade selected windows `1`, no-selection windows `1`, `16` OOS trades, and worst OOS DD `1.81%`. The current `selection_summary.csv` can be mixed if W0001-W0004 were overwritten by later reselection tests; use the clean recorded table in `docs/rolling-manifold-experiment-log.md` for the six-window view.

MRV EMA OHLC speed diagnostic: `mrv_ema_fwd_eurusd_2025_is24m_val24m_oos1m_step1m_optm1ohlc` used MT5 `Model=1` (`1 minute OHLC`) for optimizer+forward runs and kept fixed OOS tests on real ticks. It completed `17` EURUSD windows from OOS starts `2025.01.01 -> 2026.05.01`, averaging `28.98` minutes per optimizer+forward window, but failed as a drop-in acceleration method: selected windows `13 / 17`, no-selection windows `4`, profitable selected OOS windows `2 / 13`, net OOS `-4,482.18`, `62` trades, and worst OOS DD `3.99%`. The selected candidates differed from the real-tick run, for example W0001 selected `MRV_EMA_Pass5157` and lost `-950.69` versus real-tick W0001 `MRV_EMA_Pass3285` at `+5,218.80`. Treat this as evidence that tester model changes can change selected manifolds. Next useful diagnostic is real-tick optimizer repeatability: rerun the exact same window under separate experiment IDs and compare selected candidates and OOS distributions.

XAUUSD MRV EMA follow-up: the strict forward-validation process was partially tested on `XAUUSD`. W0001 selected `MRV_EMA_Pass8410` but produced `0` OOS trades, and W0002 had no selection after the first two optimizer+forward windows took about `21.5` hours total. Do not extend XAUUSD blindly before resolving runtime, selection stability, and portfolio-complementarity questions.

Latest rolling-manifold testing note: `tdts_rm_2018_5y_1y_1y` belongs to the older EURUSD-discovery plus cross-symbol-promotion framing. Keep it as historical evidence only. Future rolling research should use the per-symbol ephemeral-generator process in `docs/ephemeral-manifold-generator.md` unless the user explicitly asks to revisit the older branch.
