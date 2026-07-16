# FTMO Challenge Experiment Log

This file records experiments, code changes, tests, and observed outcomes for FTMO challenge-stage strategy generation and replay.

Use this log for pass-rate-first challenge research, including challenge `+10%`, verification `+5%`, daily/global breach analysis, consistency diagnostics, retry economics, and fast candidate-generation workflows.

Do not use this file for funded-stage survival or payout analysis. Use `ftmo-funded-experiment-log.md` for funded-stage work.

## Format

Each entry should include:

- Date
- Goal
- Change or experiment
- Test setup
- Outcome
- Decision or next step

## Current Requirements Snapshot

- Account size: `$100,000`
- Challenge fee: `GBP 500`
- Refund: first payout
- Maximum modeled retries: `10`
- Maximum acceptable losing streak: `10`
- Challenge target: `+10%`
- Verification target: `+5%`
- Daily loss limit: `-5%`
- Maximum loss limit: `-10%`
- Ranking priority: single-stage pass rate first
- Hard promotion gate: `>= 75%` single-stage pass rate
- Preferred promotion gate: `>= 85%` single-stage pass rate
- Canonical requirements file: `ftmo-challenge-requirements.md`

## Entries

### 2026-07-14 - Rolling Short-Horizon Manifold Research Goal

- Goal: Add a new challenge-stage research branch that tests rotating short-lived manifolds instead of requiring one manifold to work indefinitely.
- Change or experiment: Documented a proposed rolling workflow: optimize `EURUSD` over a rolling `5`-year window, select top `X` manifolds, screen them across other symbols, then trade successful manifolds only for `N` weeks or `N` closed trades before rolling forward and re-optimizing.
- Change or experiment: Refined the cross-symbol role: non-EURUSD checks inside the `5`-year discovery window are weak sanity filters only, while the short non-EURUSD validation slice after discovery is the real promotion gate.
- Test setup: Documentation-only change; no MT5 tests run.
- Outcome: The rolling-manifold idea is now captured as a separate branch alongside the existing fixed-manifold and behavior-cluster workflows.
- Decision or next step: Future rolling-manifold experiments should be recorded in `rolling-manifold-experiment-log.md`. Define `X`, validation-slice length, deployment horizon, weak discovery-window sanity filters, cross-symbol validation promotion gates, and how skipped windows should count in the stitched walk-forward score.

### 2026-06-21 - Challenge Requirements Split From Funded Mode

- Goal: Make FTMO challenge-stage research independent from funded-stage strategy requirements.
- Change or experiment: Created a dedicated pass-rate-first challenge requirements document and a dedicated challenge experiment log.
- Test setup: Documentation-only change; no MT5 tests run.
- Outcome: Challenge-stage work now has its own canonical requirements and log file.
- Decision or next step: Use this file for future FTMO challenge experiments, especially candidate-generation, replay scoring, consistency diagnostics, and retry-economics results.
