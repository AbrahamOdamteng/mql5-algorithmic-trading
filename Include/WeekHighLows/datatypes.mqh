
#ifndef DATATYPES_MQH
#define DATATYPES_MQH
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


enum WeekLineType
{
   WEEK_HIGH,
   WEEK_LOW
};

struct WeekData
{
   datetime startOfWeek;

   int      weekNumber;

   double   open;
   double   high;
   double   low;
   double   close;

   datetime highTime;
   datetime lowTime;

   double   weeklyATR;

   double   highImpulse;
   double   lowImpulse;

   double   highPullback;
   double   lowPullback;

   datetime highPullbackCalculatedTime;
   datetime lowPullbackCalculatedTime;
};

struct WeekHighLow
{
   WeekLineType lineType;
   string name;
   datetime startOfWeek;
   double price;
   bool isActive;
   int weekNumber;
   double maxPullback;
};


struct PriceCluster
{
   WeekLineType type;
   WeekHighLow seedLevel;
   WeekHighLow levels[];
};


PriceCluster CreatePriceCluster(WeekLineType type,
                                const WeekHighLow &seedLevel,
                                const WeekHighLow &levels[])
{
   PriceCluster cluster;

   cluster.type = type;
   cluster.seedLevel = seedLevel;

   int size = ArraySize(levels);

   if (size > 0)
   {
      ArrayResize(cluster.levels, size);
      for (int i = 0; i < size; i++)
      {
         cluster.levels[i] = levels[i];
      }
   }
   else
   {
      ArrayResize(cluster.levels, 0);
   }

   return cluster;
}


double GetLowestPrice(const PriceCluster &cluster)
{
   double lowestPrice = cluster.seedLevel.price;

   int size = ArraySize(cluster.levels);

   for (int i = 0; i < size; i++)
   {
      double currentPrice = cluster.levels[i].price;

      if (currentPrice < lowestPrice)
      {
         lowestPrice = currentPrice;
      }
   }

   return lowestPrice;
}


double GetHighestPrice(const PriceCluster &cluster)
{
   double highestPrice = cluster.seedLevel.price;

   int size = ArraySize(cluster.levels);

   for (int i = 0; i < size; i++)
   {
      double currentPrice = cluster.levels[i].price;

      if (currentPrice > highestPrice)
      {
         highestPrice = currentPrice;
      }
   }

   return highestPrice;
}

string WeekHighLowToString(const WeekHighLow &w)
{
   string typeStr = "UNKNOWN";

   if (w.lineType == WEEK_HIGH)
      typeStr = "HIGH";
   else if (w.lineType == WEEK_LOW)
      typeStr = "LOW";

   return "WeekHighLow[" +
          "type=" + typeStr +
          ", name=" + w.name +
          ", week=" + IntegerToString(w.weekNumber) +
          ", start=" + TimeToString(w.startOfWeek) +
          ", price=" + DoubleToString(w.price, _Digits) +
          ", active=" + (w.isActive ? "true" : "false") +
          ", maxPullback=" + DoubleToString(w.maxPullback, _Digits) +
          "]";
}

string WeekDataToString(const WeekData &week)
{
   return StringFormat(
      "WeekData{ "
      "startOfWeek=%s, "
      "weekNumber=%d, "
      "open=%.5f, "
      "high=%.5f, "
      "low=%.5f, "
      "close=%.5f, "
      "highTime=%s, "
      "lowTime=%s, "
      "weeklyATR=%.5f, "
      "highImpulse=%.5f, "
      "lowImpulse=%.5f, "
      "highPullback=%.5f, "
      "lowPullback=%.5f "
      "}",
      TimeToString(week.startOfWeek, TIME_DATE | TIME_MINUTES),
      week.weekNumber,
      week.open,
      week.high,
      week.low,
      week.close,
      TimeToString(week.highTime, TIME_DATE | TIME_MINUTES),
      TimeToString(week.lowTime, TIME_DATE | TIME_MINUTES),
      week.weeklyATR,
      week.highImpulse,
      week.lowImpulse,
      week.highPullback,
      week.lowPullback
   );
}


WeekHighLow CreateWeekHighLow(WeekLineType lineType,
                             const string name,
                             datetime startOfWeek,
                             double price,
                             bool isActive,
                             int weekNumber,
                             double maxPullback)
{
   WeekHighLow w;

   w.lineType     = lineType;
   w.name         = name;
   w.startOfWeek  = startOfWeek;
   w.price        = price;
   w.isActive     = isActive;
   w.weekNumber   = weekNumber;
   w.maxPullback  = maxPullback;

   return w;
}

string MqlRatesToString(const MqlRates &bar)
{
   return StringFormat(
      "MqlRates{ time=%s, open=%.5f, high=%.5f, low=%.5f, close=%.5f, tick_volume=%lld, spread=%d, real_volume=%lld }",
      TimeToString(bar.time, TIME_DATE | TIME_MINUTES),
      bar.open,
      bar.high,
      bar.low,
      bar.close,
      bar.tick_volume,
      bar.spread,
      bar.real_volume
   );
}

#endif