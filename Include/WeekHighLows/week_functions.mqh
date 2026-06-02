#ifndef WEEK_FUNCTIONS_MQH
#define WEEK_FUNCTIONS_MQH

#include "utils.mqh"
#include "datatypes.mqh"
#include "drawing_functions.mqh"
#include  "rates_circular_buffer.mqh"

void createNewWeekData(WeekData &weeks[], MqlRates &currentBar, RatesCircularBuffer &lookbackBuffer)
{
   int currentArraySize = ArraySize(weeks);

   WeekData currentWeek;

   ZeroMemory(currentWeek);

   currentWeek.weekNumber  = currentArraySize;

   currentWeek.startOfWeek = currentBar.time;

   currentWeek.open        = currentBar.open;
   currentWeek.high        = currentBar.high;
   currentWeek.low         = currentBar.low;
   currentWeek.close       = currentBar.close;

   currentWeek.highTime    = currentBar.time;
   currentWeek.lowTime     = currentBar.time;

   currentWeek.weeklyATR   = -1;

   currentWeek.highImpulse = lookbackBuffer.HighImpulse();
   currentWeek.lowImpulse  = lookbackBuffer.LowImpulse();

   currentWeek.highPullback = -1;
   currentWeek.lowPullback  = -1;

   currentWeek.highPullbackCalculatedTime = 0;
   currentWeek.lowPullbackCalculatedTime  = 0;

   Append(weeks, currentWeek);
}



bool isNewWeek(datetime currentTime, datetime prevTime)
{
   if (currentTime < prevTime)
   {
      return false;
   }

   MqlDateTime current, previous;

   TimeToStruct(currentTime, current);
   TimeToStruct(prevTime, previous);

   if (current.day_of_week < previous.day_of_week)
   {
      return true;
   }

   return false;
}


datetime GetPeriodStart(datetime time, ENUM_TIMEFRAMES tf)
{
   int shift = iBarShift(_Symbol, tf, time, false);

   if(shift < 0)
      return 0;

   return iTime(_Symbol, tf, shift);
}



bool IsNewPeriod(
   datetime currentTime,
   datetime prevTime,
   ENUM_TIMEFRAMES tf
)
{
   datetime currentPeriod =
      GetPeriodStart(currentTime, tf);

   datetime previousPeriod =
      GetPeriodStart(prevTime, tf);

   if(currentPeriod == 0 || previousPeriod == 0)
      return false;

   return currentPeriod != previousPeriod;
}


void updateCurrentProperties(WeekData &weeks[], MqlRates &currentBar, RatesCircularBuffer &impulseBuffer)
{

   if (ArraySize(weeks) == 0)
   {
      return;
   }

   int lastPosition = ArraySize(weeks) - 1;
   WeekData currentWeek = weeks[lastPosition];

   if (currentBar.high > currentWeek.high)
   {
      currentWeek.high        = currentBar.high;
      currentWeek.highImpulse = impulseBuffer.HighImpulse();
      currentWeek.highTime    = currentBar.time;
      currentWeek.highPullback = -1;
      currentWeek.highPullbackCalculatedTime = 0;
   }

   if (currentBar.low < currentWeek.low)
   {
      currentWeek.low         = currentBar.low;
      currentWeek.lowImpulse  = impulseBuffer.LowImpulse();
      currentWeek.lowTime     = currentBar.time;
      currentWeek.lowPullback = -1;
      currentWeek.lowPullbackCalculatedTime = 0;
   }
   currentWeek.close = currentBar.close;
   
   weeks[lastPosition] = currentWeek;
}


void calculateWeeklyATR(WeekData &weeks[], int period, MqlRates &currentBar)
{
   int size = ArraySize(weeks);

   if (size < period + 1) // need prev close
   {
      Print("Not enough data for ATR(", period, ")", " Current DateTime ", currentBar.time);
      return;
   }

   double sumTR = 0.0;

   for (int i = size - period; i < size; i++)
   {
      double high = weeks[i].high;
      double low = weeks[i].low;
      double prevClose = weeks[i - 1].close;

      double tr1 = high - low;
      double tr2 = MathAbs(high - prevClose);
      double tr3 = MathAbs(low - prevClose);

      double tr = MathMax(tr1, MathMax(tr2, tr3));

      sumTR += tr;
   }

   double atr = sumTR / period;
   WeekData wd = weeks[size -1];
   wd.weeklyATR = atr;
   weeks[size - 1] = wd;

   // Print("Weekly ATR(", period, ") = ", atr, " Current DateTime ", currentBar.time, " weekNumber: ", wd.weekNumber);
}


void detectWeeks( MqlRates &currentBar, MqlRates &previouseBar,WeekData &weeks[], int atrPeriod, RatesCircularBuffer &impulseBuffer){

   // bool isStartOfNewWeek = isNewWeek(currentBar.time, previouseBar.time);
   bool isStartOfNewWeek = IsNewPeriod(currentBar.time, previouseBar.time,PERIOD_D1);
   if (isStartOfNewWeek){
      DrawCurrentBarLine(currentBar.time);
      calculateWeeklyATR(weeks, atrPeriod, currentBar);
      createNewWeekData(weeks, currentBar, impulseBuffer);

      // WeekData lastWeek = GetSecondToLast(weeks);
      // Print(WeekDataToString(lastWeek));

   }else{
      updateCurrentProperties(weeks,currentBar, impulseBuffer);
   }
}



void detectWeekHighLows(  MqlRates &currentBar, MqlRates &previouseBar , WeekData &weeks[], WeekHighLow &weekHighs[], WeekHighLow &weekLows[]){
   // bool isStartOfNewWeek = isNewWeek(currentBar.time, previouseBar.time);
   bool isStartOfNewWeek = IsNewPeriod(currentBar.time, previouseBar.time,PERIOD_D1);
   int weekSize          = ArraySize(weeks);
   int weekHighSize      = ArraySize(weekHighs);
   int weekLowSize       = ArraySize(weekLows);

   if(isStartOfNewWeek && (weekSize > 0) && (weekSize == weekHighSize + 2) && (weekSize == weekLowSize + 2)){
      int lastPosition         = weekSize - 1;
      int finishedWeekPosition = lastPosition - 1;
      WeekData finishedWeek    = weeks[finishedWeekPosition];

      WeekHighLow weekHigh = CreateWeekHighLow(
         WEEK_HIGH,
         "Week_"+ IntegerToString(finishedWeek.weekNumber) + "_High",
         finishedWeek.startOfWeek,
         finishedWeek.high,
         true,
         finishedWeek.weekNumber,
         0.0 );

      WeekHighLow weekLow = CreateWeekHighLow(
         WEEK_LOW, 
         "Week_"+ IntegerToString(finishedWeek.weekNumber) + "_Low",
         finishedWeek.startOfWeek,
         finishedWeek.low,
         true,
         finishedWeek.weekNumber,
         0.0 );

      // Print(WeekHighLowToString(weekHigh));

      Append(weekHighs, weekHigh);   
      Append(weekLows, weekLow) ;  

      DrawWeekHighLowLine(currentBar.time, weekHigh, clrBlue);
      DrawWeekHighLowLine(currentBar.time, weekLow, clrRed);
   }else{
      UpdateWeekHighLines(currentBar.close,currentBar.time,weekHighs,WEEK_HIGH);
      UpdateWeekHighLines(currentBar.close,currentBar.time,weekLows,WEEK_LOW);
   }
}



void calculatePullbacks(WeekData &weeks[], MqlRates &currentBar, RatesCircularBuffer &pullbackBuffer)
{
   int size = ArraySize(weeks);

   if(size == 0)
      return ;

   datetime targetTime = currentBar.time - (g_impulse_lookback_hours * 60 * 60);
   datetime oldest_time = pullbackBuffer.Oldest().time;


   int weekNumber = -1;
   for(int i = 0; i < size; i++)
   {
      WeekData tempWeek = weeks[i];

      // HIGH pullback
      if(tempWeek.highTime == oldest_time)
      {
         tempWeek.highPullback = pullbackBuffer.calculateHighPullback();
         tempWeek.highPullbackCalculatedTime = currentBar.time;

         weeks[i] = tempWeek;

         // Print("Finished updating HighPullback for week: ", WeekDataToString(weeks[i]));
      }

      // LOW pullback
      if(tempWeek.lowTime == oldest_time)
      {

         tempWeek.lowPullback = pullbackBuffer.calculateLowPullback();
         tempWeek.lowPullbackCalculatedTime = currentBar.time;

         weeks[i] = tempWeek;

         // Print("Finished updating LowPullback for week: ", WeekDataToString(weeks[i]));
      }
   }
}
#endif 