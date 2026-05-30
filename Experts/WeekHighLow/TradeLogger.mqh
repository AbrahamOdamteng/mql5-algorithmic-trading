
#ifndef TRADE_LOGGER
#define TRADE_LOGGER

int g_TradeCsvHandle = INVALID_HANDLE;
// string g_filename = _Symbol + "_oanda_trades.csv";
string g_filename =  "all_symbols_oanda_trades.csv";


void DeleteTradeCsv()
{

   bool exists =
      FileIsExist(g_filename, FILE_COMMON);

   Print(
      "TESTING File Exists | ",
      g_filename,
      " : ",
      exists
   );

   if(exists)
   {
      bool deleted =
         FileDelete(g_filename, FILE_COMMON);

      if(deleted)
         Print("Deleted existing CSV: ", g_filename);
      else
         Print("Failed to delete CSV: ", g_filename);
   }
}

bool OpenTradeCsv()
{

   g_TradeCsvHandle = FileOpen(
      g_filename,
      FILE_WRITE |
      FILE_READ  |
      FILE_CSV   |
      FILE_COMMON,
      ',');

   if(g_TradeCsvHandle == INVALID_HANDLE)
   {
      Print("Failed to open CSV file");
      return false;
   }

   Print("CSV opened successfully");

   FileSeek(g_TradeCsvHandle, 0, SEEK_END);
      Print("CSV opened successfully");


   int ft = FileTell(g_TradeCsvHandle);

      Print("FileTell(g_TradeCsvHandle): ", ft);

   // Write header only if file empty
   if(FileSize(g_TradeCsvHandle) <= 2)
   {
      Print("Writing CSV header");

      FileWrite(
         g_TradeCsvHandle,

         "symbol",
         "ticket",

         "entry_type",
         "direction",

         "deal_time",
         "day_of_week",
         "hour",

         "price",
         "volume",

         "profit",
         "swap",
         "commission",

         "impulse_lookback_hours",
         "pullback_lookforward_hours",

         "impulse_atr_multiplier",
         "pullback_atr_multiplier"
      );

      FileFlush(g_TradeCsvHandle);
   }

   // IMPORTANT:
   // move write pointer to end AFTER header logic
   FileSeek(g_TradeCsvHandle, 0, SEEK_END);

   return true;
}


void CloseTradeCsv()
{
   if(g_TradeCsvHandle != INVALID_HANDLE)
   {
      FileClose(g_TradeCsvHandle);
      g_TradeCsvHandle = INVALID_HANDLE;
   }
}


void SaveClosedTradeToCsv(
   ulong dealTicket,

   string direction,

   datetime entryTime,
   datetime exitTime,

   double entryPrice,
   double exitPrice,

   double lots,

   double profit,
   double swap,
   double commission,

   double slPrice,
   double tpPrice,

   double actualImpulse,
   double requiredImpulse,

   double actualPullback,
   double requiredPullback,

   int clusterSize
)
{
   if(g_TradeCsvHandle == INVALID_HANDLE)
      return;

   MqlDateTime entryStruct;
   MqlDateTime exitStruct;

   TimeToStruct(entryTime, entryStruct);
   TimeToStruct(exitTime, exitStruct);

   long holdingMinutes =
      (long)((exitTime - entryTime) / 60);

   FileWrite(
      g_TradeCsvHandle,

      _Symbol,
      dealTicket,
      direction,

      TimeToString(entryTime, TIME_DATE | TIME_MINUTES),
      entryStruct.day_of_week,
      entryStruct.hour,

      TimeToString(exitTime, TIME_DATE | TIME_MINUTES),
      exitStruct.day_of_week,
      exitStruct.hour,

      holdingMinutes,

      entryPrice,
      exitPrice,

      lots,
      profit,
      swap,
      commission,

      slPrice,
      tpPrice,

      actualImpulse,
      requiredImpulse,

      actualPullback,
      requiredPullback,

      clusterSize,

      g_impulse_lookback_hours,
      g_pullback_lookforward_hours,

      g_Impulse_ATR_multiplier,
      g_pullback_ATR_multiplier
   );

   FileFlush(g_TradeCsvHandle);
}

void OnTradeTransactionHelper(
   const MqlTradeTransaction& trans,
   const MqlTradeRequest& request,
   const MqlTradeResult& result
)
{

   // Only care about deal events
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   ulong dealTicket = trans.deal;

   if(dealTicket == 0)
      return;

   if(!HistoryDealSelect(dealTicket))
      return;

   long dealEntry =
      HistoryDealGetInteger(
         dealTicket,
         DEAL_ENTRY);

   long dealType =
      HistoryDealGetInteger(
         dealTicket,
         DEAL_TYPE);

   datetime dealTime =
      (datetime)HistoryDealGetInteger(
         dealTicket,
         DEAL_TIME);

   double price =
      HistoryDealGetDouble(
         dealTicket,
         DEAL_PRICE);

   double volume =
      HistoryDealGetDouble(
         dealTicket,
         DEAL_VOLUME);

   double profit =
      HistoryDealGetDouble(
         dealTicket,
         DEAL_PROFIT);

   double swap =
      HistoryDealGetDouble(
         dealTicket,
         DEAL_SWAP);

   double commission =
      HistoryDealGetDouble(
         dealTicket,
         DEAL_COMMISSION);

   string direction = "UNKNOWN";

   if(dealType == DEAL_TYPE_BUY)
      direction = "BUY";

   if(dealType == DEAL_TYPE_SELL)
      direction = "SELL";

   string entryType = "UNKNOWN";

   if(dealEntry == DEAL_ENTRY_IN)
      entryType = "IN";

   if(dealEntry == DEAL_ENTRY_OUT)
      entryType = "OUT";

   MqlDateTime dt;
   TimeToStruct(dealTime, dt);

   Print(
      "TRADE EVENT | ",
      "ENTRY=", entryType,
      " TYPE=", direction,
      " PRICE=", price,
      " VOLUME=", volume,
      " PROFIT=", profit
   );

   if(g_TradeCsvHandle == INVALID_HANDLE)
      return;

   FileWrite(
      g_TradeCsvHandle,

      _Symbol,
      dealTicket,

      entryType,
      direction,

      TimeToString(
         dealTime,
         TIME_DATE | TIME_MINUTES),

      dt.day_of_week,
      dt.hour,

      price,
      volume,

      profit,
      swap,
      commission,

      g_impulse_lookback_hours,
      g_pullback_lookforward_hours,

      g_Impulse_ATR_multiplier,
      g_pullback_ATR_multiplier
   );

   FileFlush(g_TradeCsvHandle);
}


#endif