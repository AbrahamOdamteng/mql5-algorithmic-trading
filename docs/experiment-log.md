# Experiment Log

This file records experiments, code changes, tests, and observed outcomes for the WeekHighLow EA and indicator.

Update this log only when explicitly asked.

## Format

Each entry should include:

- Date
- Goal
- Change or experiment
- Test setup
- Outcome
- Decision or next step

## Entries

### 2026-06-02 - EURUSD Optimization And Forward Review

- Goal: Review the combined MT5 optimizer and forward-test results to determine whether any parameter manifold succeeded in both in-sample and validation periods.
- Source file: `docs/EURUSD_Optimize_2000_2018_FWD_OPT.xlsx`.
- Test setup: EURUSD MT5 optimization results amalgamated with MT5 optimizer forward results.
- Test periods: `2000 -> 2012` in-sample optimization, `2012 -> 2018` optimizer forward validation.
- Workbook structure: 1 worksheet, `23,100` data rows, `18` columns.
- Row breakdown: `21,000` optimizer rows and `2,100` forward rows.
- Pairing method: `Pass` links an `OPTIMIZER` row with its corresponding `FORWARD` row.
- Parameters tested: `g_ATR_Cluster_multiplier`, `g_impulse_lookback_hours`, `g_pullback_lookforward_hours`, `g_Impulse_ATR_multiplier`, `g_pullback_ATR_multiplier`, `g_TakeProfitMultiplier`.
- Acceptance criteria used: in-sample profit `> 0`, validation profit `> 0`, and equity drawdown `< 20%` in every test period.
- Result: `0` paired passes met the drawdown requirement. No row had equity drawdown below `20%` in both optimizer and forward periods.
- Additional observation: Without the drawdown requirement, `61` paired passes had positive optimizer profit, positive forward profit, and profit factor greater than `1` in both periods.
- Non-qualifying successful-profit region: most of the `61` positive-profit paired passes clustered around `g_ATR_Cluster_multiplier = 0.25`, `g_pullback_lookforward_hours = 24`, `g_pullback_ATR_multiplier = 0.35` or `0.40`, and `g_TakeProfitMultiplier = 3` or `5`.
- Best balanced non-qualifying candidate by positive profit in both periods: pass `16494`, using `g_ATR_Cluster_multiplier = 0.25`, `g_impulse_lookback_hours = 48`, `g_pullback_lookforward_hours = 24`, `g_Impulse_ATR_multiplier = 0.7`, `g_pullback_ATR_multiplier = 0.4`, `g_TakeProfitMultiplier = 4`; optimizer profit `57,996.88`, optimizer profit factor `1.038`, optimizer equity DD `71.63%`, forward profit `57,017.35`, forward profit factor `1.059`, forward equity DD `35.73%`.
- Decision or next step: This optimization/forward file does not contain an acceptable manifold under the current profit and drawdown rules. Further tests should prioritize reducing drawdown before evaluating out-of-sample `2018 -> 2026` performance.
