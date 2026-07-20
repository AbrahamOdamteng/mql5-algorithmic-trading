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

The initial MQL5 work drew chart markers only. Momentum-circle market orders are now explicitly enabled for genetic testing; final-signal trade logic should still wait for explicit approval.

## Research Context

The current research direction is the Ephemeral Manifold Generator, not a forever-manifold search. Three Day Trend Signal is the current EA implementation being used as the strategy substrate, while the research product is the repeatable per-symbol optimize, validate, select, freeze, and OOS-decay pipeline described in `ephemeral-manifold-generator.md`.

## Current MQL5 Implementation

Current EA:

```text
Experts/ThreeDayTrendSignal/ThreeDayTrendSignalEA.mq5
```

Implemented so far:

- ATR momentum candle feature only.
- Blue circle marker for bullish momentum.
- Red circle marker for bearish momentum.
- Optional market order execution for newly drawn momentum circles.
- No relative volume logic.
- No three-day trend filter.
- No final long/short triangle signals.

Current momentum formula:

```text
abs(current close - open from contiguousCandles - 1 bars ago) >= ATR(14) * ATR Multiplier
```

When building the contiguous candle block, the EA checks the high/low range gap between each adjacent pair. If a non-overlapping range gap is greater than `ATR * GAP_ATR_SKIP_FRACTION`, older candles beyond that gap are excluded from the momentum calculation. `GAP_ATR_SKIP_FRACTION` is hardcoded to `0.1`.

Default inputs mirror the PineScript momentum defaults:

```text
g_ATR_Period = 14
g_ATR_Multiplier = 5.0
g_ContiguousCandles = 2
```

The EA processes closed candles. On initialization it draws recent historical momentum markers, then on each new bar it evaluates the latest closed bar.

Trade execution for genetic testing:

- `g_EnableTrading` controls whether newly drawn momentum circles place market orders.
- Blue momentum circles place buy market orders.
- Red momentum circles place sell market orders.
- Position size is calculated from `g_StartingBalance * g_RiskPercentOfBalance / 100.0` and the actual stop-loss distance.
- Default risk model is `1.0%` of a fixed `100000.0` starting balance, so the risk amount is `1000.0` account currency per trade unless inputs are changed.
- `g_StopLossATRMultiple` sets stop-loss distance as a multiple of ATR.
- `g_TakeProfitSLMultiple` sets take-profit distance as a multiple of the stop-loss distance.
- Historical markers drawn during `OnInit()` do not place trades.

## Marker Mapping

Implemented now:

- Bullish ATR momentum: blue circle above the bar.
- Bearish ATR momentum: red circle below the bar.

Planned later:

- Relative volume threshold without ATR momentum: orange diamond.
- Bullish ATR momentum plus relative volume: aqua square.
- Bearish ATR momentum plus relative volume: purple square.
- Final long signal: large blue triangle up.
- Final short signal: large red triangle down.

## Implementation Sequence

Use this order unless the user changes direction:

1. Momentum candle markers.
2. Relative volume markers.
3. Daily trend filter.
4. Final long/short signal markers.
5. Backtest analysis and trade logging support if needed.
6. Order placement for final signals only after explicit user approval. Momentum-circle market orders are currently implemented for genetic testing.

## Verification Notes

The first EA version compiled through MetaEditor with:

```text
0 errors, 0 warnings
```

Latest compile status after fixed-balance risk sizing was added: `0 errors, 0 warnings`.

Future changes should continue compiling cleanly before being considered complete.

## Prepared Tester Setups

- `Files/ThreeDayTrendSignal/TDTS_EURUSD_Genetic_20260718.ini`: prepared EURUSD H1 genetic optimization config for `2000.01.01 -> 2018.01.01` with forward mode enabled. Do not run automatically from assistant sessions unless explicitly requested.
- `Profiles/Tester/ThreeDayTrendSignal_EURUSD_Genetic_20260718.set`: matching optimizer input preset for ATR period, ATR momentum multiplier, contiguous candle count, stop-loss ATR multiple, and take-profit SL multiple. Current lot sizing uses fixed starting-balance risk with `g_StartingBalance=100000.0` and `g_RiskPercentOfBalance=1.0`.
- `Files/ThreeDayTrendSignal/Run-TDTS-WalkForwardRestartable.ps1`: restartable TDTS rolling-cycle runner from the older EURUSD-discovery plus cross-symbol-promotion workflow. Treat it as legacy scaffolding unless it is revised for the new per-symbol ephemeral-generator process.
- `Files/ThreeDayTrendSignal/Run-TDTS-EURUSD-EphemeralGenerator.ps1`: active restartable EURUSD baseline generator runner. Defaults are `5y` IS, `6m` validation, `12m` OOS, `3m` primary OOS horizon, and `1m` rolling step. Validation ranking always promotes exactly one OOS candidate when validation reports exist.
- `Files/ThreeDayTrendSignal/tdts_ephemeral_optimizer_current.ini`: current generated optimizer config for the active EURUSD generator runner.

Testing caveat: the first completed `2026-07-18` EURUSD H1 genetic run used the earlier fixed `0.10` lot model. Rerun the genetic test after the fixed-balance risk-sizing change before promoting candidates from that result.

Latest rolling-cycle result under the older workflow: `tdts_rm_2018_5y_1y_1y` used optimization `2012 -> 2017`, validation `2017 -> 2018`, and OOS `2018 -> 2019` across FX28. It selected `25` EURUSD optimizer candidates, promoted `21` candidate-symbol pairs to OOS, and produced one accepted OOS unit: `TDTS_Pass262` on `EURUSD` with OOS profit `15,178.89`, DD `7.28%`, ratio `2.085`, and `48` trades. Trading all promoted pairs was negative in aggregate, so treat this as historical context rather than the active process.
