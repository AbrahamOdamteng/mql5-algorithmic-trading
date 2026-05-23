
#ifndef CLUSTER_LOGIC_MQH
#define CLUSTER_LOGIC_MQH   

//+------------------------------------------------------------------+
//|                                                datatypes.mgh.mqh |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
//+------------------------------------------------------------------+
//| defines                                                          |
//+------------------------------------------------------------------+
// #define MacrosHello   "Hello, world!"
// #define MacrosYear    2010
//+------------------------------------------------------------------+
//| DLL imports                                                      |
//+------------------------------------------------------------------+
// #import "user32.dll"
//   int      SendMessageA(int hWnd,int Msg,int wParam,int lParam);
// #import "my_expert.dll"
//   int      ExpertRecalculate(int wParam,int lParam);
// #import
//+------------------------------------------------------------------+
//| EX5 imports                                                      |
//+------------------------------------------------------------------+
// #import "stdlib.ex5"
//   string ErrorDescription(int error_code);
// #import
//+------------------------------------------------------------------+

#include "drawing_functions.mqh"
#include "utils.mqh"
// #include "datatypes.mqh"

bool IsWithinClusterRange(WeekHighLow &baseLevel, WeekHighLow &candidateLevel, double maxDistance)
{
   double priceDifference = MathAbs(baseLevel.price - candidateLevel.price);
   return priceDifference <= maxDistance;
}

void AppendWeekLevel(WeekHighLow &levels[], WeekHighLow &newLevel)
{
   int currentSize = ArraySize(levels);
   ArrayResize(levels, currentSize + 1);
   levels[currentSize] = newLevel;
}

bool doesPriceBreakCluster(WeekHighLow &baseLevel, WeekHighLow &candidateLevel, double clusterSize){

   if(baseLevel.lineType == WEEK_HIGH ){
      return candidateLevel.price > (baseLevel.price + clusterSize) ;
   }else{
      return candidateLevel.price < (baseLevel.price - clusterSize) ;
   }
}

bool detectCluster(MqlRates &currentBar, MqlRates &previouseBar, WeekData  &myWeekData[], WeekHighLow &myWeekHighLow[],  PriceCluster &priceClusterArray[], int minClusterSize, double atrClusterMultiplier){

   int arraySize         = ArraySize(myWeekData);
   int arraySizeHL       = ArraySize(myWeekHighLow);
   bool isStartOfNewWeek = isNewWeek(currentBar.time, previouseBar.time);
   if(!isStartOfNewWeek || arraySize == 0 || arraySizeHL == 0){
      return false;
   }

   if(MathAbs(arraySize - arraySizeHL) > 1){
      Print("detectCluster => ERORR!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      return false;
   }

   int lastIndex               = arraySize - 1;
   int indexOfLastFinishedWeek = lastIndex - 1;
   WeekData lastweek           = myWeekData[indexOfLastFinishedWeek];
   double clusterSize          = lastweek.weeklyATR * atrClusterMultiplier;

   Print("arraySize   = ", IntegerToString(arraySize));
   Print("indexOfLastFinishedWeek   = ", IntegerToString(indexOfLastFinishedWeek));
   Print("arraySizeHL = ", IntegerToString(arraySizeHL));

   WeekHighLow basePriceLevel = myWeekHighLow[indexOfLastFinishedWeek];
   WeekHighLow priceCluster[];

   AppendWeekLevel(priceCluster,basePriceLevel);

   for(int i = indexOfLastFinishedWeek -1; i >= 0; i--){
      WeekHighLow weekHigh = myWeekHighLow[i];
      if(doesPriceBreakCluster(basePriceLevel, weekHigh, clusterSize)){
         break;
      }
      if(IsWithinClusterRange(basePriceLevel, weekHigh, clusterSize)){
         AppendWeekLevel(priceCluster,weekHigh);
      }
   }

   int sizeOfCluster = ArraySize(priceCluster);

   if(sizeOfCluster >= minClusterSize){
      PriceCluster detectedCluster =  CreatePriceCluster(basePriceLevel.lineType,basePriceLevel,priceCluster);

      DrawClusterArrow(currentBar, detectedCluster);
      Append(priceClusterArray, detectedCluster);
      return true;
   }
   return false;

}



bool detectImpulseSignal(
   MqlRates &currentBar,
   MqlRates &previouseBar,
   WeekData &myWeekData[],
   WeekHighLow &myWeekHighLow[],
   PriceCluster &priceClusterArray[],
   double impulseATRMultiplier
){
   int arraySize         = ArraySize(myWeekData);
   int arraySizeHL       = ArraySize(myWeekHighLow);
   bool isStartOfNewWeek = isNewWeek(currentBar.time, previouseBar.time);

   if(!isStartOfNewWeek || arraySize == 0 || arraySizeHL == 0){
      return false;
   }

   if(MathAbs(arraySize - arraySizeHL) > 1){
      Print("detectImpulseSignal => ERROR: WeekData and WeekHighLow arrays are out of sync");
      return false;
   }

   int lastIndex               = arraySize - 1;
   int indexOfLastFinishedWeek = lastIndex - 1;

   if(indexOfLastFinishedWeek < 0){
      return false;
   }

   WeekData lastWeek = myWeekData[indexOfLastFinishedWeek];
   WeekHighLow basePriceLevel = myWeekHighLow[indexOfLastFinishedWeek];

   double requiredImpulse = lastWeek.weeklyATR * impulseATRMultiplier;
   double actualImpulse   = 0.0;

   if(basePriceLevel.lineType == WEEK_HIGH){
      actualImpulse = lastWeek.highImpulse;
   }
   else if(basePriceLevel.lineType == WEEK_LOW){
      actualImpulse = lastWeek.lowImpulse;
   }
   else{
      return false;
   }

   if(actualImpulse >= requiredImpulse){
      WeekHighLow priceCluster[];
      AppendWeekLevel(priceCluster, basePriceLevel);

      PriceCluster detectedCluster = CreatePriceCluster(
         basePriceLevel.lineType,
         basePriceLevel,
         priceCluster
      );

      DrawClusterArrow(currentBar, detectedCluster);
      Append(priceClusterArray, detectedCluster);

      return true;
   }

   return false;
}



bool detectImpulseContinuationSignalV1(
   MqlRates &currentBar,
   MqlRates &previouseBar,
   WeekData &myWeekData[],
   WeekHighLow &myWeekHighLow[],
   PriceCluster &priceClusterArray[],
   double impulseATRMultiplier,
   double pullbackATRMultiplier,
   double atrClustermultiplier
){
   int arraySize         = ArraySize(myWeekData);
   int arraySizeHL       = ArraySize(myWeekHighLow);
   bool isStartOfNewWeek = isNewWeek(currentBar.time, previouseBar.time);

   //!isStartOfNewWeek || 
   if(arraySize == 0 || arraySizeHL == 0){
      return false;
   }

   if(MathAbs(arraySize - arraySizeHL) > 1){
      Print("detectImpulseContinuationSignal => ERROR: WeekData and WeekHighLow arrays are out of sync");
      return false;
   }

   int lastIndex               = arraySize - 1;
   int indexOfLastFinishedWeek = lastIndex - 1;

   if(indexOfLastFinishedWeek < 0){
      return false;
   }

   WeekData lastWeek          = myWeekData[indexOfLastFinishedWeek];
   WeekHighLow basePriceLevel = myWeekHighLow[indexOfLastFinishedWeek];

   double requiredImpulse  = lastWeek.weeklyATR * impulseATRMultiplier;
   double allowedPullback  = lastWeek.weeklyATR * pullbackATRMultiplier;

   double actualImpulse    = 0.0;
   double actualPullback   = 0.0;

   if(basePriceLevel.lineType == WEEK_HIGH && lastWeek.highPullback > -1 && 
      (isStartOfNewWeek || lastWeek.highPullbackCalculatedTime == currentBar.time))
   {
      actualImpulse  = lastWeek.highImpulse;
      actualPullback = lastWeek.highPullback;
   }
   else if(basePriceLevel.lineType == WEEK_LOW && lastWeek.lowPullback > -1 &&
      (isStartOfNewWeek  || lastWeek.lowPullbackCalculatedTime == currentBar.time))
   {
      actualImpulse  = lastWeek.lowImpulse;
      actualPullback = lastWeek.lowPullback;
   }
   else
   {
      return false;
   }

   bool validSignal =
      actualImpulse >= requiredImpulse &&
      actualPullback <= allowedPullback;

   if(validSignal)
   {
      WeekHighLow priceCluster[];
      AppendWeekLevel(priceCluster, basePriceLevel);

      PriceCluster detectedCluster = CreatePriceCluster(
         basePriceLevel.lineType,
         basePriceLevel,
         priceCluster
      );

      DrawClusterArrow(currentBar, detectedCluster);
      Append(priceClusterArray, detectedCluster);

      return true;
   }

   return false;
}






bool helper(   
   WeekData &myWeekData,
   WeekHighLow &myWeekHighLow,
   double impulseATRMultiplier,
   double pullbackATRMultiplier
){
   
   double requiredImpulse  = myWeekData.weeklyATR * impulseATRMultiplier;
   double allowedPullback  = myWeekData.weeklyATR * pullbackATRMultiplier;

   double actualImpulse    = 0.0;
   double actualPullback   = 0.0;

   if(myWeekHighLow.lineType == WEEK_HIGH && myWeekData.highPullback > -1 )
   {
      actualImpulse  = myWeekData.highImpulse;
      actualPullback = myWeekData.highPullback;
   }
   else if(myWeekHighLow.lineType == WEEK_LOW && myWeekData.lowPullback > -1)
   {
      actualImpulse  = myWeekData.lowImpulse;
      actualPullback = myWeekData.lowPullback;
   }
   else
   {
      return false;
   }

   bool validSignal =
      actualImpulse  >= requiredImpulse &&
      actualPullback >= allowedPullback;

      return validSignal;
}



bool detectImpulseContinuationSignalV2(
   MqlRates &currentBar,
   MqlRates &previouseBar,
   WeekData &myWeekData[],
   WeekHighLow &myWeekHighLow[],
   PriceCluster &priceClusterArray[],
   double impulseATRMultiplier,
   double pullbackATRMultiplier,
   double atrClusterMultiplier
){
   int arraySize         = ArraySize(myWeekData);
   int arraySizeHL       = ArraySize(myWeekHighLow);
   bool isStartOfNewWeek = isNewWeek(currentBar.time, previouseBar.time);


   //!isStartOfNewWeek || 
   if(arraySize == 0 || arraySizeHL == 0){
      return false;
   }

   if(MathAbs(arraySize - arraySizeHL) > 1){
      Print("detectImpulseContinuationSignal => ERROR: WeekData and WeekHighLow arrays are out of sync");
      return false;
   }

   int lastIndex               = arraySize - 1;
   int indexOfLastFinishedWeek = lastIndex - 1;

   if(indexOfLastFinishedWeek < 0){
      return false;
   }

   WeekData lastWeek          = myWeekData[indexOfLastFinishedWeek];
   WeekHighLow basePriceLevel = myWeekHighLow[indexOfLastFinishedWeek];

   double requiredImpulse  = lastWeek.weeklyATR * impulseATRMultiplier;
   double allowedPullback  = lastWeek.weeklyATR * pullbackATRMultiplier;
   double clusterSize      = lastWeek.weeklyATR * atrClusterMultiplier;

   double actualImpulse    = 0.0;
   double actualPullback   = 0.0;
   bool validSignal = false;

   if(basePriceLevel.lineType == WEEK_HIGH  && 
      (isStartOfNewWeek || lastWeek.highPullbackCalculatedTime == currentBar.time))
   {
      validSignal = helper(lastWeek,basePriceLevel,impulseATRMultiplier,pullbackATRMultiplier);
   }
   else if(basePriceLevel.lineType == WEEK_LOW && lastWeek.lowPullback > -1 &&
      (isStartOfNewWeek  || lastWeek.lowPullbackCalculatedTime == currentBar.time))
   {
      validSignal = helper(lastWeek,basePriceLevel,impulseATRMultiplier,pullbackATRMultiplier);
   }
   else
   {
      return false;
   }


   if(!validSignal){
      return false;
   }

   WeekHighLow priceCluster[];
   Append(priceCluster,basePriceLevel );

   for (int i = indexOfLastFinishedWeek; i >= 0; i--)
   {
      WeekData wd = myWeekData[i];
      WeekHighLow whl = myWeekHighLow[i];
      if(wd.weekNumber >= lastWeek.weekNumber){
         continue;
      }


      if(doesPriceBreakCluster(basePriceLevel, whl, clusterSize)){
         break;
      }

      bool isWithinRange = IsWithinClusterRange(basePriceLevel, whl, clusterSize);
      bool valid = helper(wd,whl,impulseATRMultiplier,pullbackATRMultiplier);

      if(valid && isWithinRange){
            Append(priceCluster,whl );
      }
   }


   PriceCluster detectedCluster = CreatePriceCluster(
      basePriceLevel.lineType,
      basePriceLevel,
      priceCluster
   );

   DrawClusterArrow(currentBar, detectedCluster);
   Append(priceClusterArray, detectedCluster);

   return true;

}



#endif