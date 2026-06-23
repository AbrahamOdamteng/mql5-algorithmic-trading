//+------------------------------------------------------------------+
//|                                             MyFirstIndicator.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
#property indicator_chart_window

input ENUM_TIMEFRAMES g_HighLowPeriod = PERIOD_D1;
input int g_HighLowPeriodOptimizationIndex = -1;

ENUM_TIMEFRAMES g_ActiveHighLowPeriod = PERIOD_D1;

#include <WeekHighLows/datatypes.mqh>
#include <WeekHighLows/cluster_logic.mqh>
#include <WeekHighLows/week_functions.mqh>
#include <WeekHighLows/rates_circular_buffer.mqh>



input int    g_ATR_Period = 14;
input int    g_MinClusterSize = 2;
input double g_ATR_Cluster_multiplier = 0.1;

input int    g_impulse_lookback_hours = 24;
input double g_Impulse_ATR_multiplier = 0.5;


//int weekNumber = 0;
WeekData     g_weekData[];
WeekHighLow  g_weekHighs[];
WeekHighLow  g_weekLows[];
PriceCluster g_clusterHighs[];
PriceCluster g_clusterLows[];

RatesCircularBuffer *g_ImpulseBuffer = NULL;
RatesCircularBuffer *g_pullbackBuffer = NULL;


//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- indicator buffers mapping
          Print("OnInit Doing Work");

   g_ActiveHighLowPeriod = ResolveHighLowPeriod(g_HighLowPeriodOptimizationIndex, g_HighLowPeriod);
   Print("Active high/low period: ", HighLowPeriodToString(g_ActiveHighLowPeriod),
         " selector=", IntegerToString(g_HighLowPeriodOptimizationIndex));

   g_ImpulseBuffer = new RatesCircularBuffer(g_impulse_lookback_hours);
   g_pullbackBuffer = new RatesCircularBuffer(g_impulse_lookback_hours);
   
   //---
   return (INIT_SUCCEEDED);
}


void OnDeinit(const int reason)
{

      if(g_ImpulseBuffer != NULL){
         delete g_ImpulseBuffer;
         g_ImpulseBuffer = NULL;
      }

      if(g_pullbackBuffer != NULL){
         delete g_pullbackBuffer;
         g_pullbackBuffer = NULL;
      }

}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
//+------------------------------------------------------------------+
int OnCalculate(const int32_t rates_total,
                const int32_t prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int32_t &spread[])
{
   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);
   
   static datetime lastBarTime = 0;

   bool firstRun          =  prev_calculated == 0;
   bool moreHistoryLoaded = rates_total > prev_calculated + 1;
   bool fullRecalculation = firstRun || moreHistoryLoaded;

   int startIndex = 0;

   if (fullRecalculation)
   {
      Print("Rebuilding all data rates_total=", IntegerToString(rates_total));

      ArrayResize(g_weekData, 0);
      ArrayResize(g_weekHighs, 0);
      ArrayResize(g_weekLows, 0);

      ObjectsDeleteAll(0, 0, -1);

      lastBarTime = 0;
      // weekNumber = 0;
      startIndex = rates_total - 2;
   }else if(time[0] == lastBarTime){
      /*
      time[0] is the open time of current candle This only changes when a new bar forms.
      (time[0] == lastBarTime) means “We are still on the same candle → do nothing”
      */
      //Print("Nothing to do still on same bar");
      return (rates_total);
   }else if (rates_total == (prev_calculated + 1)){
      startIndex = 0;
   }

   lastBarTime = time[0];

   for (int i = startIndex; i >= 0; i--)
   {
      MqlRates currentBar;
      currentBar.time  = time[i];
      currentBar.open  = open[i];
      currentBar.high  = high[i];
      currentBar.low   = low[i];
      currentBar.close = close[i];

      MqlRates previousBar;
      previousBar.time  = time[i+1];
      previousBar.open  = open[i+1];
      previousBar.high  = high[i+1];
      previousBar.low   = low[i+1];
      previousBar.close = close[i+1];

      g_ImpulseBuffer.Push(currentBar);
      g_pullbackBuffer.Push(currentBar);

      calculatePullbacks(g_weekData, currentBar, g_pullbackBuffer);
      detectWeeks(currentBar, previousBar,g_weekData, g_ATR_Period, g_ImpulseBuffer);
      detectWeekHighLows(currentBar,previousBar,g_weekData,g_weekHighs,g_weekLows);

      // detectCluster(currentBar,previousBar,g_weekData, g_weekHighs, g_clusterHighs, g_MinClusterSize , g_ATR_Cluster_multiplier);
      // detectCluster(currentBar,previousBar,g_weekData, g_weekLows, g_clusterLows, g_MinClusterSize , g_ATR_Cluster_multiplier);

      detectImpulseSignal(currentBar,previousBar,g_weekData,g_weekHighs,g_clusterHighs,g_Impulse_ATR_multiplier);
      detectImpulseSignal(currentBar,previousBar,g_weekData,g_weekLows,g_clusterLows,g_Impulse_ATR_multiplier);

   }
// 100 -(99 + 1)
   return (rates_total);
   
}
//+------------------------------------------------------------------+
