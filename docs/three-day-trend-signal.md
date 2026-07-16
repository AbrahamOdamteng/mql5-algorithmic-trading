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

The initial MQL5 work should draw chart markers only. Do not place trades until the visual signal logic matches the PineScript behavior closely enough for review.

## Current MQL5 Implementation

Current EA:

```text
Experts/ThreeDayTrendSignal/ThreeDayTrendSignalEA.mq5
```

Implemented so far:

- ATR momentum candle feature only.
- Blue circle marker for bullish momentum.
- Red circle marker for bearish momentum.
- No relative volume logic.
- No three-day trend filter.
- No final long/short triangle signals.
- No order placement.

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
6. Order placement only after explicit user approval.

## Verification Notes

The first EA version compiled through MetaEditor with:

```text
0 errors, 0 warnings
```

Future changes should continue compiling cleanly before being considered complete.
