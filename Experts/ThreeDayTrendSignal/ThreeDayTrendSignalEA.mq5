//+------------------------------------------------------------------+
//|                                        ThreeDayTrendSignalEA.mq5 |
//| Draws chart markers for the 3 Day Trend Signal research strategy. |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      ""
#property version   "1.00"
#property strict

#include <Trade/Trade.mqh>

input int    g_ATR_Period          = 14;
input double g_ATR_Multiplier      = 5.0;
input int    g_ContiguousCandles   = 2;
input int    g_HistoryBarsToScan   = 2000;
input int    g_MarkerSize          = 1;
input bool   g_DeleteObjectsOnInit = true;
input bool   g_EnableTrading       = true;
input double g_StartingBalance     = 100000.0;
input double g_RiskPercentOfBalance = 1.0;
input double g_StopLossATRMultiple = 1.0;
input double g_TakeProfitSLMultiple = 2.0;
input ulong  g_MagicNumber         = 3001001;
input int    g_DeviationPoints     = 20;

const double GAP_ATR_SKIP_FRACTION = 0.1;

string   g_ObjectPrefix       = "TDTS_Momentum_";
int      g_ATR_Handle         = INVALID_HANDLE;
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

   if(g_ATR_Multiplier <= 0.0)
   {
      Print("g_ATR_Multiplier must be greater than 0");
      return INIT_PARAMETERS_INCORRECT;
   }

   if(g_ContiguousCandles < 1)
   {
      Print("g_ContiguousCandles must be at least 1");
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

      if(g_StopLossATRMultiple <= 0.0)
      {
         Print("g_StopLossATRMultiple must be greater than 0 when trading is enabled");
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

   g_Trade.SetExpertMagicNumber(g_MagicNumber);
   g_Trade.SetDeviationInPoints(g_DeviationPoints);
   g_Trade.SetTypeFillingBySymbol(_Symbol);

   if(g_DeleteObjectsOnInit)
      DeleteMomentumObjects();

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
   bool bullishMomentum = false;
   double atrValue = 0.0;

   if(DrawMomentumMarkerForShift(1, bullishMomentum, atrValue) && g_EnableTrading)
      ExecuteMarketOrder(bullishMomentum, atrValue);
}

//+------------------------------------------------------------------+
void DrawHistoricalMomentumMarkers()
{
   int availableBars = Bars(_Symbol, _Period);
   if(availableBars <= g_ContiguousCandles)
      return;

   int barsToCopy = MathMin(availableBars, MathMax(g_HistoryBarsToScan, g_ATR_Period + g_ContiguousCandles + 10));

   MqlRates rates[];
   double atrValues[];

   int copiedRates = CopyRates(_Symbol, _Period, 0, barsToCopy, rates);
   int copiedAtr = CopyBuffer(g_ATR_Handle, 0, 0, barsToCopy, atrValues);

   if(copiedRates <= g_ContiguousCandles || copiedAtr <= g_ContiguousCandles)
   {
      Print("Not enough history to draw momentum markers");
      return;
   }

   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(atrValues, true);

   int usableBars = MathMin(copiedRates, copiedAtr);
   int oldestUsableShift = usableBars - g_ContiguousCandles;

   for(int shift = oldestUsableShift; shift >= 1; shift--)
   {
      bool bullishMomentum = false;
      double atrValue = 0.0;
      DrawMomentumMarker(rates, atrValues, shift, bullishMomentum, atrValue);
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
bool DrawMomentumMarkerForShift(const int shift, bool &bullishMomentum, double &atrValue)
{
   MqlRates rates[];
   double atrValues[];
   int barsNeeded = shift + g_ContiguousCandles;

   int copiedRates = CopyRates(_Symbol, _Period, 0, barsNeeded, rates);
   int copiedAtr = CopyBuffer(g_ATR_Handle, 0, 0, shift + 1, atrValues);

   if(copiedRates < barsNeeded || copiedAtr <= shift)
      return false;

   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(atrValues, true);

   bool markerDrawn = DrawMomentumMarker(rates, atrValues, shift, bullishMomentum, atrValue);
   ChartRedraw(0);
   return markerDrawn;
}

//+------------------------------------------------------------------+
bool DrawMomentumMarker(MqlRates &rates[], double &atrValues[], const int shift, bool &bullishMomentum, double &signalAtrValue)
{
   int oldestRequestedShift = shift + g_ContiguousCandles - 1;
   int blockOpenShift = shift;
   double atrValue = atrValues[shift];

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

   if(contiguousRange < atrValue * g_ATR_Multiplier)
      return false;

   bullishMomentum = (blockClose >= blockOpen);
   signalAtrValue = atrValue;
   return DrawMomentumCircle(rates[shift], atrValue, bullishMomentum);
}

//+------------------------------------------------------------------+
bool DrawMomentumCircle(const MqlRates &bar, const double atrValue, const bool bullishMomentum)
{
   string direction = bullishMomentum ? "Bull_" : "Bear_";
   string name = g_ObjectPrefix + direction + _Symbol + "_" + IntegerToString((int)_Period) + "_" + IntegerToString((int)bar.time);

   if(ObjectFind(0, name) >= 0)
      return false;

   double fallbackOffset = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;
   double markerOffset = MathMax(atrValue * 0.15, fallbackOffset);
   double markerPrice = bullishMomentum ? bar.high + markerOffset : bar.low - markerOffset;

   if(!ObjectCreate(0, name, OBJ_ARROW, 0, bar.time, markerPrice))
   {
      Print("Failed to create momentum marker ", name, ". Error: ", GetLastError());
      return false;
   }

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
   ObjectSetInteger(0, name, OBJPROP_COLOR, bullishMomentum ? clrBlue : clrRed);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, g_MarkerSize);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, bullishMomentum ? ANCHOR_BOTTOM : ANCHOR_TOP);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   return true;
}

//+------------------------------------------------------------------+
void ExecuteMarketOrder(const bool bullishMomentum, const double atrValue)
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick))
   {
      Print("Failed to get symbol tick. Error: ", GetLastError());
      return;
   }

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   int stopsLevelPoints = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   double minStopDistance = stopsLevelPoints * point;
   double stopDistance = atrValue * g_StopLossATRMultiple;
   double takeProfitDistance = stopDistance * g_TakeProfitSLMultiple;

   if(stopDistance <= minStopDistance || takeProfitDistance <= minStopDistance)
   {
      Print("Momentum trade skipped because SL/TP distance is below broker stop level. StopDistance=", stopDistance,
            ", TakeProfitDistance=", takeProfitDistance, ", MinStopDistance=", minStopDistance);
      return;
   }

   double entryPrice = bullishMomentum ? tick.ask : tick.bid;
   double stopLoss = bullishMomentum ? entryPrice - stopDistance : entryPrice + stopDistance;
   double takeProfit = bullishMomentum ? entryPrice + takeProfitDistance : entryPrice - takeProfitDistance;

   stopLoss = NormalizeDouble(stopLoss, digits);
   takeProfit = NormalizeDouble(takeProfit, digits);

   double volume = CalculateRiskBasedVolume(bullishMomentum, entryPrice, stopLoss);
   if(volume <= 0.0)
      return;

   string comment = bullishMomentum ? "TDTS bullish momentum" : "TDTS bearish momentum";
   bool orderPlaced = bullishMomentum
      ? g_Trade.Buy(volume, _Symbol, 0.0, stopLoss, takeProfit, comment)
      : g_Trade.Sell(volume, _Symbol, 0.0, stopLoss, takeProfit, comment);

   if(!orderPlaced)
      Print("Momentum market order failed. Retcode=", g_Trade.ResultRetcode(), ", Description=", g_Trade.ResultRetcodeDescription());
}

//+------------------------------------------------------------------+
double CalculateRiskBasedVolume(const bool bullishMomentum, const double entryPrice, const double stopLoss)
{
   double riskAmount = g_StartingBalance * (g_RiskPercentOfBalance / 100.0);
   double profitAtStopForOneLot = 0.0;
   ENUM_ORDER_TYPE orderType = bullishMomentum ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;

   if(!OrderCalcProfit(orderType, _Symbol, 1.0, entryPrice, stopLoss, profitAtStopForOneLot))
   {
      Print("Failed to calculate one-lot stop-loss risk. Error: ", GetLastError());
      return 0.0;
   }

   double lossAtStopForOneLot = MathAbs(profitAtStopForOneLot);
   if(lossAtStopForOneLot <= 0.0)
   {
      Print("Momentum trade skipped because one-lot stop-loss risk is invalid: ", lossAtStopForOneLot);
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
      Print("Momentum trade skipped because risk-based volume is below symbol minimum. RequestedVolume=", requestedVolume,
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
void DeleteMomentumObjects()
{
   int totalObjects = ObjectsTotal(0, 0, -1);

   for(int i = totalObjects - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, g_ObjectPrefix) == 0)
         ObjectDelete(0, name);
   }
}
