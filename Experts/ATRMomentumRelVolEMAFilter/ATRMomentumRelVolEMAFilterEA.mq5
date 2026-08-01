//+------------------------------------------------------------------+
//|                              ATRMomentumRelVolEMAFilterEA.mq5    |
//| ATR momentum and relative-volume signals filtered by EMA trend.   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input int    g_ATR_Period                = 14;
input double g_MomentumATRMultiplier     = 5.0;
input int    g_ContiguousCandles         = 2;
input int    g_RelVolLength              = 20;
input int    g_RelVolSignalCandles       = 1;
input double g_RelVolThreshold           = 1.5;
input int    g_FastEMALength             = 100;
input int    g_SlowEMALength             = 400;
input int    g_MinEMASeparationCandles   = 0;
input double g_RiskPercentOfBalance      = 1.0;
input double g_TakeProfitSLMultiple      = 2.0;
input double g_MaxStopLossATRMultiple    = 3.0;
input int    g_HistoryBarsToScan         = 2000;
input int    g_MarkerSize                = 1;
input bool   g_DeleteObjectsOnInit       = true;
input bool   g_EnableTrading             = true;
input double g_StartingBalance           = 100000.0;
input ulong  g_MagicNumber               = 3001002;
input int    g_DeviationPoints           = 20;

const double GAP_ATR_SKIP_FRACTION = 0.1;

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

string   g_ObjectPrefix       = "MRV_EMA_";
int      g_ATR_Handle         = INVALID_HANDLE;
int      g_FastEMA_Handle     = INVALID_HANDLE;
int      g_SlowEMA_Handle     = INVALID_HANDLE;
datetime g_LastChartBarTime   = 0;
CTrade   g_Trade;

//+------------------------------------------------------------------+
int OnInit()
{
   if(g_ATR_Period < 1)
   {
      Print("g_ATR_Period must be at least 1");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(g_MomentumATRMultiplier <= 0.0)
   {
      Print("g_MomentumATRMultiplier must be greater than 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(g_ContiguousCandles < 1)
   {
      Print("g_ContiguousCandles must be at least 1");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(g_RelVolLength < 1)
   {
      Print("g_RelVolLength must be at least 1");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(g_RelVolSignalCandles < 1)
   {
      Print("g_RelVolSignalCandles must be at least 1");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(g_RelVolThreshold < 0.0)
   {
      Print("g_RelVolThreshold must be at least 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(g_FastEMALength < 1)
   {
      Print("g_FastEMALength must be at least 1");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(g_SlowEMALength < 1)
   {
      Print("g_SlowEMALength must be at least 1");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(g_SlowEMALength <= g_FastEMALength)
   {
      Print("g_SlowEMALength must be greater than g_FastEMALength");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(g_MinEMASeparationCandles < 0)
   {
      Print("g_MinEMASeparationCandles must be at least 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(g_MaxStopLossATRMultiple <= 0.0)
   {
      Print("g_MaxStopLossATRMultiple must be greater than 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(g_EnableTrading)
   {
      if(g_StartingBalance <= 0.0)
      {
         Print("g_StartingBalance must be greater than 0 when trading is enabled");
         return INIT_PARAMETERS_INCORRECT;
      }

      if(g_RiskPercentOfBalance <= 0.0)
      {
         Print("g_RiskPercentOfBalance must be greater than 0 when trading is enabled");
         return INIT_PARAMETERS_INCORRECT;
      }

      if(g_TakeProfitSLMultiple <= 0.0)
      {
         Print("g_TakeProfitSLMultiple must be greater than 0 when trading is enabled");
         return INIT_PARAMETERS_INCORRECT;
      }
   }

   g_ATR_Handle = iATR(_Symbol, _Period, g_ATR_Period);
   if(g_ATR_Handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR handle. Error: ", GetLastError());
      return INIT_FAILED;
   }

   g_FastEMA_Handle = iMA(_Symbol, _Period, g_FastEMALength, 0, MODE_EMA, PRICE_CLOSE);
   if(g_FastEMA_Handle == INVALID_HANDLE)
   {
      Print("Failed to create fast EMA handle. Error: ", GetLastError());
      return INIT_FAILED;
   }

   g_SlowEMA_Handle = iMA(_Symbol, _Period, g_SlowEMALength, 0, MODE_EMA, PRICE_CLOSE);
   if(g_SlowEMA_Handle == INVALID_HANDLE)
   {
      Print("Failed to create slow EMA handle. Error: ", GetLastError());
      return INIT_FAILED;
   }

   g_Trade.SetExpertMagicNumber(g_MagicNumber);
   g_Trade.SetDeviationInPoints(g_DeviationPoints);
   g_Trade.SetTypeFillingBySymbol(_Symbol);

   if(g_DeleteObjectsOnInit)
      DeleteEAObjects();

   DrawHistoricalMomentumMarkers();
   g_LastChartBarTime = iTime(_Symbol, _Period, 0);

   return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   if(g_ATR_Handle != INVALID_HANDLE)
   {
      IndicatorRelease(g_ATR_Handle);
      g_ATR_Handle = INVALID_HANDLE;
   }

   if(g_FastEMA_Handle != INVALID_HANDLE)
   {
      IndicatorRelease(g_FastEMA_Handle);
      g_FastEMA_Handle = INVALID_HANDLE;
   }

   if(g_SlowEMA_Handle != INVALID_HANDLE)
   {
      IndicatorRelease(g_SlowEMA_Handle);
      g_SlowEMA_Handle = INVALID_HANDLE;
   }
}

//+------------------------------------------------------------------+
void OnTick()
{
   datetime currentChartBarTime = iTime(_Symbol, _Period, 0);
   if(currentChartBarTime == g_LastChartBarTime)
      return;

   g_LastChartBarTime = currentChartBarTime;
   ProcessLatestClosedBar();
}

//+------------------------------------------------------------------+
void ProcessLatestClosedBar()
{
   TDTSSignalContext context;

   if(DrawSignalMarkerForShift(1, context) && context.hasSquare && g_EnableTrading)
      ExecuteMarketOrder(context);
}

//+------------------------------------------------------------------+
void DrawHistoricalMomentumMarkers()
{
   int availableBars = Bars(_Symbol, _Period);
   if(availableBars <= g_ContiguousCandles)
      return;

   int barsPerDay = GetBarsPerDay();
   int minimumHistoryBars = GetBarsNeededForShift(1, barsPerDay) + 10;
   int barsToCopy = MathMin(availableBars, MathMax(g_HistoryBarsToScan, minimumHistoryBars));

   MqlRates rates[];
   double atrValues[];
   double fastEMAValues[];
   double slowEMAValues[];

   int copiedRates = CopyRates(_Symbol, _Period, 0, barsToCopy, rates);
   int copiedAtr = CopyBuffer(g_ATR_Handle, 0, 0, barsToCopy, atrValues);
   int copiedFastEMA = CopyBuffer(g_FastEMA_Handle, 0, 0, barsToCopy, fastEMAValues);
   int copiedSlowEMA = CopyBuffer(g_SlowEMA_Handle, 0, 0, barsToCopy, slowEMAValues);

   if(copiedRates <= g_ContiguousCandles || copiedAtr <= 0 || copiedFastEMA <= 0 || copiedSlowEMA <= 0)
   {
      Print("Not enough history to draw MRV EMA markers");
      return;
   }

   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(atrValues, true);
   ArraySetAsSeries(fastEMAValues, true);
   ArraySetAsSeries(slowEMAValues, true);

   int oldestUsableShift = MathMin(copiedRates, MathMin(copiedAtr, MathMin(copiedFastEMA, copiedSlowEMA))) - 2;

   for(int shift = oldestUsableShift; shift >= 1; shift--)
   {
      TDTSSignalContext context;
      DrawEMALinesForShift(rates, fastEMAValues, slowEMAValues, shift);
      DrawSignalMarker(rates, atrValues, fastEMAValues, slowEMAValues, shift, context);
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
bool DrawSignalMarkerForShift(const int shift, TDTSSignalContext &context)
{
   MqlRates rates[];
   double atrValues[];
   double fastEMAValues[];
   double slowEMAValues[];
   int barsPerDay = GetBarsPerDay();
   int barsNeeded = GetBarsNeededForShift(shift, barsPerDay);

   int copiedRates = CopyRates(_Symbol, _Period, 0, barsNeeded, rates);
   int copiedAtr = CopyBuffer(g_ATR_Handle, 0, 0, barsNeeded, atrValues);
   int copiedFastEMA = CopyBuffer(g_FastEMA_Handle, 0, 0, barsNeeded, fastEMAValues);
   int copiedSlowEMA = CopyBuffer(g_SlowEMA_Handle, 0, 0, barsNeeded, slowEMAValues);

   if(copiedRates < barsNeeded || copiedAtr < barsNeeded || copiedFastEMA < barsNeeded || copiedSlowEMA < barsNeeded)
      return false;

   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(atrValues, true);
   ArraySetAsSeries(fastEMAValues, true);
   ArraySetAsSeries(slowEMAValues, true);

   DrawEMALinesForShift(rates, fastEMAValues, slowEMAValues, shift);
   bool markerDrawn = DrawSignalMarker(rates, atrValues, fastEMAValues, slowEMAValues, shift, context);
   ChartRedraw(0);
   return markerDrawn;
}

//+------------------------------------------------------------------+
bool DrawSignalMarker(MqlRates &rates[], double &atrValues[], double &fastEMAValues[], double &slowEMAValues[], const int shift, TDTSSignalContext &context)
{
   ResetSignalContext(context);

   context.fastEMA = GetBufferValue(fastEMAValues, shift);
   context.slowEMA = GetBufferValue(slowEMAValues, shift);
   context.emaSeparationCandles = CountEMASeparationCandles(fastEMAValues, slowEMAValues, shift);
   context.hasRelVol = IsRelativeVolumeSignal(rates, shift);
   context.hasMomentum = GetMomentumSignal(rates, atrValues, shift, context.bullishMomentum, context.atrValue);
   context.hasSquare = context.hasMomentum && context.hasRelVol;

   if(!context.hasMomentum && !context.hasRelVol)
      return false;

   if(context.hasSquare)
      return DrawMarker(rates[shift], context.atrValue, context.bullishMomentum ? "BullSquare_" : "BearSquare_", context.bullishMomentum, 110, context.bullishMomentum ? clrAqua : clrPurple);

   if(context.hasMomentum)
      return DrawMarker(rates[shift], context.atrValue, context.bullishMomentum ? "BullCircle_" : "BearCircle_", context.bullishMomentum, 159, context.bullishMomentum ? clrBlue : clrRed);

   double relVolAtrValue = GetBufferValue(atrValues, shift);
   return DrawMarker(rates[shift], relVolAtrValue, "RelVol_", true, 117, clrOrange);
}

//+------------------------------------------------------------------+
void ResetSignalContext(TDTSSignalContext &context)
{
   context.hasMomentum = false;
   context.hasRelVol = false;
   context.hasSquare = false;
   context.bullishMomentum = false;
   context.atrValue = 0.0;
   context.fastEMA = 0.0;
   context.slowEMA = 0.0;
   context.emaSeparationCandles = 0;
   context.tradeDirection = 0;
}

//+------------------------------------------------------------------+
bool GetMomentumSignal(MqlRates &rates[], double &atrValues[], const int shift, bool &bullishMomentum, double &signalAtrValue)
{
   int oldestRequestedShift = shift + g_ContiguousCandles - 1;
   int blockOpenShift = shift;
   double atrValue = GetBufferValue(atrValues, shift);

   if(atrValue <= 0.0 || oldestRequestedShift >= ArraySize(rates))
      return false;

   for(int olderShift = shift + 1; olderShift <= oldestRequestedShift; olderShift++)
   {
      int newerShift = olderShift - 1;
      double rangeGap = 0.0;

      if(rates[newerShift].low > rates[olderShift].high)
         rangeGap = rates[newerShift].low - rates[olderShift].high;
      else if(rates[newerShift].high < rates[olderShift].low)
         rangeGap = rates[olderShift].low - rates[newerShift].high;

      if(rangeGap > atrValue * GAP_ATR_SKIP_FRACTION)
         break;

      blockOpenShift = olderShift;
   }

   double blockOpen = rates[blockOpenShift].open;
   double blockClose = rates[shift].close;
   double contiguousRange = MathAbs(blockClose - blockOpen);

   if(contiguousRange < atrValue * g_MomentumATRMultiplier)
      return false;

   bullishMomentum = (blockClose >= blockOpen);
   signalAtrValue = atrValue;
   return true;
}

//+------------------------------------------------------------------+
bool IsRelativeVolumeSignal(MqlRates &rates[], const int shift)
{
   double relVolCombined = 0.0;

   for(int candleOffset = 0; candleOffset < g_RelVolSignalCandles; candleOffset++)
   {
      double relVol = 0.0;
      if(!GetRelativeVolumeForShift(rates, shift + candleOffset, relVol))
         return false;

      relVolCombined += relVol;
   }

   return relVolCombined >= g_RelVolThreshold;
}

//+------------------------------------------------------------------+
bool GetRelativeVolumeForShift(MqlRates &rates[], const int shift, double &relVol)
{
   int barsPerDay = GetBarsPerDay();
   double relVolSum = 0.0;
   int relVolCount = 0;

   for(int i = 1; i <= g_RelVolLength; i++)
   {
      int volumeShift = shift + (i * barsPerDay);
      if(volumeShift >= ArraySize(rates))
         continue;

      relVolSum += (double)rates[volumeShift].tick_volume;
      relVolCount++;
   }

   if(relVolCount <= 0)
      return false;

   double relVolAvg = relVolSum / (double)relVolCount;
   if(relVolAvg <= 0.0)
      return false;

   relVol = (double)rates[shift].tick_volume / relVolAvg;
   return true;
}

//+------------------------------------------------------------------+
int CountEMASeparationCandles(double &fastEMAValues[], double &slowEMAValues[], const int shift)
{
   double fastEMA = GetBufferValue(fastEMAValues, shift);
   double slowEMA = GetBufferValue(slowEMAValues, shift);

   if(fastEMA <= 0.0 || slowEMA <= 0.0 || fastEMA == slowEMA)
      return 0;

   bool bullishSide = fastEMA > slowEMA;
   int count = 0;

   for(int i = shift; i < ArraySize(fastEMAValues) && i < ArraySize(slowEMAValues); i++)
   {
      double fast = GetBufferValue(fastEMAValues, i);
      double slow = GetBufferValue(slowEMAValues, i);

      if(fast <= 0.0 || slow <= 0.0)
         break;

      if(bullishSide)
      {
         if(fast <= slow)
            break;
      }
      else
      {
         if(fast >= slow)
            break;
      }

      count++;
   }

   return count;
}

//+------------------------------------------------------------------+
double GetBufferValue(double &values[], const int shift)
{
   if(shift < 0 || shift >= ArraySize(values))
      return 0.0;

   if(values[shift] == EMPTY_VALUE)
      return 0.0;

   return values[shift];
}

//+------------------------------------------------------------------+
int GetBarsPerDay()
{
   int periodSeconds = PeriodSeconds(_Period);
   if(periodSeconds <= 0)
      return 1;

   return MathMax(1, (int)(86400 / periodSeconds));
}

//+------------------------------------------------------------------+
int GetBarsNeededForShift(const int shift, const int barsPerDay)
{
   int barsNeeded = shift + g_ContiguousCandles;
   barsNeeded = MathMax(barsNeeded, shift + g_RelVolSignalCandles + (g_RelVolLength * barsPerDay));
   barsNeeded = MathMax(barsNeeded, shift + g_MinEMASeparationCandles + 2);
   barsNeeded = MathMax(barsNeeded, shift + g_SlowEMALength + 10);
   barsNeeded = MathMax(barsNeeded, shift + g_FastEMALength + 10);
   barsNeeded = MathMax(barsNeeded, shift + g_ATR_Period + 10);
   return barsNeeded;
}

//+------------------------------------------------------------------+
void DrawEMALinesForShift(MqlRates &rates[], double &fastEMAValues[], double &slowEMAValues[], const int shift)
{
   DrawEMASegment(rates, slowEMAValues, shift, "SlowEMA_", clrBlue);
   DrawEMASegment(rates, fastEMAValues, shift, "FastEMA_", clrRed);
}

//+------------------------------------------------------------------+
void DrawEMASegment(MqlRates &rates[], double &emaValues[], const int shift, const string lineType, const color lineColor)
{
   int olderShift = shift + 1;
   if(shift < 0 || olderShift >= ArraySize(rates) || olderShift >= ArraySize(emaValues))
      return;

   double currentEMA = GetBufferValue(emaValues, shift);
   double olderEMA = GetBufferValue(emaValues, olderShift);
   if(currentEMA <= 0.0 || olderEMA <= 0.0)
      return;

   string name = g_ObjectPrefix + lineType + _Symbol + "_" + IntegerToString((int)_Period) + "_" + IntegerToString((int)rates[shift].time);

   if(ObjectFind(0, name) < 0)
   {
      if(!ObjectCreate(0, name, OBJ_TREND, 0, rates[olderShift].time, olderEMA, rates[shift].time, currentEMA))
      {
         Print("Failed to create MRV EMA line ", name, ". Error: ", GetLastError());
         return;
      }
   }
   else
   {
      ObjectMove(0, name, 0, rates[olderShift].time, olderEMA);
      ObjectMove(0, name, 1, rates[shift].time, currentEMA);
   }

   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
bool DrawMarker(const MqlRates &bar, const double atrValue, const string markerType, const bool aboveBar, const int arrowCode, const color markerColor)
{
   string name = g_ObjectPrefix + markerType + _Symbol + "_" + IntegerToString((int)_Period) + "_" + IntegerToString((int)bar.time);

   if(ObjectFind(0, name) >= 0)
      return false;

   double fallbackOffset = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;
   double markerOffset = MathMax(atrValue * 0.15, fallbackOffset);
   double markerPrice = aboveBar ? bar.high + markerOffset : bar.low - markerOffset;

   if(!ObjectCreate(0, name, OBJ_ARROW, 0, bar.time, markerPrice))
   {
      Print("Failed to create MRV EMA marker ", name, ". Error: ", GetLastError());
      return false;
   }

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode);
   ObjectSetInteger(0, name, OBJPROP_COLOR, markerColor);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, g_MarkerSize);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, aboveBar ? ANCHOR_BOTTOM : ANCHOR_TOP);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   return true;
}

//+------------------------------------------------------------------+
void ExecuteMarketOrder(TDTSSignalContext &context)
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      Print("Failed to get symbol tick. Error: ", GetLastError());
      return;
   }

   context.tradeDirection = GetTradeDirection(context, tick);
   if(context.tradeDirection == 0)
      return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int stopsLevelPoints = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDistance = stopsLevelPoints * point;
   double entryPrice = context.tradeDirection > 0 ? tick.ask : tick.bid;
   double stopLoss = context.slowEMA;
   double stopDistance = context.tradeDirection > 0 ? entryPrice - stopLoss : stopLoss - entryPrice;
   double takeProfitDistance = stopDistance * g_TakeProfitSLMultiple;

   if(stopDistance <= 0.0)
      return;

   if(stopDistance <= minStopDistance || takeProfitDistance <= minStopDistance)
   {
      Print("MRV EMA trade skipped because SL/TP distance is below broker stop level. StopDistance=", stopDistance,
            ", TakeProfitDistance=", takeProfitDistance, ", MinStopDistance=", minStopDistance);
      return;
   }

   if(context.atrValue <= 0.0 || stopDistance > context.atrValue * g_MaxStopLossATRMultiple)
   {
      Print("MRV EMA trade skipped because slow EMA stop distance exceeds ATR gate. StopDistance=", stopDistance,
            ", ATR=", context.atrValue, ", MaxATRMultiple=", g_MaxStopLossATRMultiple);
      return;
   }

   double takeProfit = context.tradeDirection > 0 ? entryPrice + takeProfitDistance : entryPrice - takeProfitDistance;
   stopLoss = NormalizeDouble(stopLoss, digits);
   takeProfit = NormalizeDouble(takeProfit, digits);

   double volume = CalculateRiskBasedVolume(context.tradeDirection, entryPrice, stopLoss);
   if(volume <= 0.0)
      return;

   string comment = context.tradeDirection > 0 ? "MRV EMA long" : "MRV EMA short";
   bool orderPlaced = context.tradeDirection > 0
      ? g_Trade.Buy(volume, _Symbol, 0.0, stopLoss, takeProfit, comment)
      : g_Trade.Sell(volume, _Symbol, 0.0, stopLoss, takeProfit, comment);

   if(!orderPlaced)
      Print("MRV EMA market order failed. Retcode=", g_Trade.ResultRetcode(), ", Description=", g_Trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
int GetTradeDirection(const TDTSSignalContext &context, const MqlTick &tick)
{
   if(!context.hasSquare)
      return 0;

   if(context.emaSeparationCandles < g_MinEMASeparationCandles)
      return 0;

   if(context.slowEMA <= 0.0 || context.fastEMA <= 0.0)
      return 0;

   if(tick.ask > context.fastEMA && context.fastEMA > context.slowEMA)
      return 1;

   if(tick.bid < context.fastEMA && context.fastEMA < context.slowEMA)
      return -1;

   return 0;
}

//+------------------------------------------------------------------+
double CalculateRiskBasedVolume(const int tradeDirection, const double entryPrice, const double stopLoss)
{
   double riskAmount = g_StartingBalance * (g_RiskPercentOfBalance / 100.0);
   double profitAtStopForOneLot = 0.0;
   ENUM_ORDER_TYPE orderType = tradeDirection > 0 ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   if(!OrderCalcProfit(orderType, _Symbol, 1.0, entryPrice, stopLoss, profitAtStopForOneLot))
   {
      Print("Failed to calculate one-lot stop-loss risk. Error: ", GetLastError());
      return 0.0;
   }

   double lossAtStopForOneLot = MathAbs(profitAtStopForOneLot);
   if(lossAtStopForOneLot <= 0.0)
   {
      Print("MRV EMA trade skipped because one-lot stop-loss risk is invalid: ", lossAtStopForOneLot);
      return 0.0;
   }

   double requestedVolume = riskAmount / lossAtStopForOneLot;
   return NormalizeRiskVolume(requestedVolume, riskAmount, lossAtStopForOneLot);
}

//+------------------------------------------------------------------+
double NormalizeRiskVolume(const double requestedVolume, const double riskAmount, const double lossAtStopForOneLot)
{
   double minVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxVolume = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double volumeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(volumeStep <= 0.0)
      return requestedVolume;

   double volume = MathMin(maxVolume, requestedVolume);
   volume = MathFloor(volume / volumeStep) * volumeStep;
   volume = MathMin(maxVolume, volume);

   if(volume < minVolume)
   {
      Print("MRV EMA trade skipped because risk-based volume is below symbol minimum. RequestedVolume=", requestedVolume,
            ", MinVolume=", minVolume, ", RiskAmount=", riskAmount, ", OneLotStopRisk=", lossAtStopForOneLot);
      return 0.0;
   }

   int volumeDigits = 0;
   double scaledStep = volumeStep;
   while(volumeDigits < 8 && MathAbs(scaledStep - MathRound(scaledStep)) > 0.00000001)
   {
      scaledStep *= 10.0;
      volumeDigits++;
   }

   return NormalizeDouble(volume, volumeDigits);
}

//+------------------------------------------------------------------+
void DeleteEAObjects()
{
   int totalObjects = ObjectsTotal(0, 0, -1);

   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, g_ObjectPrefix) == 0)
         ObjectDelete(0, name);
   }
}
