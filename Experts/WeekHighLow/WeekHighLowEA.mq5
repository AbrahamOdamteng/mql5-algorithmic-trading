//+------------------------------------------------------------------+
//|                                                  WeekHighLow.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.00"


#include <Trade/Trade.mqh>
#include <WeekHighLows/datatypes.mqh>
#include <WeekHighLows/cluster_logic.mqh>
#include <WeekHighLows/week_functions.mqh>
#include "EA_Utils.mqh"
#include "TradeLogger.mqh"

CTrade g_trade; 


input int     g_ATR_Period              = 14;
input int     g_MinClusterSize          = 2;
input double  g_ATR_Cluster_multiplier  = 0.1;

input int     g_impulse_lookback_hours      = 24;
input int     g_pullback_lookforward_hours  = 24;

input double  g_Impulse_ATR_multiplier  = 0.5;
input double  g_pullback_ATR_multiplier = 0.5;

input int     g_TakeProfitMultiplier    = 2;
input double  g_Risk_Percentage         = 1.0;



datetime      lastProcessedBarTime      = 0;

//int weekNumber = 0;
WeekData     g_weekData[];
WeekHighLow  g_weekHighs[];
WeekHighLow  g_weekLows[];
PriceCluster g_clusterHighs[];
PriceCluster g_clusterLows[];

RatesCircularBuffer *g_ImpulseBuffer = NULL;
RatesCircularBuffer *g_pullbackBuffer = NULL;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

    g_ImpulseBuffer = new RatesCircularBuffer(g_impulse_lookback_hours);
    g_pullbackBuffer = new RatesCircularBuffer(g_pullback_lookforward_hours);

    MqlRates rates[];
    int requestedBars = 70000;
    int loadedBars = CopyRates(_Symbol,_Period, 0,requestedBars,rates);
    if(loadedBars <= 0){
      Print("Failed to load history");
      return (INIT_FAILED);
    }

    Print("Requested bars: ", requestedBars);
    Print("Loaded bars: ", loadedBars);
    // Make array behave like indicator arrays
    ArraySetAsSeries(rates, true);

    for(int i = loadedBars-2; i >= 1; i--){
      MqlRates currentBar  = rates[i];
      MqlRates previousBar = rates[i + 1];

      g_ImpulseBuffer.Push(currentBar);
      g_pullbackBuffer.Push(currentBar);

      calculatePullbacks(g_weekData, currentBar, g_pullbackBuffer);
      detectWeeks(currentBar, previousBar,g_weekData, g_ATR_Period,g_ImpulseBuffer);
      detectWeekHighLows(currentBar,previousBar,g_weekData,g_weekHighs,g_weekLows);

      // detectCluster(currentBar,previousBar,g_weekData, g_weekHighs, g_clusterHighs, g_MinClusterSize , g_ATR_Cluster_multiplier);
      // detectCluster(currentBar,previousBar,g_weekData, g_weekLows, g_clusterLows, g_MinClusterSize , g_ATR_Cluster_multiplier);

      
      // detectImpulseSignal(currentBar,previousBar,g_weekData,g_weekHighs,g_clusterHighs,g_Impulse_ATR_multiplier);
      // detectImpulseSignal(currentBar,previousBar,g_weekData,g_weekLows,g_clusterLows,g_Impulse_ATR_multiplier);


      detectImpulseContinuationSignalV2(currentBar,previousBar,g_weekData,g_weekHighs,g_clusterHighs,g_Impulse_ATR_multiplier,g_pullback_ATR_multiplier, g_ATR_Cluster_multiplier);
      detectImpulseContinuationSignalV2(currentBar,previousBar,g_weekData,g_weekLows,g_clusterLows,g_Impulse_ATR_multiplier, g_pullback_ATR_multiplier, g_ATR_Cluster_multiplier);
    

    }

    lastProcessedBarTime = iTime(_Symbol,_Period,0);

    // DeleteTradeCsv();
    // OpenTradeCsv();
    return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
      if(g_ImpulseBuffer != NULL){
         delete g_ImpulseBuffer;
         g_ImpulseBuffer = NULL;
      }

      if(g_pullbackBuffer != NULL){
         delete g_pullbackBuffer;
         g_pullbackBuffer = NULL;
      }

      // CloseTradeCsv();
   
  }

// void OnTradeTransaction(
//    const MqlTradeTransaction& trans,
//    const MqlTradeRequest& request,
//    const MqlTradeResult& result
// ){
//   OnTradeTransactionHelper(trans,request,result);
// }



//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
    datetime currentBarTime = iTime(_Symbol,_Period,0);
    if(currentBarTime == lastProcessedBarTime){
      return;
    }

    lastProcessedBarTime = currentBarTime;

    MqlRates rates[];
    int loadedBars = CopyRates(_Symbol,_Period, 0,3,rates);
    if(loadedBars < 3){
       Print("Failed to load latest bars");
       return;
    }

    ArraySetAsSeries(rates,true);

    MqlRates currentBar  = rates[1];
    MqlRates previousBar = rates[2];

    
    g_ImpulseBuffer.Push(currentBar);
    g_pullbackBuffer.Push(currentBar);
    
    calculatePullbacks(g_weekData, currentBar, g_pullbackBuffer);
    detectWeeks(currentBar, previousBar,g_weekData, g_ATR_Period,g_ImpulseBuffer);
    detectWeekHighLows(currentBar,previousBar,g_weekData,g_weekHighs,g_weekLows);

    // bool highClusterDetected =  detectCluster(currentBar,previousBar,g_weekData, g_weekHighs, g_clusterHighs, g_MinClusterSize , g_ATR_Cluster_multiplier);
    // bool lowClusterDetected = detectCluster(currentBar,previousBar,g_weekData, g_weekLows, g_clusterLows, g_MinClusterSize , g_ATR_Cluster_multiplier);

    // bool highClusterDetected =  detectImpulseSignal(currentBar,previousBar,g_weekData,g_weekHighs,g_clusterHighs,g_Impulse_ATR_multiplier);
    // bool lowClusterDetected =  detectImpulseSignal(currentBar,previousBar,g_weekData,g_weekLows,g_clusterLows,g_Impulse_ATR_multiplier);


    bool highClusterDetected = detectImpulseContinuationSignalV2(currentBar,previousBar,g_weekData,g_weekHighs,g_clusterHighs,g_Impulse_ATR_multiplier,g_pullback_ATR_multiplier, g_ATR_Cluster_multiplier);
    bool lowClusterDetected  = detectImpulseContinuationSignalV2(currentBar,previousBar,g_weekData,g_weekLows,g_clusterLows,g_Impulse_ATR_multiplier, g_pullback_ATR_multiplier, g_ATR_Cluster_multiplier);


    if(highClusterDetected){
      Print("High Cluster Detected!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      PriceCluster last = GetLast(g_clusterHighs);
      WeekData lastWeek = GetSecondToLast(g_weekData);
      double clusterHeight = lastWeek.weeklyATR * g_ATR_Cluster_multiplier;
      PlacePendingOrder(last, g_weekData,g_trade, g_TakeProfitMultiplier, clusterHeight, g_Risk_Percentage);
    }

    if(lowClusterDetected){
      Print("Low Cluster Detected!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      PriceCluster last = GetLast(g_clusterLows);
      WeekData lastWeek = GetSecondToLast(g_weekData);
      double clusterHeight = lastWeek.weeklyATR * g_ATR_Cluster_multiplier;
      PlacePendingOrder(last,g_weekData, g_trade, g_TakeProfitMultiplier,clusterHeight, g_Risk_Percentage);
    }
   
  }
//+------------------------------------------------------------------+


