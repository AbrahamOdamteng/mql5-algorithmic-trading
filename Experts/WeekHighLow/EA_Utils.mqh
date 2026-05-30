

#ifndef EA_UTILS_MQH
#define EA_UTILS_MQH


#include <WeekHighLows/datatypes.mqh>

enum TradeStrategy{
   BREAKOUT_STRATEGY,
   REVERSE_ON_STOP
};

double CalculateLotSize(double riskAmount,
                        double entryPrice,
                        double stopLossPrice)
{
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);

   double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

   double stopDistance = MathAbs(entryPrice - stopLossPrice);

   if (stopDistance <= 0)
      return 0;

   // Monetary loss for 1.0 lot
   double lossPerLot =
      (stopDistance / tickSize) * tickValue;

   double lots = riskAmount / lossPerLot;

   // Broker constraints
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);

   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   // Clamp to valid range
   lots = MathMax(minLot, MathMin(maxLot, lots));

   // Round down to broker step
   lots = MathFloor(lots / lotStep) * lotStep;

   return NormalizeDouble(lots, 2);
}









double Calculate_Lot_Size_V2(double riskAmount,
                        double entryPrice,
                        double stopLossPrice)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double stopDistance = MathAbs(entryPrice - stopLossPrice);

   if(stopDistance <= 0)
      return 0.0;

   double testLot = 1.0;

   double profit = 0.0;

   ENUM_ORDER_TYPE orderType =
      (entryPrice > stopLossPrice)
      ? ORDER_TYPE_BUY
      : ORDER_TYPE_SELL;

   // Calculate loss for 1 lot
   if(!OrderCalcProfit(
         orderType,
         _Symbol,
         testLot,
         entryPrice,
         stopLossPrice,
         profit))
   {
      Print("OrderCalcProfit failed");
      return 0.0;
   }

   double lossPerLot = MathAbs(profit);

   if(lossPerLot <= 0.0)
      return 0.0;

   double lots = riskAmount / lossPerLot;

   // Clamp to broker limits
   lots = MathMax(minLot, MathMin(maxLot, lots));

   // Round down to valid step
   lots = MathFloor(lots / lotStep) * lotStep;

   // Normalize using step precision
   int precision = (int)MathRound(-MathLog10(lotStep));

   return NormalizeDouble(lots, precision);
}







double Calculate_Lot_Size_V3(double riskPercentage,
                             double entryPrice,
                             double stopLossPrice,
                             double equity = 0.0)
{
   double minLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double lotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   double stopDistance = MathAbs(entryPrice - stopLossPrice);

   if(stopDistance <= 0.0)
      return 0.0;

   // Use current account equity if not supplied
   if(equity <= 0.0)
      equity = AccountInfoDouble(ACCOUNT_EQUITY);

   double riskAmount = equity * (riskPercentage / 100.0);

   double profit = 0.0;

   ENUM_ORDER_TYPE orderType =
      (entryPrice > stopLossPrice)
      ? ORDER_TYPE_BUY
      : ORDER_TYPE_SELL;

   // Calculate loss for 1 lot
   if(!OrderCalcProfit(
         orderType,
         _Symbol,
         1.0,
         entryPrice,
         stopLossPrice,
         profit))
   {
      Print("OrderCalcProfit failed");
      return 0.0;
   }

   double lossPerLot = MathAbs(profit);

   if(lossPerLot <= 0.0)
      return 0.0;

   double lots = riskAmount / lossPerLot;

   // Clamp to broker limits
   lots = MathMax(minLot, MathMin(maxLot, lots));

   // Round down to valid step
   lots = MathFloor(lots / lotStep) * lotStep;

   int precision = (int)MathRound(-MathLog10(lotStep));

   return NormalizeDouble(lots, precision);
}






void PlacePendingOrder(PriceCluster &cluster, WeekData &weeks[], CTrade &trade, int takeProfitMultiplier, double atrVal){

   placeImpulseContinuationOrders(cluster, weeks,trade,takeProfitMultiplier, atrVal);
}



void breakoutStrategy(PriceCluster &cluster, CTrade &trade, int takeProfitMultiplier){

   if(cluster.seedLevel.lineType == WEEK_HIGH){
      double stopLoss = GetLowestPrice(cluster);
      double takeProfit = GetHighestPrice(cluster);

      double diff = cluster.seedLevel.price - stopLoss;
      takeProfit = (diff * takeProfitMultiplier) + cluster.seedLevel.price;

      double volume = Calculate_Lot_Size_V3(1, cluster.seedLevel.price, stopLoss );

      bool success = trade.BuyStop(volume,cluster.seedLevel.price,_Symbol,stopLoss,takeProfit);

      if (success){
         Print("Buy Stop placed successfully^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
      }else{
         Print("Failed to place order");
         Print("Volume: ", volume);
         Print("Retcode: ", trade.ResultRetcode());
         Print("Description: ", trade.ResultRetcodeDescription());
      }
   }

   if(cluster.seedLevel.lineType == WEEK_LOW){
      double takeProfit = GetLowestPrice(cluster);
      double stopLoss = GetHighestPrice(cluster);

      double diff = stopLoss - cluster.seedLevel.price;
      takeProfit = cluster.seedLevel.price - (diff * takeProfitMultiplier) ;

      double volume = Calculate_Lot_Size_V3(1, cluster.seedLevel.price, stopLoss );

      bool success = trade.SellStop(volume,cluster.seedLevel.price,_Symbol,stopLoss,takeProfit);

      if (success){
         Print("Sell Stop placed successfully ---------------------------------------------------");
      }else{
         Print("Failed to place order");
         Print("Volume: ", volume);
         Print("Retcode: ", trade.ResultRetcode());
         Print("Description: ", trade.ResultRetcodeDescription());
      }
   }
}


void reverseOnStopStrategy(PriceCluster &cluster, CTrade &trade, int takeProfitMultiplier, double atrVal){

   // double longEntryPrice = cluster.seedLevel.price;
   // double longStopLoss   = longEntryPrice - atrVal;
   // double longTakeProfit = longEntryPrice + (takeProfitMultiplier * atrVal);

   // double shortEntryPrice = longStopLoss;
   // double shortStopLoss   = shortEntryPrice + atrVal;
   // double shortTakeProfit = shortEntryPrice + (takeProfitMultiplier * atrVal);


   double longEntryPrice = GetHighestPrice(cluster);
   double longStopLoss   = GetLowestPrice(cluster);
   double longTakeProfit = longEntryPrice + (takeProfitMultiplier * (MathAbs(longEntryPrice - longStopLoss)));

   double shortEntryPrice = GetLowestPrice(cluster);
   double shortStopLoss   = GetHighestPrice(cluster);
   double shortTakeProfit = shortEntryPrice - (takeProfitMultiplier * MathAbs(shortStopLoss - shortEntryPrice ));


   double volume          = Calculate_Lot_Size_V3(1, longEntryPrice, longStopLoss );


   if(cluster.seedLevel.lineType == WEEK_HIGH){

      bool success = trade.BuyStop(volume, longEntryPrice,_Symbol,longStopLoss,longTakeProfit);

      if (success){
         Print("Buy Stop placed successfully^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
      }else{
         Print("Failed to place order");
         Print("Volume: ", volume);
         Print("Retcode: ", trade.ResultRetcode());
         Print("Description: ", trade.ResultRetcodeDescription());
      }

      success =  trade.SellLimit(volume,shortEntryPrice,_Symbol,shortStopLoss,shortTakeProfit);

      if (success){
         Print("Sell Limit placed successfully^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
      }else{
         Print("Failed to place order");
         Print("Volume: ", volume);
         Print("Retcode: ", trade.ResultRetcode());
         Print("Description: ", trade.ResultRetcodeDescription());
      }

   } else {

      bool success = trade.SellStop(volume, shortEntryPrice,_Symbol,shortStopLoss,shortTakeProfit);

      if (success){
         Print("Sell Stop placed successfully^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
      }else{
         Print("Failed to place order");
         Print("Volume: ", volume);
         Print("Retcode: ", trade.ResultRetcode());
         Print("Description: ", trade.ResultRetcodeDescription());
      }

      success =  trade.BuyLimit(volume,longEntryPrice,_Symbol,longStopLoss,longTakeProfit);

      if (success){
         Print("Buy Limit placed successfully^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
      }else{
         Print("Failed to place order");
         Print("Volume: ", volume);
         Print("Retcode: ", trade.ResultRetcode());
         Print("Description: ", trade.ResultRetcodeDescription());
      }

   }

}



void reverseOnStopStrategyV222222233(PriceCluster &cluster, CTrade &trade, int takeProfitMultiplier, double atrVal){

   // double longEntryPrice = cluster.seedLevel.price;
   // double longStopLoss   = longEntryPrice - atrVal;
   // double longTakeProfit = longEntryPrice + (takeProfitMultiplier * atrVal);

   // double shortEntryPrice = longStopLoss;
   // double shortStopLoss   = shortEntryPrice + atrVal;
   // double shortTakeProfit = shortEntryPrice + (takeProfitMultiplier * atrVal);


   double longEntryPrice = cluster.seedLevel.price + atrVal; 
   double longStopLoss   = cluster.seedLevel.price; 
   double longTakeProfit = longEntryPrice + (takeProfitMultiplier * (MathAbs(longEntryPrice - longStopLoss))); 
   
   double shortEntryPrice = cluster.seedLevel.price - atrVal; 
   double shortStopLoss   = cluster.seedLevel.price; 
   double shortTakeProfit = shortEntryPrice - (takeProfitMultiplier * MathAbs(shortStopLoss - shortEntryPrice ));

   double volume          = Calculate_Lot_Size_V3(1, longEntryPrice, longStopLoss );


   if(cluster.seedLevel.lineType == WEEK_HIGH){

      bool success = trade.BuyStop(volume, longEntryPrice,_Symbol,longStopLoss,longTakeProfit);

      if (success){
         Print("Buy Stop placed successfully^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
      }else{
         Print("Failed to place order");
         Print("Volume: ", volume);
         Print("Retcode: ", trade.ResultRetcode());
         Print("Description: ", trade.ResultRetcodeDescription());
      }

      success =  trade.SellLimit(volume,shortEntryPrice,_Symbol,shortStopLoss,shortTakeProfit);

      if (success){
         Print("Sell Limit placed successfully^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
      }else{
         Print("Failed to place order");
         Print("Volume: ", volume);
         Print("Retcode: ", trade.ResultRetcode());
         Print("Description: ", trade.ResultRetcodeDescription());
      }

   } else {

      bool success = trade.SellStop(volume, shortEntryPrice,_Symbol,shortStopLoss,shortTakeProfit);

      if (success){
         Print("Sell Stop placed successfully^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
      }else{
         Print("Failed to place order");
         Print("Volume: ", volume);
         Print("Retcode: ", trade.ResultRetcode());
         Print("Description: ", trade.ResultRetcodeDescription());
      }

      success =  trade.BuyLimit(volume,longEntryPrice,_Symbol,longStopLoss,longTakeProfit);

      if (success){
         Print("Buy Limit placed successfully^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
      }else{
         Print("Failed to place order");
         Print("Volume: ", volume);
         Print("Retcode: ", trade.ResultRetcode());
         Print("Description: ", trade.ResultRetcodeDescription());
      }

   }

}


int GetDayOfWeek(datetime dt)
{
   MqlDateTime timeStruct;
   TimeToStruct(dt, timeStruct);

   return timeStruct.day_of_week;
}


int GetHour(datetime dt)
{
   MqlDateTime timeStruct;
   TimeToStruct(dt, timeStruct);

   return timeStruct.hour;
}


string tradeComment(datetime tradeTime, string direction, double impulse, double pullback, PriceCluster &cluster){

   int dayOfWeek = GetDayOfWeek(tradeTime);
   int hourOfDay = GetHour(tradeTime);
   return StringFormat("D%dT%d|C%d|I%.4f|P%.4f", dayOfWeek,hourOfDay, ArraySize(cluster.levels), impulse,pullback);
}

void PrintOrderDistances(
   double entryPrice,
   double stopLoss,
   double takeProfit
)
{
   double minStopDistance =
      SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_STOPS_LEVEL
      ) *
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_POINT
      );

   double slDistance =
      MathAbs(entryPrice - stopLoss);

   double tpDistance =
      MathAbs(takeProfit - entryPrice);

   Print("====================================");
   Print("ENTRY PRICE: ", entryPrice);
   Print("STOP LOSS : ", stopLoss);
   Print("TAKE PROFIT: ", takeProfit);

   Print("SL DISTANCE: ", slDistance);
   Print("TP DISTANCE: ", tpDistance);

   Print("MIN STOP DISTANCE: ", minStopDistance);

   Print(
      "SL VALID: ",
      slDistance >= minStopDistance
   );

   Print(
      "TP VALID: ",
      tpDistance >= minStopDistance
   );

   Print("====================================");
}

double NormalizePrice(double price)
{
   double tickSize =
      SymbolInfoDouble(
         _Symbol,
         SYMBOL_TRADE_TICK_SIZE
      );

   return
      MathRound(price / tickSize)
      * tickSize;
}


void placeImpulseContinuationOrders(PriceCluster &cluster, WeekData &weeks[],  CTrade &trade, int takeProfitMultiplier, double atrVal){

   Print(
      "SYMBOL_FILLING_MODE=",
      SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE)
   );

   Print(
      "SYMBOL_TRADE_MODE=",
      SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE)
   );

   Print(
      "SYMBOL_ORDER_MODE=",
      SymbolInfoInteger(_Symbol, SYMBOL_ORDER_MODE)
   );

   Print(
      "SYMBOL_TRADE_STOPS_LEVEL=",
      SymbolInfoInteger(
         _Symbol,
         SYMBOL_TRADE_STOPS_LEVEL
      )
   );

   Print(
   "Point=",
   SymbolInfoDouble(_Symbol, SYMBOL_POINT)
   );

   Print(
   "SYMBOL_VOLUME_MIN=",
   SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN)
   );

   Print(
      "SYMBOL_VOLUME_MAX=",
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX)
   );

   Print(
      "SYMBOL_VOLUME_STEP=",
      SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP)
   );

//   trade.SetTypeFilling(ORDER_FILLING_FOK);


   double minStopDistance = SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL) * SymbolInfoDouble( _Symbol,SYMBOL_POINT);






   double longEntryPrice = cluster.seedLevel.price + atrVal; 
   double longStopLoss   = cluster.seedLevel.price; 
   double longTakeProfit = longEntryPrice + (takeProfitMultiplier * (MathAbs(longEntryPrice - longStopLoss))); 
   
   double shortEntryPrice = cluster.seedLevel.price - atrVal; 
   double shortStopLoss   = cluster.seedLevel.price; 
   double shortTakeProfit = shortEntryPrice - (takeProfitMultiplier * MathAbs(shortStopLoss - shortEntryPrice ));

   longEntryPrice = NormalizePrice(longEntryPrice);
   longStopLoss   = NormalizePrice(longStopLoss);
   longTakeProfit = NormalizePrice(longTakeProfit);

   shortEntryPrice   = NormalizePrice(shortEntryPrice);
   shortStopLoss     = NormalizePrice(shortStopLoss);
   shortTakeProfit   = NormalizePrice(shortTakeProfit);


   double volume          = 0.0;

   double longEntryDistance   = MathAbs(longEntryPrice - longStopLoss);
   double longTpDistance      = MathAbs(longTakeProfit - longEntryPrice);


   double shortEntryDistance =
   MathAbs(shortEntryPrice - shortStopLoss);

double shortTpDistance =
   MathAbs(shortTakeProfit - shortEntryPrice);

if(longEntryDistance < minStopDistance)
{
   Print(
      "INVALID LONG SL DISTANCE | ",
      "Required=", minStopDistance,
      " Actual=", longEntryDistance
   );

   return;
}

if(longTpDistance < minStopDistance)
{
   Print(
      "INVALID LONG TP DISTANCE | ",
      "Required=", minStopDistance,
      " Actual=", longTpDistance
   );

   return;
}


if(shortEntryDistance < minStopDistance)
{
   Print(
      "INVALID SHORT SL DISTANCE | ",
      "Required=", minStopDistance,
      " Actual=", shortEntryDistance
   );

   return;
}

if(shortTpDistance < minStopDistance)
{
   Print(
      "INVALID SHORT TP DISTANCE | ",
      "Required=", minStopDistance,
      " Actual=", shortTpDistance
   );

   return;
}

   WeekData wd = weeks[cluster.seedLevel.weekNumber];
   if(wd.weekNumber != cluster.seedLevel.weekNumber){
      Print("Error!!!!: wd.weekNumber != cluster.seedLevel.weekNumber");
      WeekData error = weeks[1000000];
   }

   if(cluster.seedLevel.lineType == WEEK_HIGH){
      volume = Calculate_Lot_Size_V2(1000, longEntryPrice, longStopLoss );
      string comment = tradeComment(wd.highTime, "H", wd.highImpulse, wd.highPullback,cluster);

      PrintOrderDistances(longEntryPrice,longStopLoss, longTakeProfit);

      bool success = trade.BuyStop(volume, longEntryPrice,_Symbol,longStopLoss,longTakeProfit,ORDER_TIME_GTC,0,comment );

      if (success){
         Print("Buy Stop placed successfully^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
      }else{
         Print("Failed to place order");
         Print("Volume: ", volume);
         Print("Retcode: ", trade.ResultRetcode());
         Print("Description: ", trade.ResultRetcodeDescription());
      }
   } else {

      volume = Calculate_Lot_Size_V2(1000, shortEntryPrice, shortStopLoss );

      string comment = tradeComment(wd.lowTime, "L", wd.lowImpulse, wd.lowPullback,cluster);
      PrintOrderDistances(shortEntryPrice, shortStopLoss, shortTakeProfit);

      bool success = trade.SellStop(volume, shortEntryPrice,_Symbol,shortStopLoss,shortTakeProfit,ORDER_TIME_GTC,0,comment);

      if (success){
         Print("Sell Stop placed successfully^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^");
      }else{
         Print("Failed to place order");
         Print("Volume: ", volume);
         Print("Retcode: ", trade.ResultRetcode());
         Print("Description: ", trade.ResultRetcodeDescription());
      }
   }
}



#endif