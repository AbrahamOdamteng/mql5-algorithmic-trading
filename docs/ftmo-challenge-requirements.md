# FTMO Challenge Strategy Requirements

This document defines the current requirements for finding and testing challenge-stage strategies. The challenge-stage strategy is allowed to differ from the funded-stage strategy.

Record challenge-stage experiments in `ftmo-challenge-experiment-log.md`. Record funded-stage experiments in `ftmo-funded-experiment-log.md`.

## Operating Assumptions

| Item | Value |
| --- | ---: |
| Account size | `$100,000` |
| Challenge fee | `GBP 500` |
| Refund | Refunded on first payout |
| Maximum retries to model | `10` |
| Maximum acceptable losing streak | `10` |
| Challenge target | `+10%` |
| Verification target | `+5%` |
| Daily loss limit | `-5%` |
| Maximum loss limit | `-10%` |

## Objective

Optimize for single-stage pass rate first.

Do not optimize for the fastest pass if that creates low-reliability or consistency-rule risk. Speed is a secondary sanity check after pass rate, breach behavior, and consistency diagnostics.

The funded-stage strategy can be lower risk and different from the challenge strategy. Funded-stage testing should be evaluated separately using survival, payout, and monthly return metrics.

## Ranking Priority

Rank challenge candidates in this order:

1. Single-stage pass rate before daily or global breach.
2. Global-loss breach rate.
3. Daily-loss breach rate.
4. Consistency-rule warnings.
5. Median pass duration.
6. Average pass duration.
7. Expected challenge-fee cost per pass.
8. Losing-streak distribution over `10` attempts.

## Acceptance Bands

Use these as the first promotion gates for challenge-mode candidates:

| Grade | Single-stage pass rate | Interpretation |
| --- | ---: | --- |
| `A` | `>= 90%` | Strong |
| `B` | `>= 85%` | Preferred |
| `C` | `>= 75%` | Minimum viable |
| Reject | `< 75%` | Too weak for the current goal |

The hard promotion gate is currently `>= 75%` single-stage pass rate. Prefer `>= 85%` before spending heavy compute or manual review time.

## Speed Rules

Speed should not dominate the search, but very slow candidates tie up capital and reduce practical retry throughput.

Use these speed rules:

- Preferred median pass duration: `<= 90` trading days.
- Warning median pass duration: `> 90` trading days.
- Strong warning median pass duration: `> 120` trading days.
- Mark simulations unresolved after `180` calendar days unless a specific prop-firm model requires a different limit.

Report both trading days and calendar days. Trading days are better for strategy opportunity count; calendar days are better for account operations.

## Verification Stage

After a candidate passes the challenge-stage filter, replay verification separately with a `+5%` target.

Default verification assumptions:

- Use the same strategy.
- Test the same risk settings and one reduced-risk setting.
- Report two-stage success as `challenge pass rate * verification pass rate` only as an approximation; also run a sequential challenge-then-verification replay when tooling supports it.

## Challenge Fee Economics

For a single-stage pass rate `p`, expected gross challenge-fee cost per challenge pass is:

```text
GBP 500 / p
```

Report expected gross fee cost for every promoted candidate. Also report the probability of at least one pass within `10` attempts:

```text
1 - (1 - p)^10
```

Refund is only expected on first payout, so net economics must be evaluated with the funded-stage strategy, not with the challenge strategy alone.

## Consistency Diagnostics

Because some prop firms have consistency rules, every challenge replay should report profit concentration at the point of pass.

Required diagnostics:

- Largest winning day divided by target profit.
- Largest winning trade divided by target profit.
- Top `3` winning days divided by target profit.
- Number of trading days contributing positive profit before pass.

Initial warning thresholds:

| Diagnostic | Warning |
| --- | ---: |
| Largest winning day / target profit | `> 40%` |
| Largest winning trade / target profit | `> 30%` |
| Top 3 winning days / target profit | `> 70%` |

These are warnings, not hard rejects, unless testing a specific prop-firm rule. If a candidate's pass rate depends on one outsized day or trade, downgrade it before promotion.

## Risk Sweep

Use this default challenge-mode risk sweep for normalized replay:

```text
0.25%, 0.35%, 0.50%, 0.65%, 0.75%, 1.00%, 1.25%, 1.50%, 2.00%
```

Only extend above `2.00%` if a candidate has unusually low daily/global breach rates and no severe consistency concentration.

## Replay Requirements

Fixed MT5 report profit is not enough for challenge strategy selection.

Required replay behavior:

- Start simulations from many historical trade events or dates.
- Sort trade events by `deal_time` before replay.
- Deduplicate reruns by a stable key such as `manifold_id + test_id + symbol + ticket + trade_id + entry_type + deal_time`.
- Stop each replay when target, daily breach, global breach, timeout, or end-of-data occurs.
- Report unresolved starts separately.

Required output columns for each candidate/risk setting:

- `candidate_id`
- `risk_pct`
- `target_pct`
- `starts`
- `passes`
- `global_loss_failures`
- `daily_loss_failures`
- `unresolved`
- `single_stage_pass_rate`
- `median_trading_days_to_pass`
- `median_calendar_days_to_pass`
- `average_trading_days_to_pass`
- `average_calendar_days_to_pass`
- `expected_gross_fee_per_pass_gbp`
- `probability_at_least_one_pass_in_10_attempts`
- `worst_losing_streak_observed`
- `largest_winning_day_target_share_p50`
- `largest_winning_day_target_share_p90`
- `largest_trade_target_share_p90`
- `top3_winning_days_target_share_p90`

## Data Limitations

Closed-PnL replay is acceptable for fast screening, but it is only a proxy.

Before promotion to serious challenge use, prefer equity-aware replay or MT5 report review that can detect intratrade floating-equity breaches. Closed-PnL replay can miss daily-loss, global-loss, or profit-target touches that occurred before a trade closed.

## Search Implications

The fast strategy-generation workflow should favor candidates with:

- High rolling first-passage pass rate.
- Moderate pass speed without forcing over-risked behavior.
- Enough trade frequency to produce many replay starts.
- Low daily/global breach rates.
- Low profit concentration at pass.
- Robustness across shifted windows and execution-cost stress after initial screening.

Do not reject a candidate only because it is not the fastest. Reject it if it cannot pass often enough, breaches too often, depends on one outsized event, or remains unresolved too frequently.
