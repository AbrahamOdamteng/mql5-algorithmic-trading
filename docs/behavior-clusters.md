# Behavior Cluster Research Plan

This document extends the existing fixed-manifold workflow. It does not replace the prior approach of testing one parameter manifold across multiple symbols. The new idea is to test whether each symbol has one or more robust local strategy families, then build the FTMO portfolio from behaviorally distinct `symbol + cluster` strategy units.

## Motivation

The previous robustness check looked for a single parameter manifold that could work across a diverse symbol basket. That is a strong test, but it may be too restrictive because FX pairs, metals, indices, and energy can have genuinely different market structure.

The alternative robustness question is:

- Can each symbol support a stable local edge?
- Does that edge appear as a broad family of profitable parameter sets rather than one isolated winning pass?
- Are there multiple behaviorally distinct edges per symbol?
- Does a diversified portfolio of these symbol-specific edges pass FTMO-style challenge and verification rules quickly enough?

## FTMO Objective

The current challenge-stage target is pass-rate-first rather than speed-first. See `ftmo-challenge-requirements.md` for the canonical requirements.

Goal realignment set on `2026-06-14` and refined on `2026-06-21`: challenge/evaluation mode and funded mode may use different strategies. Challenge mode should be treated as an account-acquisition engine, targeting FTMO `+10%` before daily/global breach with single-stage pass rate prioritized over raw pass speed. Funded mode should be evaluated separately at lower risk, targeting steady `1% -> 3%` monthly extraction and account survival rather than another fast `+10%` first-passage target.

For FTMO-style evaluation, the relevant first-passage objective is:

```text
Reach +10% for challenge, then +5% for verification, before hitting daily or global loss limits, with pass rate prioritized over speed.
```

After funded status, the objective changes. The funded-stage goal is lower-risk survival and steady extraction, currently framed as roughly `1% -> 3%` monthly on aggregated funded capital rather than continuing to chase evaluation-speed returns.

This implies separate operating modes:

- Evaluation mode: enough risk and trade frequency to pass often without excessive breach or consistency-rule risk.
- Funded mode: lower risk, lower breach probability, and stable monthly profitability.

## Strategy Unit Definition

The live portfolio should be built from strategy units, not just symbols.

```text
strategy unit = symbol + behavior cluster representative
```

If `EURUSD` has three accepted behavior clusters, the portfolio may include three EURUSD units, one representative from each behavior cluster. If `XAUUSD` has one accepted behavior cluster, it contributes one unit and should be treated as a specialist rather than a fully robust core symbol.

## Discovery Workflow

Use the existing time segmentation, but change what is discovered and selected.

1. Run genetic optimization on the in-sample period only, currently `2000 -> 2012` where symbol history allows.
2. Apply broad in-sample filters for profit, drawdown, profit/DD ratio, and trade count.
3. Cluster surviving candidates by normalized parameter distance to find parameter families.
4. Validate family members on the validation period, currently `2012 -> 2018` or the symbol-specific available-history equivalent.
5. Generate trade CSV logs for validation survivors or representative members.
6. Cluster candidates by trade behavior overlap, not only by parameter distance.
7. Select random or median representatives from accepted behavior clusters, avoiding the historical best unless explicitly testing an upper bound.
8. Freeze the representatives and run untouched OOS, currently `2018 -> 2026`.
9. Run rolling FTMO first-passage analysis on the frozen portfolio.

The important constraint is that OOS and FTMO replay must not be used to discover the clusters. They are used to judge the frozen selection.

## Parameter Distance

Parameter distance answers whether two manifolds are numerically different.

For each optimized parameter:

```text
ParameterDistance_i = abs(A_i - B_i) / (Max_i - Min_i)
```

Overall manifold distance:

```text
ManifoldDistance = average(ParameterDistance_i)
```

Suggested interpretation:

| ManifoldDistance | Meaning |
| ---: | --- |
| `< 0.15` | Very similar |
| `0.15 -> 0.30` | Nearby |
| `0.30 -> 0.50` | Different |
| `> 0.50` | Very different |

Parameter distance is useful for finding stable parameter regions, but it is secondary to trade behavior. Two very different parameter sets can still take almost the same trades.

## Trade Behavior Distance

Trade behavior distance answers whether two manifolds are actually trading differently.

Two trades can be treated as matching if they have:

- Same symbol.
- Same direction.
- Entry time within a tolerance, initially `3` H1 bars or `24` hours depending on analysis strictness.
- Entry price within a tolerance, initially `0.25 ATR` or `0.25R` if those fields are available.

For two candidate manifolds:

```text
OverlapCoverage = MatchedTrades / min(TradeCountA, TradeCountB)
JaccardOverlap = MatchedTrades / (TradeCountA + TradeCountB - MatchedTrades)
TradeDistance = 1 - JaccardOverlap
```

`JaccardOverlap` is set intersection over union. It measures shared trades divided by all unique trades across both manifolds.

Suggested interpretation:

| Trade overlap | Meaning |
| --- | --- |
| `OverlapCoverage >= 85%` | Same behavior / clone |
| `60% -> 85%` | Related variant |
| `40% -> 60%` | Partially distinct |
| `< 40%` | Meaningfully distinct |
| `< 25%` | Strongly distinct |

Initial rule for separate behavior clusters:

```text
OverlapCoverage < 60%
JaccardOverlap < 40%
```

If the portfolio needs stricter independence, use:

```text
OverlapCoverage < 40%
JaccardOverlap < 25%
```

## Symbol Classification

Symbols should be promoted based on the number and quality of distinct profitable behavior clusters, not by preference alone.

| Distinct profitable behavior clusters | Symbol status |
| ---: | --- |
| `0` | Reject |
| `1` | Specialist / tradable but not robust |
| `2` | Minimum robust / support symbol |
| `3+` | Core symbol |
| `5+` | Very strong, but check overfitting and clone behavior |

Minimum symbol acceptance:

- At least `2` validation-profitable behavior clusters for support status.
- At least `3` validation-profitable behavior clusters for core status.
- Random or median members from the clusters should survive OOS often enough.
- Pairwise trade overlap between accepted clusters should remain below the chosen overlap threshold.
- The symbol should contribute useful trades without dominating portfolio drawdown.

## Portfolio-Level Target

For the FTMO challenge objective, the portfolio likely needs enough trade frequency to produce high pass rates without forcing excessive risk.

Use rough trade-frequency targets rather than symbol count alone:

- The portfolio should contain enough behaviorally distinct strategy units to generate meaningful `90`-day opportunity count.
- `8` symbols with `3` independent clusters each may be better than `20` symbols with one fragile cluster each.
- A practical early target is `20 -> 30` behaviorally distinct strategy units, then test whether that produces enough closed trades and pass-rate quality.

Current expected starting universe remains the expanded basket unless a new research phase deliberately changes it:

- `EURUSD`
- `GBPUSD`
- `USDJPY`
- `EURJPY`
- `XAUUSD`
- `XAGUSD`
- `US500`
- `US30`
- `US100`
- `UK100`
- `USOIL`
- `UKOIL`

Candidate symbols should become core, support, specialist, or rejected based on their cluster evidence.

## Selection Rule

Do not choose the best historical member from each family by default.

Preferred representative selection:

- Pick one random member from each accepted behavior cluster.
- Alternatively pick a median-quality member if deterministic reproducibility is needed.
- Do not pick multiple members from the same behavior cluster unless testing clone sensitivity.
- Repeat random portfolio sampling several times to estimate whether the cluster families are robust or dependent on lucky representatives.

## Open Implementation Needs

Needed utilities or script extensions:

- Candidate clustering by normalized parameter distance.
- Trade-log matching by symbol, direction, entry time, and price tolerance.
- Pairwise `OverlapCoverage`, `JaccardOverlap`, and `TradeDistance` reporting.
- Behavior-cluster assignment.
- Random or median representative selection from accepted clusters.
- Portfolio FTMO replay over selected `symbol + behavior cluster` units, including challenge plus verification timing.
