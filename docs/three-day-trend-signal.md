# Three Day Trend Signal Strategy

This is the current active strategy direction as of `2026-07-15`.

The previous day/week high-low strategy is abandoned for new development unless the user explicitly asks for legacy work. Keep the old WeekHighLow files and historical docs as reference, but do not extend that strategy by default.

## Source Strategy

The strategy was first coded as a TradingView PineScript indicator:

```text
C:\Users\abraham\AppData\Roaming\MetaQuotes\Terminal\Common\Files\3 Day Trend Signal with ATR Candle Filter.txt
```

The MQL5 implementation should be built incrementally and verified feature by feature.

## Intended PineScript Logic

The source indicator has three main components:

1. ATR momentum candle marker.
2. Relative volume confirmation marker.
3. Daily trend filter and final long/short signal marker.

The initial MQL5 work drew chart markers only. Market orders are now explicitly enabled for genetic testing only when ATR momentum and relative volume occur together, producing square markers; final-signal trade logic should still wait for explicit approval.

## Research Context

The current research direction is the Ephemeral Manifold Generator, not a forever-manifold search. Three Day Trend Signal is the current EA implementation being used as the strategy substrate, while the research product is the repeatable per-symbol optimize, validate, select, freeze, and OOS-decay pipeline described in `ephemeral-manifold-generator.md`.

## Current MQL5 Implementation

Current EA:

```text
Experts/ThreeDayTrendSignal/ThreeDayTrendSignalEA.mq5
```

Implemented so far:

- ATR momentum candle feature.
- Relative volume feature using tick volume.
- Blue circle marker for bullish momentum without relative volume.
- Red circle marker for bearish momentum without relative volume.
- Orange diamond marker for relative volume without ATR momentum.
- Aqua square marker for bullish ATR momentum plus relative volume.
- Purple square marker for bearish ATR momentum plus relative volume.
- Optional market order execution for newly drawn ATR momentum plus relative-volume square markers.
- No three-day trend filter.
- No final long/short triangle signals.

Current momentum formula:

```text
abs(current close - open from contiguousCandles - 1 bars ago) >= ATR(14) * ATR Multiplier
```

When building the contiguous candle block, the EA checks the high/low range gap between each adjacent pair. If a non-overlapping range gap is greater than `ATR * GAP_ATR_SKIP_FRACTION`, older candles beyond that gap are excluded from the momentum calculation. `GAP_ATR_SKIP_FRACTION` is hardcoded to `0.1`.

Default momentum inputs mirror the PineScript momentum defaults:

```text
g_ATR_Period = 14
g_ATR_Multiplier = 5.0
g_ContiguousCandles = 2
```

Current relative-volume inputs:

```text
g_RelVolLength = 20
g_RelVolCandles = 1
g_RelVolThreshold = 1.5
```

Relative volume uses MT5 tick volume and compares each bar against the same intraday slot over prior days. The genetic optimizer currently searches RelVol ranges from `Profiles/Tester/ThreeDayTrendSignal_EURUSD_Genetic_20260718.set`.

The EA processes closed candles. On initialization it draws recent historical momentum markers, then on each new bar it evaluates the latest closed bar.

Trade execution for genetic testing:

- `g_EnableTrading` controls whether newly drawn ATR momentum plus relative-volume square markers place market orders.
- Blue momentum circles do not place trades.
- Red momentum circles do not place trades.
- Aqua bullish momentum plus relative-volume squares place buy market orders.
- Purple bearish momentum plus relative-volume squares place sell market orders.
- Orange relative-volume-only diamonds do not place trades.
- Position size is calculated from `g_StartingBalance * g_RiskPercentOfBalance / 100.0` and the actual stop-loss distance.
- Default risk model is `1.0%` of a fixed `100000.0` starting balance, so the risk amount is `1000.0` account currency per trade unless inputs are changed.
- `g_StopLossATRMultiple` sets stop-loss distance as a multiple of ATR.
- `g_TakeProfitSLMultiple` sets take-profit distance as a multiple of the stop-loss distance.
- Historical markers drawn during `OnInit()` do not place trades.

## Experimental EMA-Filtered Variant

A separate revised EA has been created for A/B testing without changing the current TDTS baseline:

```text
Experts/ATRMomentumRelVolEMAFilter/ATRMomentumRelVolEMAFilterEA.mq5
```

Current status:

- Compiled with MetaEditor64 on `2026-07-31` with `0 errors, 0 warnings`.
- Uses object prefix `MRV_EMA_` and magic number default `3001002`.
- Preserves the existing momentum-only circles, relative-volume-only diamonds, and momentum plus relative-volume squares.
- Draws the slow EMA as a blue chart line.
- Draws the fast EMA as a red chart line.
- Trades only newly closed-bar square conditions when the EMA/price gate passes.
- Square color does not determine trade direction.
- Long direction requires current ask and fast EMA above the slow EMA.
- Short direction requires current bid and fast EMA below the slow EMA.
- EMA separation must be at least `g_MinEMASeparationCandles`, counted on closed candles and including the signal candle.
- Stop loss is the slow EMA value from the closed signal candle.
- Take profit is `g_TakeProfitSLMultiple` times the slow-EMA stop distance.
- Trades are skipped when slow-EMA stop distance exceeds `ATR * g_MaxStopLossATRMultiple`.
- Risk sizing still uses fixed starting balance via `g_StartingBalance * g_RiskPercentOfBalance / 100.0`.
- Historical markers and EMA visuals drawn during `OnInit()` do not place trades.

Prepared preset:

```text
Profiles/Tester/ATRMomentumRelVolEMAFilter_WalkForward_Current.set
```

Prepared tester config:

```text
Files/ATRMomentumRelVolEMAFilter/MRV_EMA_EURUSD_Genetic_20260731.ini
```

Prepared throwaway-manifold runner:

```text
Files/ATRMomentumRelVolEMAFilter/Run-MRV-EURUSD-EphemeralGenerator.ps1
```

The preset enables optimization for the revised strategy inputs and leaves operational inputs fixed. The existing TDTS EA, presets, and generator runner remain unchanged.

The original prepared EMA diagnostic used the throwaway-manifold process:

- Optimize for `36` months.
- Validate for `3` months.
- Run OOS for `3` months.
- Move the entire window forward by `1` month and repeat.
- Treat selected EMA-filtered manifolds as disposable outputs of the generator, not permanent parameter sets.

The completed EMA diagnostic `mrv_ema_eg_eurusd_2025_is24m_val48m_oos1m_step1m` used `24` months IS, `48` months validation, `1` month OOS, and `1` month rolling step. It failed promotion; validation was limited to the top `25` IS candidates, and W0001 selected a candidate with roughly `63%` validation DD.

The completed non-perturbation EMA forward-validation diagnostic was run with:

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\ATRMomentumRelVolEMAFilter\Run-MRV-EURUSD-ForwardValidationGenerator.ps1
```

This used MT5 optimizer `ForwardMode=1` for `24` months IS plus `24` months validation, then selected from validation-gated forward candidates and ran `1` month OOS. It did not run grouped perturbation.

Result for `mrv_ema_fwd_eurusd_2025_is24m_val24m_oos1m_step1m`:

- Net OOS: `+7,344.13`.
- Profitable windows: `2 / 4`.
- Zero-trade windows: `1 / 4`.
- OOS trades: `22`.
- Worst OOS DD: `2.74%`.
- Selected validation DDs: `10.36%`, `8.35%`, `9.86%`, and `2.90%`.

Interpretation: the MT5-forward-validation process fixed the prior high-validation-DD selection flaw, but this is not promotable yet because the sample is tiny, W0004 produced no OOS trades, and `g_RiskPercentOfBalance` was still optimized.

Score-gated reselection diagnostics were added on `2026-08-03` for the same four completed EURUSD windows. The runner now reads MT5 forward spreadsheet `Back Result` and `Forward Result` columns, exposes `-MinBackScore` and `-MinForwardScore`, and can rank candidates after score gates by validation DD, profit, trades, or profit factor. When saying "highest profit" in this runner, the current implementation means highest forward/validation profit; back/IS profit is not part of that ranking except through the score gate.

Tested reselection results for `BackScore >= 90` and `ForwardScore >= 90`:

| Mode | Net OOS | Profitable windows | Zero-trade windows | OOS trades | Worst OOS DD |
| --- | ---: | ---: | ---: | ---: | ---: |
| Highest validation trades | `+6,134.56` | `2 / 4` | `1 / 4` | `13` | `1.81%` |
| Highest validation DD | `+5,601.09` | `2 / 4` | `1 / 4` | `10` | `1.81%` |
| Highest validation profit | `+5,184.96` | `2 / 4` | `1 / 4` | `8` | `1.39%` |
| Lowest validation trades | `+1,399.06` | `2 / 4` | `1 / 4` | `14` | `2.21%` |
| Lowest validation DD | `+1,207.59` | `2 / 4` | `1 / 4` | `13` | `0.71%` |
| Highest validation PF | `-493.73` | `1 / 4` | `1 / 4` | `12` | `3.07%` |

Additional tested modes: `BackScore >= 80`, `ForwardScore >= 80`, then lowest validation DD selected the same candidates as the `90/90` lowest-DD mode. `80/80` highest validation profit produced net OOS `+3,915.11`, `2 / 4` profitable windows, `0 / 4` zero-trade windows, `9` trades, and worst OOS DD `1.39%`.

Current interpretation: on this tiny EURUSD-only diagnostic, `90/90` highest validation trades is the current lead among tested score-gated selection modes. Do not promote it yet; the result needs multi-symbol testing, fixed-risk review because `g_RiskPercentOfBalance` remains optimized, and broader rolling windows.

Risk-percent optimization note: `g_RiskPercentOfBalance` is intentionally optimizer-enabled in the MRV EMA diagnostics. The reason is not just to maximize profit. Some manifolds can fire back-to-back trades, and in a multi-symbol deployment several symbols may initiate trades in the same hour. A single-symbol MT5 tester gives that symbol access to the full account margin, but a real portfolio shares finite margin across all symbols. FTMO-style accounts may have about `100x` leverage, while OANDA personal accounts may have about `30x`, so portfolio margin capacity can be materially tighter than any one-symbol test implies. Treat selected risk percent as a margin/capacity-sizing part of the candidate, and validate promising multi-symbol portfolios later with explicit leverage, margin, exposure, and free-margin rules.

Follow-up W0005-W0006 overnight extension using the same `90/90` highest-validation-trades rule:

| Window | OOS period | Status | Pass | Back score | Forward score | Validation trades | OOS profit | OOS DD | OOS trades |
| --- | --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| W0001 | `2025.01.01 -> 2025.02.01` | Selected | `3285` | `98.61` | `94.03` | `190` | `+5,218.80` | `1.81%` | `6` |
| W0002 | `2025.02.01 -> 2025.03.01` | Selected | `9045` | `99.98` | `97.02` | `153` | `-402.31` | `0.55%` | `4` |
| W0003 | `2025.03.01 -> 2025.04.01` | Selected | `2532` | `92.59` | `93.00` | `55` | `+1,318.07` | `0.60%` | `3` |
| W0004 | `2025.04.01 -> 2025.05.01` | Selected | `3569` | `98.20` | `91.33` | `270` | `0.00` | `0.00%` | `0` |
| W0005 | `2025.05.01 -> 2025.06.01` | No selection | - | - | - | - | - | - | - |
| W0006 | `2025.06.01 -> 2025.07.01` | Selected | `2975` | `99.48` | `98.55` | `93` | `+1,518.76` | `1.25%` | `3` |

Six-window aggregate for this rule: net OOS `+7,653.32`, selected windows `5 / 6`, `3` profitable selected windows, `1` losing selected window, `1` zero-trade selected window, `1` no-selection window, `16` OOS trades, and worst OOS DD `1.81%`. W0005 abstained because `207` candidates passed normal IS/VAL gates, but `0` passed both `BackScore >= 90` and `ForwardScore >= 90`.

Speed diagnostic using `1 minute OHLC` optimizer model:

- Process ID: `mrv_ema_fwd_eurusd_2025_is24m_val24m_oos1m_step1m_optm1ohlc`.
- Optimizer+forward used MT5 `Model=1`; fixed OOS tests still used real ticks (`Model=4`).
- Reports were written to the separate `_optm1ohlc` folder, so the original real-tick EURUSD forward-validation reports were not overwritten.
- Completed `17` windows from OOS starts `2025.01.01 -> 2026.05.01`.
- Runtime averaged `28.98` minutes per optimizer+forward window.
- Aggregate OOS: selected windows `13 / 17`, no-selection windows `4`, profitable selected windows `2 / 13`, zero-trade selected windows `2`, net OOS `-4,482.18`, `62` trades, and worst OOS DD `3.99%`.
- The selected candidates differed materially from the earlier real-tick process. W0001 selected `MRV_EMA_Pass5157` and produced OOS `-950.69`, while the clean real-tick run selected `MRV_EMA_Pass3285` and produced OOS `+5,218.80`.
- Interpretation: `Model=1` is fast but is not a safe drop-in replacement for real-tick optimization in this process. It changes the candidate landscape and selected manifolds. Treat the result as a failed speed diagnostic.
- Follow-up risk: even with real ticks, MT5 genetic optimizer repeatability still needs testing. If identical real-tick reruns select different candidates with materially different OOS, generator results should be judged as a distribution across optimizer runs, not from one run.

After forward-validation selection and trade-frequency handling are reviewed, the planned next process is grouped validation-survivor perturbation before OOS selection:

- Run IS optimization and validation normally.
- Keep successful validation candidates.
- Group validation survivors by normalized parameter similarity.
- Select each group's medoid as the real candidate nearest the middle of that group.
- Perturb only group medoids using fixed single backtests with `Optimization=0`, not MT5 genetic optimization.
- Require local perturbation robustness before selecting a medoid for OOS.
- Use OOS only as measurement after the selection process is fixed.

Preferred first grouped-perturbation process version:

- IS: `24` months.
- Validation: `24` months.
- OOS measurement: `3` months.
- Rolling step: `1` month.

Prepared grouped-perturbation runner:

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\ATRMomentumRelVolEMAFilter\Run-MRV-EURUSD-ForwardPerturbationGenerator.ps1
```

This runner uses MT5 built-in forward testing for validation and fixed `Optimization=0` tests for perturbation and OOS.

Prepared 2025 three-iteration command:

```powershell
powershell -ExecutionPolicy Bypass -File .\Files\ATRMomentumRelVolEMAFilter\Run-MRV-EURUSD-EphemeralGenerator.ps1 `
  -FirstOosStart 2025-01-01 `
  -LastOosStart 2025-03-01 `
  -ISMonths 36 `
  -ValidationMonths 3 `
  -OosMonths 3 `
  -PrimaryOosMonths 3 `
  -StepMonths 1 `
  -MaxWindows 3 `
  -ValidationSelectionMode PositiveLowestTrades
```

This produces OOS starts `2025.01.01`, `2025.02.01`, and `2025.03.01`. With `-OosMonths 3`, the first OOS window ends at `2025.04.01`; an end date of `2025.03.01` would be a `2`-month OOS slice and should only be used if the process is intentionally changed.

## Marker Mapping

Implemented now:

- Bullish ATR momentum without relative volume: blue circle above the bar.
- Bearish ATR momentum without relative volume: red circle below the bar.
- Relative volume threshold without ATR momentum: orange diamond above the bar.
- Bullish ATR momentum plus relative volume: aqua square above the bar.
- Bearish ATR momentum plus relative volume: purple square below the bar.

Planned later:

- Final long signal: large blue triangle up.
- Final short signal: large red triangle down.

## Implementation Sequence

Use this order unless the user changes direction:

1. Momentum candle markers.
2. Relative volume markers. Done using tick volume.
3. Daily trend filter.
4. Final long/short signal markers.
5. Backtest analysis and trade logging support if needed.
6. Order placement for final signals only after explicit user approval. Momentum plus relative-volume square market orders are currently implemented for genetic testing.

## Verification Notes

The first EA version compiled through MetaEditor with:

```text
0 errors, 0 warnings
```

Latest compile status after square-only trade gating was added: `0 errors, 0 warnings`.

Future changes should continue compiling cleanly before being considered complete.

## Prepared Tester Setups

- `Files/ThreeDayTrendSignal/TDTS_EURUSD_Genetic_20260718.ini`: prepared EURUSD H1 genetic optimization config for `2000.01.01 -> 2018.01.01` with forward mode enabled. Do not run automatically from assistant sessions unless explicitly requested.
- `Profiles/Tester/ThreeDayTrendSignal_EURUSD_Genetic_20260718.set`: matching optimizer input preset for ATR period, ATR momentum multiplier, contiguous candle count, relative-volume length/candles/threshold, stop-loss ATR multiple, and take-profit SL multiple. Current lot sizing uses fixed starting-balance risk with `g_StartingBalance=100000.0` and `g_RiskPercentOfBalance=1.0`.
- `Files/ATRMomentumRelVolEMAFilter/MRV_EMA_EURUSD_Genetic_20260731.ini`: prepared EURUSD H1 genetic optimization config for the experimental EMA-filtered variant using `2000.01.01 -> 2018.01.01` and forward mode enabled. Do not run automatically from assistant sessions unless explicitly requested.
- `Files/ATRMomentumRelVolEMAFilter/Run-MRV-EURUSD-EphemeralGenerator.ps1`: restartable EURUSD throwaway-manifold runner for the experimental EMA-filtered variant. Defaults are `36m` IS, `3m` validation, `3m` OOS, `3m` primary OOS horizon, and `1m` rolling step. The prepared 2025 run uses OOS starts `2025.01.01 -> 2025.03.01` for three iterations.
- `Profiles/Tester/ATRMomentumRelVolEMAFilter_WalkForward_Current.set`: optimizer preset for the experimental EMA-filtered variant. It optimizes ATR period, momentum ATR multiplier, contiguous candles, relative-volume length/signal candles/threshold, fast and slow EMA lengths, minimum EMA separation candles, fixed starting-balance risk percent, take-profit multiple, and max stop-loss ATR multiple.
- `Files/ThreeDayTrendSignal/Run-TDTS-WalkForwardRestartable.ps1`: restartable TDTS rolling-cycle runner from the older EURUSD-discovery plus cross-symbol-promotion workflow. Treat it as legacy scaffolding unless it is revised for the new per-symbol ephemeral-generator process.
- `Files/ThreeDayTrendSignal/Run-TDTS-EURUSD-EphemeralGenerator.ps1`: active restartable EURUSD baseline generator runner. Defaults are `36m` IS, `3m` validation, `3m` OOS, `3m` primary OOS horizon, and `1m` rolling step. Most validation ranking modes promote exactly one OOS candidate when validation reports exist; explicit abstention modes such as `PositiveLowestTradesHardGates` can record no selection.
- `Files/ThreeDayTrendSignal/tdts_ephemeral_optimizer_current.ini`: current generated optimizer config for the active EURUSD generator runner.

Latest six-window EURUSD generator result: under process `tdts_eg_eurusd_2017_is36m_val3m_oos3m_step1m`, the best tested validation selection mode is `PositiveLowestTrades`, with net OOS `+9,214.41` across the first six monthly OOS windows. `PositiveLowestTradesFinalMonth` produced net OOS `+7,881.33`, `PositiveLowestTradesHardGates` produced net OOS `+1,223.10`, and `PositiveLowestTradesQualityFloor` produced net OOS `-6,558.80`. These results are not robust because W0004-W0006 remain weak across tested modes. Next useful work should move beyond simple selection filters toward process-level tests such as shorter OOS deployment or implementing the missing daily trend/final signal logic.

Testing caveat: the first completed `2026-07-18` EURUSD H1 genetic run used the earlier fixed `0.10` lot model and predates RelVol plus square-only trade gating. Treat it as superseded historical evidence; current generator work should use `tdts_eg_eurusd_2017_is36m_val3m_oos3m_step1m` or a later named process version.

Latest rolling-cycle result under the older workflow: `tdts_rm_2018_5y_1y_1y` used optimization `2012 -> 2017`, validation `2017 -> 2018`, and OOS `2018 -> 2019` across FX28. It selected `25` EURUSD optimizer candidates, promoted `21` candidate-symbol pairs to OOS, and produced one accepted OOS unit: `TDTS_Pass262` on `EURUSD` with OOS profit `15,178.89`, DD `7.28%`, ratio `2.085`, and `48` trades. Trading all promoted pairs was negative in aggregate, so treat this as historical context rather than the active process.
