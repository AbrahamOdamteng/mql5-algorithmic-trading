
#ifndef UTILS_MQH
#define UTILS_MQH

#include "datatypes.mqh"


void Append(WeekHighLow &myArray[], const WeekHighLow &newValue)
{
   int size = ArraySize(myArray);
   ArrayResize(myArray, size + 1);
   myArray[size] = newValue;
}

void Append(WeekData &myArray[], const WeekData &newValue)
{
   int size = ArraySize(myArray);
   ArrayResize(myArray, size + 1);
   myArray[size] = newValue;
}

void Append(PriceCluster &myArray[], const PriceCluster &newValue)
{
   int size = ArraySize(myArray);
   ArrayResize(myArray, size + 1);
   myArray[size] = newValue;
}

PriceCluster GetLast(const PriceCluster &priceClusters[])
{
   int size = ArraySize(priceClusters);

   if (size == 0)
   {
      PriceCluster emptyBar;
      ZeroMemory(emptyBar);
      return emptyBar;
   }

   return priceClusters[size - 1];
}


WeekData GetLast(const WeekData &weeks[])
{
   int size = ArraySize(weeks);

   if(size == 0)
   {
      WeekData emptyWeek;
      ZeroMemory(emptyWeek);
      return emptyWeek;
   }

   return weeks[size - 1];
}

WeekData GetSecondToLast(const WeekData &weekDatas[])
{
   int size = ArraySize(weekDatas);

   if (size < 2)
   {
      WeekData emptyBar;
      ZeroMemory(emptyBar);
      return emptyBar;
   }

   return weekDatas[size - 2];
}





#endif