
#ifndef RATES_CCIRCULAR_BUFFER
#define RATES_CCIRCULAR_BUFFER

class RatesCircularBuffer
{
private:
   MqlRates m_data[];
   int      m_size;
   int      m_index;
   int      m_count;

public:

   // Constructor
   RatesCircularBuffer(int size)
   {
      m_size  = size;
      m_index = 0;
      m_count = 0;

      ArrayResize(m_data, m_size);
   }

   // Push newest candle
   void Push(const MqlRates &rate)
   {
      m_data[m_index] = rate;

      m_index = (m_index + 1) % m_size;

      if(m_count < m_size)
         m_count++;
   }

   // Get candle by relative index
   // 0 = newest
   // 1 = previous
   // etc.
   MqlRates Get(int offset)
   {
      MqlRates empty = {};

      if(offset >= m_count)
         return empty;

      int idx = (m_index - 1 - offset + m_size) % m_size;

      return m_data[idx];
   }

   // Latest candle
   MqlRates Latest()
   {
      return Get(0);
   }

   // Oldest stored candle
   MqlRates Oldest()
   {
      MqlRates empty = {};

      if(m_count == 0)
         return empty;

      int idx;

      if(m_count < m_size)
         idx = 0;
      else
         idx = m_index;

      return m_data[idx];
   }

   int Count()
   {
      return m_count;
   }

   bool IsFull()
   {
      return m_count == m_size;
   }

   void Clear()
   {
      m_index = 0;
      m_count = 0;
   }


   double HighImpulse()
   {
      if(m_count == 0)
         return 0.0;

      MqlRates current = Get(0);

      double currentWeekHigh = current.high;
      double lowestLow       = current.low;

      for(int offset = 1; offset < m_count; offset++)
      {
         MqlRates bar = Get(offset);

         // Stop if an older candle already broke/exceeded this high
         if(bar.high > currentWeekHigh)
            break;

         if(bar.low < lowestLow)
            lowestLow = bar.low;
      }

      double res =  currentWeekHigh - lowestLow;
      // Print("New high impulse: ", res);
      return res; 
   }


   double LowImpulse()
   {
      if(m_count == 0)
         return 0.0;

      MqlRates current = Get(0);

      double currentWeekLow = current.low;
      double highestHigh   = current.high;

      for(int offset = 1; offset < m_count; offset++)
      {
         MqlRates bar = Get(offset);

         // Stop if an older candle already broke/exceeded this low
         if(bar.low <= currentWeekLow)
            break;

         if(bar.high > highestHigh)
            highestHigh = bar.high;
      }

      double res =  highestHigh - currentWeekLow;
      // Print("New Low Impulse: ", res);
      return res;
   }




double calculateHighPullback()
{
   if (Count() == 0)
      return 0.0;

   // Oldest element is assumed to be the week-high candle
   MqlRates oldestBar = Get(Count() - 1);
   double weekHigh = oldestBar.high;

   double maxPullback = 0.0;

   // Walk FORWARD from oldest -> newest
   for (int i = Count() - 1; i >= 0; i--)
   {
      MqlRates bar = Get(i);

      // Stop if the weekly high is breached
      if (bar.high > weekHigh)
         break;

      double pullback = weekHigh - bar.low;

      if (pullback > maxPullback)
         maxPullback = pullback;
   }

   return maxPullback;
}


double calculateLowPullback()
{
   if (Count() == 0)
      return 0.0;

   // Oldest element is assumed to be the week-low candle
   MqlRates oldestBar = Get(Count() - 1);
   double weekLow = oldestBar.low;

   double maxPullback = 0.0;

   // Walk FORWARD from oldest -> newest
   for (int i = Count() - 1; i >= 0; i--)
   {
      MqlRates bar = Get(i);

      // Stop if the weekly low is breached
      if (bar.low < weekLow)
         break;

      double pullback = bar.high - weekLow;

      if (pullback > maxPullback)
         maxPullback = pullback;
   }

   return maxPullback;
}


};

#endif