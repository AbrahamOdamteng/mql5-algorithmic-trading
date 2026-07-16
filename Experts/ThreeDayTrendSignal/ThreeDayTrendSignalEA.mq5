//+------------------------------------------------------------------+
//|                                        ThreeDayTrendSignalEA.mq5 |
//| Draws chart markers for the 3 Day Trend Signal research strategy. |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026"
#property link      ""
#property version   "1.00"
#property strict

input int    g_ATR_Period          = 14;
input double g_ATR_Multiplier      = 5.0;
input int    g_ContiguousCandles   = 2;
input int    g_HistoryBarsToScan   = 2000;
input int    g_MarkerSize          = 1;
input bool   g_DeleteObjectsOnInit = true;

const double GAP_ATR_SKIP_FRACTION = 0.1;

string   g_ObjectPrefix       = "TDTS_Momentum_";
int      g_ATR_Handle         = INVALID_HANDLE;
datetime g_LastChartBarTime   = 0;

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

   g_ATR_Handle = iATR(_Symbol, _Period, g_ATR_Period);
   if(g_ATR_Handle == INVALID_HANDLE)
   {
      Print("Failed to create ATR handle. Error: ", GetLastError());
      return INIT_FAILED;
   }

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
   DrawMomentumMarkerForShift(1);
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
      DrawMomentumMarker(rates, atrValues, shift);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void DrawMomentumMarkerForShift(const int shift)
{
   MqlRates rates[];
   double atrValues[];
   int barsNeeded = shift + g_ContiguousCandles;

   int copiedRates = CopyRates(_Symbol, _Period, 0, barsNeeded, rates);
   int copiedAtr = CopyBuffer(g_ATR_Handle, 0, 0, shift + 1, atrValues);

   if(copiedRates < barsNeeded || copiedAtr <= shift)
      return;

   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(atrValues, true);

   DrawMomentumMarker(rates, atrValues, shift);
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
void DrawMomentumMarker(MqlRates &rates[], double &atrValues[], const int shift)
{
   int oldestRequestedShift = shift + g_ContiguousCandles - 1;
   int blockOpenShift = shift;
   double atrValue = atrValues[shift];

   if(atrValue <= 0.0 || oldestRequestedShift >= ArraySize(rates))
      return;

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
      return;

   bool bullishMomentum = (blockClose >= blockOpen);
   DrawMomentumCircle(rates[shift], atrValue, bullishMomentum);
}

//+------------------------------------------------------------------+
void DrawMomentumCircle(const MqlRates &bar, const double atrValue, const bool bullishMomentum)
{
   string direction = bullishMomentum ? "Bull_" : "Bear_";
   string name = g_ObjectPrefix + direction + _Symbol + "_" + IntegerToString((int)_Period) + "_" + IntegerToString((int)bar.time);

   if(ObjectFind(0, name) >= 0)
      return;

   double fallbackOffset = SymbolInfoDouble(_Symbol, SYMBOL_POINT) * 10.0;
   double markerOffset = MathMax(atrValue * 0.15, fallbackOffset);
   double markerPrice = bullishMomentum ? bar.high + markerOffset : bar.low - markerOffset;

   if(!ObjectCreate(0, name, OBJ_ARROW, 0, bar.time, markerPrice))
   {
      Print("Failed to create momentum marker ", name, ". Error: ", GetLastError());
      return;
   }

   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, 159);
   ObjectSetInteger(0, name, OBJPROP_COLOR, bullishMomentum ? clrBlue : clrRed);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, g_MarkerSize);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, bullishMomentum ? ANCHOR_BOTTOM : ANCHOR_TOP);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
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
