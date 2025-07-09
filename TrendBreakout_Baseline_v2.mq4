//+------------------------------------------------------------------+
//|                                             TrendBreakout_FINAL.mq4 |
//|       Clean, fixed version with risk-based lot, SL, scale out, etc |
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
double EntryPrice, StopLossPrice;
bool HasScaledOut = false;

//+------------------------------------------------------------------+
int OnInit() {
   // Mark vertical line where EA starts
   string lineID = "EA_Startup_Line";
   ObjectCreate(0, lineID, OBJ_VLINE, 0, Time[0], 0);
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

   double ema  = iMA(Symbol(), 0, EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 0);
   double adx  = iADX(Symbol(), 0, ADX_Period, PRICE_CLOSE, MODE_MAIN, 0);
   double atr  = iATR(Symbol(), 0, ATR_Period, 0);
   double psar = iSAR(Symbol(), 0, 0.02, 0.2, 0);
   double price = Close[0];

   if (adx < ADX_Threshold) return;

   double lotSize, stopLevel, minSL, rawSL;

   // Buy Setup
   if (price > ema && price > psar) {
      rawSL = Bid - StopLoss_ATR_Mult * atr;
      stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
      minSL = Bid - stopLevel - (5 * Point);
      StopLossPrice = NormalizeDouble(MathMin(rawSL, minSL), Digits);
      lotSize = CalculateLotSize(Bid - StopLossPrice);
      if (lotSize < MarketInfo(Symbol(), MODE_MINLOT)) return;

      Ticket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, Slippage,
                         StopLossPrice, 0, "Buy Entry", MagicNumber, 0, clrBlue);
      if (Ticket > 0) {
         EntryPrice = Ask;
         HasScaledOut = false;
      }
   }

   // Sell Setup
   if (price < ema && price < psar) {
      rawSL = Ask + StopLoss_ATR_Mult * atr;
      stopLevel = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
      minSL = Ask + stopLevel + (5 * Point);
      StopLossPrice = NormalizeDouble(MathMax(rawSL, minSL), Digits);
      lotSize = CalculateLotSize(StopLossPrice - Ask);
      if (lotSize < MarketInfo(Symbol(), MODE_MINLOT)) return;

      Ticket = OrderSend(Symbol(), OP_SELL, lotSize, Bid, Slippage,
                         StopLossPrice, 0, "Sell Entry", MagicNumber, 0, clrRed);
      if (Ticket > 0) {
         EntryPrice = Bid;
         HasScaledOut = false;
      }
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
void ManageTrade() {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (OrderMagicNumber() != MagicNumber || OrderSymbol() != Symbol()) continue;

      double atr = iATR(Symbol(), 0, ATR_Period, 0);
      double psar = iSAR(Symbol(), 0, 0.02, 0.2, 0);
      double price = (OrderType() == OP_BUY) ? Bid : Ask;

      // PSAR Flip Exit
      if ((OrderType() == OP_BUY && psar > price) ||
          (OrderType() == OP_SELL && psar < price)) {
         OrderClose(OrderTicket(), OrderLots(), price, Slippage, clrOrange);
         return;
      }

      // Scale-out logic
      if (!HasScaledOut) {
         if ((OrderType() == OP_BUY && price >= EntryPrice + ScaleOut_ATR_Mult * atr) ||
             (OrderType() == OP_SELL && price <= EntryPrice - ScaleOut_ATR_Mult * atr)) {
            double halfLot = NormalizeDouble(OrderLots() / 2.0, 2);
            if (halfLot >= MarketInfo(Symbol(), MODE_MINLOT)) {
               OrderClose(OrderTicket(), halfLot, price, Slippage, clrYellow);
               HasScaledOut = true;

               // Move SL to breakeven
               double newSL = NormalizeDouble(EntryPrice, Digits);
               OrderModify(OrderTicket(), OrderOpenPrice(), newSL, 0, 0, clrAqua);
            }

            // Reacquire updated ticket
            for (int j = OrdersTotal() - 1; j >= 0; j--) {
               if (OrderSelect(j, SELECT_BY_POS, MODE_TRADES)) {
                  if (OrderMagicNumber() == MagicNumber && OrderSymbol() == Symbol()) {
                     Ticket = OrderTicket();
                     break;
                  }
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossDistance) {
   double riskAmount = AccountBalance() * RiskPercent / 100.0;
   double tickValue = MarketInfo(Symbol(), MODE_TICKVALUE);
   if (tickValue <= 0 || stopLossDistance <= 0) return 0.0;

   double rawLot = riskAmount / MarketInfo(Symbol(), MODE_ASK);
   double step = MarketInfo(Symbol(), MODE_LOTSTEP);
   double minLot = MarketInfo(Symbol(), MODE_MINLOT);
   double maxLot = MarketInfo(Symbol(), MODE_MAXLOT);

   double adjustedLot = MathFloor(rawLot / step) * step;
   adjustedLot = MathMax(minLot, MathMin(maxLot, adjustedLot));
   return NormalizeDouble(adjustedLot, 2);
}
