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

### 2026-06-21 - Challenge Requirements Split From Funded Mode

- Goal: Make FTMO challenge-stage research independent from funded-stage strategy requirements.
- Change or experiment: Created a dedicated pass-rate-first challenge requirements document and a dedicated challenge experiment log.
- Test setup: Documentation-only change; no MT5 tests run.
- Outcome: Challenge-stage work now has its own canonical requirements and log file.
- Decision or next step: Use this file for future FTMO challenge experiments, especially candidate-generation, replay scoring, consistency diagnostics, and retry-economics results.
