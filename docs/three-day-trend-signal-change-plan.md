# Three Day Trend Signal Change Plan

Use this document to plan and record proposed changes to the Three Day Trend Signal strategy before implementation.

## Purpose

The goal is to separate strategy-design decisions from code changes. Proposed changes should be written here first, reviewed, and only then implemented in the EA, tester presets, runner scripts, or documentation.

## Current Baseline

- Active EA: `Experts/ThreeDayTrendSignal/ThreeDayTrendSignalEA.mq5`.
- ATR momentum candle markers are implemented.
- Relative volume markers are implemented using tick volume.
- Market orders currently execute only when ATR momentum and relative volume occur together, producing square markers.
- Daily trend filter is not implemented.
- Final long/short triangle signals are not implemented.
- Latest compile status documented elsewhere is `0 errors, 0 warnings`.

## Planning Rules

- Do not change EA behavior until the intended logic is written in this file.
- Keep changes small enough to verify visually and through tester output.
- Prefer marker-only implementation before enabling new trade execution behavior.
- Treat order-placement changes as separate from signal-drawing changes unless explicitly approved.
- Record whether a change affects visual markers, trade entry, stop loss, take profit, sizing, optimizer inputs, logging, or runner behavior.
- Implementation may either extend the existing EA or create a new EA if that is cleaner.
- The EA may be renamed if the new strategy variant is different enough to justify a separate identity.
- Functions and data structures may stay in one EA file or be split into separate include files if that keeps the implementation cleaner.

## Proposed Changes

Add proposed changes here before implementation.

| ID | Status | Area | Proposal | Decision | Notes |
| --- | --- | --- | --- | --- | --- |
| TDTS-001 | Ready | Trend filter inputs | Add two EMA calculations: a slow EMA and a fast EMA. Each EMA period should be controlled by an optimizable EA input named `g_SlowEMALength` and `g_FastEMALength`. The slow EMA length must be greater than the fast EMA length. | Implement in revised EA. | Defaults: fast `100`, slow `400`. Use chart timeframe, close price, and `INIT_PARAMETERS_INCORRECT` for `g_SlowEMALength <= g_FastEMALength`. Fast EMA optimizer range: min `25`, max `1975`, step `25`. Slow EMA optimizer range: min `50`, max `2000`, step `25`. |
| TDTS-002 | Ready | Trend filter gating | Add an optimizable integer input named `g_MinEMASeparationCandles`. A trade can only trigger after the fast and slow EMAs have remained separated for at least this many closed candles since the most recent cross or touch. | Implement in revised EA. | Optimizer range: min `0`, max `72`, step `3`. Use a computed helper, not persistent state. Count includes the signal candle. Exact equality is a touch and resets the count. |
| TDTS-003 | Ready | Trade entry filter | Trade only when a square marker exists and the EMA/price trend gate gives direction. Long trades require both current price and fast EMA above slow EMA. Short trades require both current price and fast EMA below slow EMA. In both cases, the EMAs must have been separated for at least `g_MinEMASeparationCandles`. | Implement in revised EA. | Square color does not matter. Any square is enough to satisfy the square requirement; trade direction comes from current bid/ask and fast EMA being on the same side of the slow EMA. Do not remember blocked square signals for later. |
| TDTS-004 | Ready | Risk sizing | Confirm optimizable risk-percentage input `g_RiskPercentOfBalance`, with optimizer range `0.1` to `1.0` step `0.1`. This is the percentage of fixed starting balance risked per trade. | Implement in revised EA. | If starting balance is `100000`, value `1.0` risks `1000` per trade and value `0.1` risks `100` per trade. Keep existing fixed-starting-balance risk model. |
| TDTS-005 | Ready | Trade execution | When all filters are met, open a market order at current bid/ask. Set stop loss at the slow EMA from the closed signal candle. Set take profit as a multiple of the stop-loss distance using optimizable input `g_TakeProfitSLMultiple`. Remove the old ATR stop-loss multiplier from the revised EA. | Implement in revised EA. | TP factor optimizer range: `1.0` to `5.0` with step `0.25`. Skip if the slow EMA is on the wrong side of entry or if broker stop-distance checks fail. |
| TDTS-006 | Ready | Stop-loss safety gate | Add an optimizable maximum stop-loss distance input named `g_MaxStopLossATRMultiple`. If the slow-EMA stop distance is greater than `ATR * g_MaxStopLossATRMultiple`, skip the trade. | Implement in revised EA. | Optimizer range: min `1.0`, max `10.0`, step `0.5`. Default `3.0`. This prevents oversized EMA-based stops from creating poor reward/risk or invalid sizing. |
| TDTS-007 | Ready | Relative volume inputs | Confirm optimizable relative-volume inputs. `g_RelVolLength` controls how many prior days are used to calculate the relative-volume average. Rename `g_RelVolCandles` to `g_RelVolSignalCandles`; it controls how many closed candles are accumulated for the relative-volume signal. | Implement in revised EA. | Keep the name `g_RelVolLength`. `g_RelVolLength` range: min `5` days, max `90` days, step `5` days. `g_RelVolSignalCandles` range: min `1`, max `10`, step `1`. |
| TDTS-008 | Ready | Chart visuals | Draw both EMA lines onto the chart in the revised EA. | Implement in revised EA. | Slow EMA must be blue. Fast EMA must be red. EMA drawing is visual-only and must not change signal or trade logic. |

## Draft Optimizer Inputs

| Input | Type | Min | Max | Step | Notes |
| --- | --- | ---: | ---: | ---: | --- |
| `g_FastEMALength` | Integer candles | `25` | `1975` | `25` | Must be less than `g_SlowEMALength`. |
| `g_SlowEMALength` | Integer candles | `50` | `2000` | `25` | Must be greater than `g_FastEMALength`. |
| `g_ATR_Period` | Integer candles | `10` | `500` | `5` | ATR period used for momentum threshold and max stop-loss size gate. Range is intended for H1/H2/H3/H4 and M30/M15 usage rather than daily-chart defaults. |
| `g_MomentumATRMultiplier` | Floating point | `1.0` | `10.0` | `0.25` | ATR multiplier used to decide whether the candle block has enough momentum. Replaces `g_ATR_Multiplier`. |
| `g_MinEMASeparationCandles` | Integer candles | `0` | `72` | `3` | Minimum closed candles since EMA cross or touch. |
| `g_ContiguousCandles` | Integer candles | `1` | `10` | `1` | Momentum block length used for square creation. |
| `g_RelVolSignalCandles` | Integer candles | `1` | `10` | `1` | Number of closed candles accumulated for the relative-volume signal. Replaces `g_RelVolCandles`. |
| `g_RelVolThreshold` | Floating point | `1.0` | `10.0` | `0.5` | Relative-volume threshold used for diamond/square creation. |
| `g_RiskPercentOfBalance` | Floating point | `0.1` | `1.0` | `0.1` | Percentage of fixed starting balance risked per trade. |
| `g_TakeProfitSLMultiple` | Floating point | `1.0` | `5.0` | `0.25` | Take-profit distance as a multiple of slow-EMA stop-loss distance. |
| `g_MaxStopLossATRMultiple` | Floating point | `1.0` | `10.0` | `0.5` | Maximum allowed slow-EMA stop distance in ATR multiples. |

## Draft Trade Gate

A trade is allowed only when the signal conditions below are true on the closed signal candle and the current bid/ask price-side check passes at order placement:

- A square marker condition exists, meaning ATR momentum and relative volume occur together.
- For a long trade, both the current price and fast EMA are above the slow EMA.
- For a short trade, both the current price and fast EMA are below the slow EMA.
- The fast and slow EMAs have remained separated for at least `g_MinEMASeparationCandles` closed candles since the most recent cross or touch.

The square marker color does not matter. Any square can trigger either a long or short candidate. The trade direction is determined only by the EMA relationship:

- Current price above slow EMA and fast EMA above slow EMA: long candidate.
- Current price below slow EMA and fast EMA below slow EMA: short candidate.

Examples where a long trade is allowed by the EMA/price side gate:

| Current price | Fast EMA | Slow EMA | Gate result |
| ---: | ---: | ---: | --- |
| `110` | `105` | `100` | Long allowed |
| `105` | `110` | `100` | Long allowed |

## Draft Risk Model

Risk per trade should be calculated from fixed starting balance, not current account balance:

```text
risk_amount = starting_balance * risk_percentage / 100.0
```

Examples with `starting_balance = 100000`:

| Risk percentage | Risk amount per trade |
| ---: | ---: |
| `1.0` | `1000` |
| `0.1` | `100` |

The planned optimizer range for risk percentage is `0.1` to `1.0` with step `0.1`.

## Draft Trade Model

When all filters are met:

- Open a market order at the current price.
- For a long trade, set stop loss at the slow EMA.
- For a short trade, set stop loss at the slow EMA.
- Calculate stop-loss distance from entry price to the slow EMA stop.
- Set take profit as a multiple of the stop-loss distance.

Take-profit formula:

```text
take_profit_distance = stop_loss_distance * take_profit_sl_multiple
```

Planned take-profit input:

| Input | Type | Min | Max | Step |
| --- | --- | ---: | ---: | ---: |
| `g_TakeProfitSLMultiple` | Floating point | `1.0` | `5.0` | `0.25` |

Planned maximum stop-loss gate:

```text
max_stop_loss_distance = ATR * max_stop_loss_atr_multiple
```

If the actual stop-loss distance from entry price to the slow EMA is greater than this maximum, no trade is executed.

| Input | Type | Min | Max | Step |
| --- | --- | ---: | ---: | ---: |
| `g_MaxStopLossATRMultiple` | Floating point | `1.0` | `10.0` | `0.5` |

## Draft Relative Volume Input

Relative volume should use an optimizable lookback length instead of a fixed `20` day period.

Planned input:

| Input | Type | Min | Max | Step |
| --- | --- | ---: | ---: | ---: |
| `g_RelativeVolumeLength` or `g_RelVolLength` | Integer days | `5` | `90` | `5` |

This value determines how many prior same-intraday-slot candles are used to calculate the relative-volume baseline.

## Implementation Handoff Plan

This section is written for a future assistant or LLM implementation session. It should be treated as the implementation plan unless the user changes direction before coding starts.

### Preferred File Strategy

Create a separate revised EA instead of mutating the current active EA in place.

Recommended path:

```text
Experts/ATRMomentumRelVolEMAFilter/ATRMomentumRelVolEMAFilterEA.mq5
```

Rationale:

- The current `ThreeDayTrendSignalEA.mq5` is already tied to existing generator runs, presets, reports, and docs.
- A separate EA allows clean A/B comparison between the current square-marker strategy and the revised EMA-filtered variant.
- Existing runner scripts and presets can be copied or adapted later without breaking the current baseline.
- The implementation can still reuse most current EA logic by copying the file first, then making targeted changes.
- The revised strategy does not trade in three-day chunks, so the new EA name should not include `ThreeDay`.
- The revised strategy should not be named after marker shapes, because chart marker shapes are implementation details that can change.

Keep the first implementation in one `.mq5` file. Do not split into include files initially. The current EA is small enough that a single file is easier to compile, test, and compare. Revisit include files only if signal evaluation, logging, or runner integration grows substantially.

### Revised EA Identity

Use a distinct object prefix and trade comments so chart objects and tester trades can be distinguished from the original EA.

Suggested names:

| Item | Suggested value |
| --- | --- |
| File | `ATRMomentumRelVolEMAFilterEA.mq5` |
| Folder | `Experts/ATRMomentumRelVolEMAFilter/` |
| Object prefix | `MRV_EMA_` |
| Magic number default | A new value, for example `3001002` |
| Long comment | `MRV EMA long` |
| Short comment | `MRV EMA short` |

### Input Set

Use these inputs in the revised EA. Remove `g_StopLossATRMultiple`.

| Input | Default | Optimized | Min | Step | Max | Notes |
| --- | ---: | --- | ---: | ---: | ---: | --- |
| `g_ATR_Period` | `14` | Yes | `10` | `5` | `500` | Used for momentum threshold and max stop-loss size gate. |
| `g_MomentumATRMultiplier` | `5.0` | Yes | `1.0` | `0.25` | `10.0` | Rename from `g_ATR_Multiplier`. |
| `g_ContiguousCandles` | `2` | Yes | `1` | `1` | `10` | Existing momentum block input. |
| `g_RelVolLength` | `20` | Yes | `5` | `5` | `90` | Prior-day same-slot lookback length. Keep this name unless user asks to rename. |
| `g_RelVolSignalCandles` | `1` | Yes | `1` | `1` | `10` | Rename from `g_RelVolCandles`. |
| `g_RelVolThreshold` | `1.5` | Yes | `1.0` | `0.5` | `10.0` | Existing RelVol signal threshold. |
| `g_FastEMALength` | `100` | Yes | `25` | `25` | `1975` | Must be less than slow EMA length. |
| `g_SlowEMALength` | `400` | Yes | `50` | `25` | `2000` | Must be greater than fast EMA length. |
| `g_MinEMASeparationCandles` | `0` | Yes | `0` | `3` | `72` | Minimum closed candles since EMA cross or touch. |
| `g_RiskPercentOfBalance` | `1.0` | Yes | `0.1` | `0.1` | `1.0` | Fixed starting-balance risk percentage. |
| `g_TakeProfitSLMultiple` | `2.0` | Yes | `1.0` | `0.25` | `5.0` | TP distance as a multiple of slow-EMA SL distance. |
| `g_MaxStopLossATRMultiple` | `3.0` | Yes | `1.0` | `0.5` | `10.0` | Skip trades when slow-EMA stop distance is too large. |
| `g_HistoryBarsToScan` | `2000` | No | N/A | N/A | N/A | Operational/chart input. |
| `g_MarkerSize` | `1` | No | N/A | N/A | N/A | Operational/chart input. |
| `g_DeleteObjectsOnInit` | `true` | No | N/A | N/A | N/A | Operational/chart input. |
| `g_EnableTrading` | `true` | No | N/A | N/A | N/A | Operational input. |
| `g_StartingBalance` | `100000.0` | No | N/A | N/A | N/A | Fixed risk base. |
| `g_MagicNumber` | `3001002` | No | N/A | N/A | N/A | Operational input. |
| `g_DeviationPoints` | `20` | No | N/A | N/A | N/A | Operational input. |

The default EMA values are implementation defaults only. The optimizer grid is the important research input.

### Indicator Handles

Create three indicator handles in `OnInit()`:

| Handle | MQL5 call | Purpose |
| --- | --- | --- |
| `g_ATR_Handle` | `iATR(_Symbol, _Period, g_ATR_Period)` | Momentum threshold and max SL distance. |
| `g_FastEMA_Handle` | `iMA(_Symbol, _Period, g_FastEMALength, 0, MODE_EMA, PRICE_CLOSE)` | Fast trend filter. |
| `g_SlowEMA_Handle` | `iMA(_Symbol, _Period, g_SlowEMALength, 0, MODE_EMA, PRICE_CLOSE)` | Slow trend filter and stop-loss level. |

Use chart timeframe for both EMAs. Use close price. These choices keep the implementation aligned with the EA's closed-candle processing and avoid multi-timeframe complications in the first revised version.

Release all valid handles in `OnDeinit()`.

### Parameter Validation

In `OnInit()`, validate at least:

- `g_ATR_Period >= 1`.
- `g_MomentumATRMultiplier > 0.0`.
- `g_ContiguousCandles >= 1`.
- `g_RelVolLength >= 1`.
- `g_RelVolSignalCandles >= 1`.
- `g_RelVolThreshold >= 0.0`.
- `g_FastEMALength >= 1`.
- `g_SlowEMALength >= 1`.
- `g_SlowEMALength > g_FastEMALength`.
- `g_MinEMASeparationCandles >= 0`.
- `g_MaxStopLossATRMultiple > 0.0`.
- `g_TakeProfitSLMultiple > 0.0` when trading is enabled.
- `g_StartingBalance > 0.0` when trading is enabled.
- `g_RiskPercentOfBalance > 0.0` when trading is enabled.

Return `INIT_PARAMETERS_INCORRECT` for invalid EMA ordering so the optimizer rejects those combinations cleanly.

### Signal Data Shape

Introduce a small local struct or equivalent pass-by-reference outputs for signal evaluation. Keep it simple; do not over-engineer.

Suggested struct:

```cpp
struct TDTSSignalContext
{
   bool hasMomentum;
   bool hasRelVol;
   bool hasSquare;
   bool bullishMomentum;
   double atrValue;
   double fastEMA;
   double slowEMA;
   int emaSeparationCandles;
   int tradeDirection;
};
```

Use `tradeDirection = 1` for long, `-1` for short, and `0` for no trade.

### Square Marker Logic

Preserve current marker logic unless the user later asks to change visuals:

- Momentum only: blue/red circles.
- RelVol only: orange diamond.
- Momentum plus RelVol: aqua/purple square.

For trade logic, square color must not determine direction. `hasSquare = hasMomentum && hasRelVol` is the only square requirement.

### EMA Chart Drawing

The revised EA must draw both EMA lines onto the chart for visual inspection:

- Slow EMA: blue line.
- Fast EMA: red line.

These EMA lines are chart visuals only. They must not alter signal evaluation, trade direction, stop-loss placement, take-profit placement, or position sizing.

Use the revised EA object prefix so EMA drawing objects can be deleted independently from other indicators or EAs. Historical drawing should cover the same practical chart window as marker drawing, and latest closed-bar processing should extend/update the EMA visuals without placing historical trades.

### EMA Separation Calculation

The revised EA needs the number of closed candles since the fast and slow EMA last crossed or touched.

Implement this as a pure helper function rather than a persistent global counter, because the EA already evaluates historical bars and latest closed bars by shift. A computed helper avoids state drift and works consistently for historical marker drawing and live closed-bar processing.

Suggested function:

```cpp
int CountEMASeparationCandles(double &fastEMAValues[], double &slowEMAValues[], const int shift)
```

Expected behavior:

- Use closed candles only.
- Start counting at `shift`.
- If `fastEMAValues[shift] == slowEMAValues[shift]`, return `0`.
- Determine current side from `fastEMAValues[shift] > slowEMAValues[shift]` or `<`.
- Walk older bars: `shift + 1`, `shift + 2`, and so on.
- Stop when the older bar is equal to the slow EMA or on the opposite side.
- Return the number of consecutive closed candles, including the signal candle, where fast and slow have stayed separated on the current side.

Use exact double comparison for cross/touch in the first implementation:

```cpp
fastEMA <= slowEMA
fastEMA >= slowEMA
```

For a current bullish EMA state, count while `fastEMA > slowEMA`. For a current bearish EMA state, count while `fastEMA < slowEMA`. This treats equality as touch and resets the count.

This means `g_MinEMASeparationCandles = 0` disables the duration requirement, while values above zero require the count to be greater than or equal to that input. Because the count includes the signal candle, a value of `3` means the signal candle plus two prior closed candles have maintained separation.

### EMA And Price Trade Gate

Evaluate the trade gate on the latest closed signal candle, but use the expected market entry price for the current-price side check.

For live/tester order placement:

- Long candidate entry price: current `tick.ask`.
- Short candidate entry price: current `tick.bid`.

Trade direction rules:

- If `hasSquare` is false, no trade.
- If `emaSeparationCandles < g_MinEMASeparationCandles`, no trade.
- If `tick.ask > slowEMA` and `fastEMA > slowEMA`, direction is long.
- Else if `tick.bid < slowEMA` and `fastEMA < slowEMA`, direction is short.
- Else no trade.

Do not remember blocked square signals for later. A square is valid only on the newly closed bar being processed. If EMA separation or price-side gate is not valid at that moment, skip the trade.

### Stop Loss And Take Profit

Replace ATR-based stop distance with slow-EMA stop price.

For a long trade:

```text
entry = tick.ask
stop_loss = slowEMA
stop_distance = entry - stop_loss
take_profit = entry + stop_distance * g_TakeProfitSLMultiple
```

For a short trade:

```text
entry = tick.bid
stop_loss = slowEMA
stop_distance = stop_loss - entry
take_profit = entry - stop_distance * g_TakeProfitSLMultiple
```

Skip the trade if:

- Long stop is not below entry.
- Short stop is not above entry.
- `stop_distance <= broker_min_stop_distance`.
- `take_profit_distance <= broker_min_stop_distance`.
- `stop_distance > atrValue * g_MaxStopLossATRMultiple`.

Normalize SL and TP to symbol digits after calculations.

### Position Sizing

Keep the existing risk-based sizing model.

Formula:

```text
risk_amount = g_StartingBalance * (g_RiskPercentOfBalance / 100.0)
```

Use `OrderCalcProfit()` with one lot and the EMA stop price to calculate one-lot stop risk. Then divide desired risk amount by one-lot stop risk and normalize to symbol volume step. Reuse the current `CalculateRiskBasedVolume()` and `NormalizeRiskVolume()` structure with direction based on trade direction rather than `bullishMomentum`.

### Function-Level Change Plan

Start by copying the current EA to the new file, then make these changes:

| Current function/area | Planned change |
| --- | --- |
| Inputs | Rename `g_ATR_Multiplier` to `g_MomentumATRMultiplier`; rename `g_RelVolCandles` to `g_RelVolSignalCandles`; remove `g_StopLossATRMultiple`; add fast/slow EMA inputs, min EMA separation, and max stop ATR multiple. |
| Globals | Add `g_FastEMA_Handle` and `g_SlowEMA_Handle`; update object prefix. |
| `OnInit()` | Validate new inputs; create ATR, fast EMA, and slow EMA handles; reject `slow <= fast`. |
| `OnDeinit()` | Release all indicator handles. |
| `DrawHistoricalMomentumMarkers()` | Copy fast and slow EMA buffers along with rates and ATR. Increase minimum history to cover the largest of ATR, EMA, momentum, and RelVol needs. Historical drawing remains marker-only for trade execution but must draw/update historical EMA chart lines. |
| `DrawSignalMarkerForShift()` | Copy enough rates, ATR, fast EMA, and slow EMA buffers for signal and EMA-separation evaluation. |
| `DrawSignalMarker()` | Keep marker output logic but use renamed inputs. It may optionally populate `hasSquare`. |
| EMA chart drawing helper | Draw or update slow EMA chart visuals in blue and fast EMA chart visuals in red using the revised EA object prefix. |
| `GetMomentumSignal()` | Replace `g_ATR_Multiplier` reference with `g_MomentumATRMultiplier`. |
| `IsRelativeVolumeSignal()` | Replace `g_RelVolCandles` with `g_RelVolSignalCandles`. |
| `ProcessLatestClosedBar()` | Draw/evaluate latest closed bar; if square exists and trading is enabled, evaluate EMA/price gate and call revised order execution. |
| `ExecuteMarketOrder()` | Replace `bullishMomentum` parameter with `tradeDirection`, `atrValue`, and `slowEMA`; derive entry from bid/ask; use slow EMA SL; use TP multiple; apply max ATR stop gate. |
| `CalculateRiskBasedVolume()` | Replace boolean direction with `tradeDirection`; map `1` to buy and `-1` to sell. |

### History Requirements

When copying bars and buffers, ensure enough history exists for all calculations:

```text
bars_needed = max(
  shift + g_ContiguousCandles,
  shift + g_RelVolSignalCandles + (g_RelVolLength * barsPerDay),
  shift + g_MinEMASeparationCandles + 2,
  shift + g_SlowEMALength + 10,
  shift + g_FastEMALength + 10,
  shift + g_ATR_Period + 10
)
```

The exact EMA warmup requirement can be larger in practice for very long EMAs. If `CopyBuffer()` returns fewer bars than needed or EMA values are unavailable, skip evaluation for that shift rather than using incomplete data.

### Tester Preset Plan

After the EA compiles, create a new tester preset instead of overwriting the current one.

Recommended preset path:

```text
Profiles/Tester/ATRMomentumRelVolEMAFilter_WalkForward_Current.set
```

Use `Y` only on the strategy optimizer parameters listed in the input table. Keep operational inputs fixed with `N`.

Do not update the existing generator runner until the new EA compiles and a basic fixed test or prepare-only tester config is verified.

### Runner Plan

If the user asks to run the ephemeral generator with the revised EA, copy the current runner and config rather than mutating the existing runner first.

Recommended runner path:

```text
Files/ATRMomentumRelVolEMAFilter/Run-MRV-EURUSD-EphemeralGenerator.ps1
```

Recommended process ID prefix:

```text
mrv_ema_eg_eurusd_2017_is36m_val3m_oos3m_step1m
```

Required generator structure for this revised EA:

- Use the throwaway-manifold concept from the active Ephemeral Manifold Generator research direction.
- Optimize each window for `36` months.
- Validate the selected optimizer candidates for `3` months.
- Run OOS for `3` months.
- Move the whole IS/VAL/OOS window forward by `1` month and repeat the full process.
- Treat each selected manifold as disposable; the product being tested is the repeatable generation process, not any one EMA-filtered parameter set.

Runner update requirements:

- Point generated INI files to `ATRMomentumRelVolEMAFilter/ATRMomentumRelVolEMAFilterEA.ex5`.
- Point generated fixed-test `.set` files to the new preset identity.
- Parse and carry through the renamed/new optimizer columns: `MomentumATRMultiplier`, `RelVolSignalCandles`, `FastEMALength`, `SlowEMALength`, `MinEMASeparationCandles`, `MaxStopLossATRMultiple`.
- Remove references to `StopLossATRMultiple` from generated fixed-test `.set` files for the revised EA.
- Keep old runner and old report folders untouched.

### Verification Sequence

Implement and verify in this order:

1. Copy EA to the new file and update file header, object prefix, magic number, and inputs.
2. Compile after input/handle changes before changing trade logic.
3. Add EMA buffer copying and separation-count helper.
4. Compile again.
5. Add EMA/price trade gate while keeping marker drawing unchanged.
6. Replace ATR stop logic with slow-EMA stop and max ATR stop-distance gate.
7. Compile with `0 errors, 0 warnings`.
8. Load on a chart with trading disabled or in visual tester and confirm circles, diamonds, and squares still draw.
9. Confirm historical markers drawn during `OnInit()` do not place trades.
10. Confirm only newly closed bars can place trades.
11. Confirm square color does not control direction by inspecting logs or trade comments when EMA direction disagrees with square color.
12. Confirm trades are skipped when slow EMA is on the wrong side of entry or stop distance exceeds `ATR * g_MaxStopLossATRMultiple`.
13. Create the new `.set` preset and verify the optimizer ranges match this document.
14. Only after the EA and preset are stable, adapt runner scripts if needed.

### Documentation Updates After Implementation

Update these docs only after code compiles and behavior is verified:

| File | Required update |
| --- | --- |
| `docs/three-day-trend-signal.md` | Add revised EMA-filtered EA as a current or experimental variant. |
| `docs/session-start.md` | Add a concise note if the revised EA becomes the active implementation. |
| `docs/architecture.md` | Update only if include files are introduced or the EA structure materially changes. |
| `docs/signal-flow.md` | Update if the revised trade gate becomes active research baseline. |

### Known Implementation Decisions Captured Here

- Use a new EA file for the revised strategy variant.
- Name the revised EA after its mechanics, not the original PineScript title or marker shapes.
- Keep implementation in one `.mq5` file initially.
- Use chart timeframe EMAs.
- Use close-price EMAs.
- Use `INIT_PARAMETERS_INCORRECT` for `slow EMA length <= fast EMA length`.
- Count EMA separation using closed candles and include the signal candle in the count.
- Treat EMA equality as touch and reset separation count.
- Use current bid/ask as the current price for the price-side trade gate.
- Do not remember blocked square signals for later.
- Use slow EMA as stop loss.
- Remove `g_StopLossATRMultiple`.
- Keep ATR for momentum detection and max stop-loss distance filtering.

### Main Risks To Watch

- Very long EMA lengths may require more history than `g_HistoryBarsToScan`; the EA must copy enough history for indicator buffers or skip safely.
- MQL5 `CopyBuffer()` indexing must remain series-aligned with `CopyRates()` arrays.
- Current bid/ask can be on a different side of the slow EMA than the closed signal candle close in fast markets; this is intentional for the first revised version.
- Slow EMA stop can be too close to broker stop levels; skip rather than forcing a wider stop.
- Slow EMA stop can produce very large position sizes when close to entry; broker stop-level and volume normalization checks must remain in place.
- The optimizer state space is very large. Do not shrink EMA ranges until first-run evidence supports doing so, unless the user changes this decision.

## Planned Internal State

| ID | Variable | Purpose | Notes |
| --- | --- | --- | --- |
| TDTS-002 | `emaSeparationCandles` or similar | Store the computed number of closed candles since the fast EMA and slow EMA last crossed or touched for the evaluated signal. | Calculate with a helper from EMA buffers for the requested shift; do not use a persistent global counter. Exact implementation name can follow existing EA naming style. |

## Decision Log

Record confirmed decisions here.

| Date | Decision | Reason |
| --- | --- | --- |
| 2026-07-31 | Created planning document before changing TDTS behavior. | Keep strategy design and implementation separated. |
| 2026-07-31 | Remove `g_StopLossATRMultiple` from the new/revised EA. | Stop loss will be calculated from the slow EMA, so ATR no longer defines the stop-loss distance. |
| 2026-07-31 | Require `slow EMA length > fast EMA length`. | Preserve the intended meaning of fast and slow trend filters and avoid ambiguous optimizer combinations. |
| 2026-07-31 | Use EMA optimizer ranges: fast `25 -> 1975` step `25`; slow `50 -> 2000` step `25`. | Define broad long-horizon EMA search space while preserving fast/slow ordering. |
| 2026-07-31 | Use `g_MinEMASeparationCandles` optimizer range `0 -> 72` step `3`. | Test whether a newly crossed EMA state or a longer sustained separation works better. |
| 2026-07-31 | Use `g_ContiguousCandles` optimizer range `1 -> 10` step `1`. | Keep momentum block length searchable. |
| 2026-07-31 | Use `g_RelVolThreshold` optimizer range `1.0 -> 10.0` step `0.5`. | Keep relative-volume confirmation strictness searchable. |
| 2026-07-31 | Rename `g_RelVolCandles` to `g_RelVolSignalCandles` and use optimizer range `1 -> 10` step `1`. | Make the input name clearer: it controls the relative-volume signal candle window, not the historical daily lookback. |
| 2026-07-31 | Use `g_RiskPercentOfBalance` optimizer range `0.1 -> 1.0` step `0.1`. | Test fixed starting-balance risk levels from `100` to `1000` per trade on a `100000` starting balance. |
| 2026-07-31 | Rename `g_ATR_Multiplier` to `g_MomentumATRMultiplier` and use optimizer range `1.0 -> 10.0` step `0.25`. | Make clear that the multiplier controls momentum detection, not ATR generally. |
| 2026-07-31 | Use `g_ATR_Period` optimizer range `10 -> 500` step `5`. | The revised EA is expected to run on H1/H2/H3/H4 and M30/M15, not primarily daily charts. |
| 2026-07-31 | Keep broad EMA ranges for the first run despite large state space. | Some parts of the range may prove uninformative, but this should be judged from first-run optimizer evidence before shrinking. |
| 2026-07-31 | Treat the implementation handoff plan as code-ready for the first revised EA pass. | Remaining questions from the original draft have been resolved in this document; no code-level blocker remains before creating the new EA file. |
| 2026-07-31 | Use the slow EMA value from the closed signal candle as the stop-loss anchor. | The revised EA evaluates closed candles and should avoid mixing the signal state with an in-progress EMA value. |
| 2026-07-31 | Draw both EMAs on the chart: slow EMA in blue and fast EMA in red. | Visual confirmation of the EMA filter and slow-EMA stop anchor should be possible directly on the chart. |

## Implementation Log

Record completed implementation work here after changes are made.

| Date | Change ID | Files Changed | Verification | Result |
| --- | --- | --- | --- | --- |
| 2026-07-31 | TDTS-001 through TDTS-008 | `Experts/ATRMomentumRelVolEMAFilter/ATRMomentumRelVolEMAFilterEA.mq5` | Compiled with MetaEditor64. | `0 errors, 0 warnings`. New EA file created with revised identity, inputs, ATR/EMA handles, marker preservation, EMA chart drawing, square-plus-EMA trade gate, slow-EMA stop loss, ATR max-stop safety gate, TP multiple, and fixed starting-balance risk sizing. Existing `ThreeDayTrendSignalEA.mq5` was not changed. |
| 2026-07-31 | Tester preset | `Profiles/Tester/ATRMomentumRelVolEMAFilter_WalkForward_Current.set` | Compared preset input names and ranges against the revised EA inputs and this document's optimizer table. | New separate optimizer preset created. Strategy inputs are optimizer-enabled; operational inputs are fixed. Existing TDTS presets were not changed. |
| 2026-07-31 | Documentation | `docs/three-day-trend-signal.md`, `docs/README.md`, `docs/architecture.md`, `docs/signal-flow.md` | Reviewed updated sections for active-baseline wording. | Documented the revised EA as an experimental EMA-filtered A/B variant while preserving the original TDTS EA as the active baseline. |
| 2026-07-31 | Tester config | `Files/ATRMomentumRelVolEMAFilter/MRV_EMA_EURUSD_Genetic_20260731.ini`, `reports/mrv_ema_eurusd_genetic_20260731/` | Verified referenced EA binary, preset, config file, and report folder paths exist. Did not launch MT5. | Added separate EURUSD H1 genetic/forward tester config for the experimental EMA-filtered variant. Existing TDTS tester configs were not changed. |
| 2026-07-31 | MRV throwaway-manifold runner | `Files/ATRMomentumRelVolEMAFilter/Run-MRV-EURUSD-EphemeralGenerator.ps1`, `Files/ATRMomentumRelVolEMAFilter/mrv_ema_ephemeral_optimizer_current.ini` | Ran `-PrepareOnly` for OOS starts `2025-01-01 -> 2025-03-01` with `36m` IS, `3m` validation, `3m` OOS, and `1m` step. Confirmed `windows.csv` contains three windows and generated optimizer config points at `ATRMomentumRelVolEMAFilter\ATRMomentumRelVolEMAFilterEA.ex5`. | Added separate restartable runner for the experimental EMA-filtered EA. Existing TDTS runner was not changed. |

## Verification Checklist

Use the relevant checks for each change.

- Compile `ATRMomentumRelVolEMAFilterEA.mq5` with `0 errors, 0 warnings`.
- Visually confirm marker behavior on chart history before relying on tester results.
- Confirm historical markers drawn during `OnInit()` do not place trades.
- Confirm newly added signal types do or do not trade as intended.
- If runner or preset behavior changes, run `-PrepareOnly` or another non-MT5-launching validation when possible.
- Update `docs/three-day-trend-signal.md` and `docs/session-start.md` if the active baseline changes.

## Open Questions

No code-level blockers remain for the first revised EA implementation described in this document.

Resolved implementation questions:

- Create a new EA at `Experts/ATRMomentumRelVolEMAFilter/ATRMomentumRelVolEMAFilterEA.mq5` instead of mutating the current TDTS EA.
- Keep the first implementation in one `.mq5` file, without new include files.
- Use default EMA lengths `g_FastEMALength=100` and `g_SlowEMALength=400`.
- Calculate both EMAs on the chart timeframe using close price.
- Return `INIT_PARAMETERS_INCORRECT` for `g_SlowEMALength <= g_FastEMALength`.
- Use the fast/slow EMA relationship only as a trade-entry filter for square-marker signals in this first revised version.
- Count EMA separation using closed candles, including the signal candle.
- Treat exact EMA equality as touch and reset the separation count.
- Block invalid square signals entirely; do not remember them for later.
- Use current bid/ask as the expected market entry price for the price-side gate and order entry.
- Reuse `g_RiskPercentOfBalance`.
- Use the slow EMA value from the closed signal candle as the stop-loss anchor.
- Skip the trade if the slow EMA is on the wrong side of entry price.
- Enforce broker minimum stop-distance checks and skip invalid trades instead of widening stops.
- Keep `g_RelVolLength` as the relative-volume lookback input name.
- Implement the revised trade-entry rules in the new EA first; do not alter the existing generator runner until the EA and preset are stable.
- Historical markers drawn during `OnInit()` remain marker-only and must not place trades.
- Draw the slow EMA on chart in blue and the fast EMA on chart in red.

Non-blocking follow-up decisions after the EA compiles:

- Whether to create the tester preset immediately after compile or after a visual marker check.
- Whether and when to copy/adapt the ephemeral-generator runner for the revised EA.
- Whether the revised EA becomes the active baseline or remains an experimental A/B variant after initial results.
