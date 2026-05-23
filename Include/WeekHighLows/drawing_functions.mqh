#ifndef DRAWING_FUNCTIONS
#define DRAWING_FUNCTIONS

void DrawArrow(string name, datetime time, double price, color arrowColor, int arrowCode){

   bool objectCreated =  ObjectCreate(0, name, OBJ_ARROW,0,time,price);
   
   if(!objectCreated){
      Print("DrawArrow() => Failed to create arrow", name);
      return;
   }

   // Set arrow to "up arrow" symbol
   ObjectSetInteger(0, name, OBJPROP_ARROWCODE, arrowCode); // Wingdings up arrow

   // Set color
   ObjectSetInteger(0, name, OBJPROP_COLOR, arrowColor);

   // Set width (size)
   ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);

   // Optional: anchor arrow below price (so it points up nicely)
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
}

void DrawCurrentBarLine(datetime dt)
{
   string name = "WeekLine_" + TimeToString(dt);

   if (ObjectFind(0, name) == -1)
   {

      ObjectCreate(0, name, OBJ_VLINE, 0, dt, 0);

      ObjectSetInteger(0, name, OBJPROP_COLOR, clrGray);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
      // Print("Drawing Week Line at ", TimeToString(dt));
   }
}

void DrawWeekHighLowLine(datetime time, WeekHighLow &weekHighLow, color lineColor)
{
   ObjectCreate(0, weekHighLow.name, OBJ_TREND, 0,
                weekHighLow.startOfWeek, weekHighLow.price,
                time, weekHighLow.price);

   ObjectSetInteger(0, weekHighLow.name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, weekHighLow.name, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, weekHighLow.name, OBJPROP_RAY_RIGHT, true);
}

void UpdateWeekHighLines(double currentPrice, datetime time, WeekHighLow &weekHighLowArray[], WeekLineType lineType)
{

   int arraySize = ArraySize(weekHighLowArray);

   for (int i = 0; i < arraySize; i++)
   {
      WeekHighLow weekHL = weekHighLowArray[i];

      if (weekHL.lineType != lineType)
      {
         Print("Array contains wrong line type: ", WeekHighLowToString(weekHL));
         ExpertRemove();
      }

      bool isHit = false;

      if (lineType == WEEK_HIGH)
      {
         isHit = (weekHL.price <= currentPrice);
      }
      if (lineType == WEEK_LOW)
      {
         isHit = (weekHL.price >= currentPrice);
      }

      if (weekHL.isActive && isHit)
      {

         // Print("Collision detected for ", WeekHighLowToString(weekHL), " at time ", TimeToString(time), " at currentPrice ", currentPrice, " Array Size = ", arraySize);

         weekHL.isActive = false;
         weekHighLowArray[i] = weekHL;

         ObjectMove(0, weekHL.name, 1, time, weekHL.price);
         ObjectSetInteger(0, weekHL.name, OBJPROP_RAY_RIGHT, false);
      }
   }
}


void DrawClusterArrow(MqlRates &currentBar,PriceCluster &detectedCluster){

   string arrowPrefix   = detectedCluster.seedLevel.lineType == WEEK_HIGH ? "UpArrow" : "DownArrow" ;
   color arrowColor     = detectedCluster.seedLevel.lineType == WEEK_HIGH ?clrBlue  : clrRed ;
   int arrowCode        = detectedCluster.seedLevel.lineType == WEEK_HIGH ? 233       : 234 ;
   DrawArrow(arrowPrefix+"_"+ TimeToString(currentBar.time),currentBar.time, detectedCluster.seedLevel.price, arrowColor, arrowCode);

}

#endif