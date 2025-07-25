//+------------------------------------------------------------------+
//| ReportingModule.mqh — CSV Logger                                |
//+------------------------------------------------------------------+
#ifndef __REPORTING_MODULE__
#define __REPORTING_MODULE__

string reportFile = "TradeLog.csv";

//--- Called when trade is opened
void LogTradeEntry(int ticket, int type, double lots, double price, double sl, double tp)
{
   int file = FileOpen(reportFile, FILE_CSV | FILE_WRITE | FILE_READ | FILE_SHARE_WRITE | FILE_ANSI);
   if (file == INVALID_HANDLE)
   {
      Print("❌ Failed to open trade log file");
      return;
   }

   FileSeek(file, 0, SEEK_END); // append mode

   string typeStr = (type == OP_BUY) ? "BUY" : (type == OP_SELL) ? "SELL" : "OTHER";

   FileWrite(file,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
      "OPEN",
      ticket,
      Symbol(),
      typeStr,
      DoubleToStr(lots, 2),
      DoubleToStr(price, _Digits),
      DoubleToStr(sl, _Digits),
      DoubleToStr(tp, _Digits),
      "-"
   );

   FileClose(file);
}

//--- Called when trade is closed
void LogTradeExit(int ticket, double closePrice, double profit)
{
   int file = FileOpen(reportFile, FILE_CSV | FILE_WRITE | FILE_READ | FILE_SHARE_WRITE | FILE_ANSI);
   if (file == INVALID_HANDLE)
   {
      Print("❌ Failed to open trade log file for close");
      return;
   }

   FileSeek(file, 0, SEEK_END); // append mode

   FileWrite(file,
      TimeToString(TimeCurrent(), TIME_DATE | TIME_MINUTES),
      "CLOSE",
      ticket,
      Symbol(),
      "-",
      "-",
      "-",
      "-",
      DoubleToStr(closePrice, _Digits),
      DoubleToStr(profit, 2)
   );

   FileClose(file);
}

#endif
