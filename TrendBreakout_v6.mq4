//+------------------------------------------------------------------+
//|                                                      TrendBreakout_Fixed.mq4 |
//|                          Cleaned & Improved Trend-Following EA                |
//+------------------------------------------------------------------+
#property strict

input int    EMA_Period          = 50;
input int    ADX_Period          = 14;
input double ADX_Threshold       = 20;
input int    ATR_Period          = 14;
input double RiskPercent         = 2.0;
input double StopLoss_ATR_Mult   = 1.5;
input double ScaleOut_ATR_Mult   = 1.0;
input double Slippage            = 3;
input int    MagicNumber         = 123456;

int Ticket = -1;
double EntryPrice, StopLossPrice, TakeProfitPrice;
bool HasScaledOut = false;

//+------------------------------------------------------------------+
int OnInit() {
   Print("✅ TrendBreakout EA initialized");
   // Draw vertical line at current bar when EA starts
   string lineID = "EA_Startup_Line";
   datetime timeNow = Time[0];
   ObjectCreate(0, lineID, OBJ_VLINE, 0, timeNow, 0);
   ObjectSetInteger(0, lineID, OBJPROP_COLOR, clrAqua);
   ObjectSetInteger(0, lineID, OBJPROP_STYLE, STYLE_DASHDOTDOT);
   ObjectSetInteger(0, lineID, OBJPROP_WIDTH, 2);

   return INIT_SUCCEEDED;
}
//+------------------------------------------------------------------+
void OnTick() {
   if (IsTradeOpen()) {
      ManageTrade();
      return;
   }

   if (!IsEntryTime()) return;

   double ema  = iMA(Symbol(), 0, EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
   double adx  = iADX(Symbol(), 0, ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
   double atr  = iATR(Symbol(), 0, ATR_Period, 1);
   double psar = iSAR(Symbol(), 0, 0.02, 0.2, 1);
   double price = Close[1];

   if (adx < ADX_Threshold) return;
   if (price < ema || price < psar) return;

   double lotSize = CalculateLotSize(StopLoss_ATR_Mult * atr);
   double stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
double minSL = Ask - stopLevel - (5 * Point);
double rawSL = price - StopLoss_ATR_Mult * atr;
StopLossPrice = NormalizeDouble(MathMin(rawSL, minSL), Digits);

   Ticket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, Slippage,
                      StopLossPrice, 0, "Trend Entry", MagicNumber, 0, clrGreen);

   if (Ticket > 0) {
      EntryPrice = Ask;
      HasScaledOut = false;
      Print("✅ Buy order placed: ", EntryPrice);
   } else {
      Print("❌ OrderSend failed: ", GetLastError());
   }
}
//+------------------------------------------------------------------+
bool IsTradeOpen() {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) {
         if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol())
            return true;
      }
   }
   return false;
}
//+------------------------------------------------------------------+
bool IsEntryTime() {
   datetime candleOpen = iTime(Symbol(), 0, 0);
   return TimeCurrent() >= (candleOpen + PeriodSeconds() - 30);  // last 30 sec
}
//+------------------------------------------------------------------+
void ManageTrade() {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol()) continue;

      double atr = iATR(Symbol(), 0, ATR_Period, 1);
      double psar = iSAR(Symbol(), 0, 0.02, 0.2, 0);
      double price = Bid;

      // PSAR Flip Exit
      if (OrderType() == OP_BUY && psar > price) {
         OrderClose(OrderTicket(), OrderLots(), Bid, Slippage, clrRed);
         Print("🔻 Closed on PSAR flip");
         return;
      }

      // Scale-out at 1x ATR
      if (!HasScaledOut && OrderType() == OP_BUY && price >= EntryPrice + ScaleOut_ATR_Mult * atr) {
         double halfLot = NormalizeDouble(OrderLots() / 2.0, 2);
         if (halfLot >= MarketInfo(Symbol(), MODE_MINLOT)) {
            OrderClose(OrderTicket(), halfLot, Bid, Slippage, clrYellow);
            Print("💰 Scaled out 50% at +1 ATR");

// Reacquire updated ticket after scale-out
for (int j = OrdersTotal() - 1; j >= 0; j--) {
    if (OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) {
        if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) {
            Ticket = OrderTicket();
            break;
        }
    }
}
         }
         // Move SL to breakeven
         double newSL = NormalizeDouble(EntryPrice, Digits);
         OrderModify(OrderTicket(), OrderOpenPrice(), newSL, 0, 0, clrAqua);
         HasScaledOut = true;
         Print("🔐 SL moved to breakeven");
      }
   }
}
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistance) {
    double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    if (tickValue <= 0) return 0.0;
   double riskAmount = AccountBalance() * RiskPercent / 100.0;
   double lot = riskAmount / (stopLossDistance * MarketInfo(Symbol(), MODE_TICKVALUE));
   double step = MarketInfo(Symbol(), MODE_LOTSTEP);
    double minLot = MarketInfo(Symbol(), MODE_MINLOT);
    double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);

    double adjustedLot = MathFloor(lot / step) * step;
    adjustedLot = MathMax(minLot, MathMin(maxLot, adjustedLot));
    return NormalizeDouble(adjustedLot, 2);
}
