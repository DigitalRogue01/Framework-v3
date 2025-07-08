#ifndef __TradeManagementModule__
#define __TradeManagementModule__

// Settings
// Helper function: returns true if order is a matching market order
bool IsOurOrder(int magicNumber) {
   return (OrderMagicNumber() == magicNumber && OrderSymbol() == Symbol() &&
           (OrderType() == OP_BUY || OrderType() == OP_SELL));
}

// Manage open trades
void ManageOpenTrades(double atr, int magicNumber) {
   for (int i = OrdersTotal() - 1; i >= 0; i--) {
      if (!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if (!IsOurOrder(magicNumber)) continue;

      int ticket = OrderTicket();
      double openPrice = OrderOpenPrice();
      double lots = OrderLots();
      int type = OrderType();
      double currentPrice = (type == OP_BUY) ? Bid : Ask;
      double sl = OrderStopLoss();

      // === Break-Even Stop ===
      double beThreshold = openPrice + ((type == OP_BUY) ? BreakEvenATRMultiplier * atr : -BreakEvenATRMultiplier * atr);
      bool shouldMoveSL = (type == OP_BUY && currentPrice >= beThreshold) ||
                          (type == OP_SELL && currentPrice <= beThreshold);

      if (shouldMoveSL) {
         double newSL = openPrice;
         if (MathAbs(sl - newSL) > Point) {
            if (!OrderModify(ticket, openPrice, newSL, OrderTakeProfit(), 0, clrBlue)) {
               Print("⚠️ Failed to move SL to BE. Error: ", GetLastError());
            } else {
               Print("✅ Moved SL to BE. Ticket: ", ticket);
            }
         }
      }

      // === Scale Out ===
      double scaleOutPrice = openPrice + ((type == OP_BUY) ? ScaleOutATRMultiplier * atr : -ScaleOutATRMultiplier * atr);
      bool reachedScaleOut = (type == OP_BUY && currentPrice >= scaleOutPrice) ||
                             (type == OP_SELL && currentPrice <= scaleOutPrice);

      if (reachedScaleOut && lots > MarketInfo(Symbol(), MODE_MINLOT)) {
         double closeLots = NormalizeDouble(lots / 2.0, 2);
         double priceToClose = (type == OP_BUY) ? Bid : Ask;

         bool scaledOut = OrderClose(ticket, closeLots, priceToClose, 3, clrYellow);
         if (scaledOut) {
            Print("📉 Scaled out half. Ticket=", ticket, " Closed=", closeLots);
         } else {
            Print("❌ Failed to scale out. Error: ", GetLastError());
         }
      }

      // === PSAR Exit ===
      double psar = iSAR(Symbol(), 0, 0.02, 0.2, 0);
      bool exitSignal = (type == OP_BUY && psar > currentPrice) ||
                        (type == OP_SELL && psar < currentPrice);

      if (exitSignal) {
         double closePrice = (type == OP_BUY) ? Bid : Ask;
         bool closedPSAR = OrderClose(ticket, lots, closePrice, 3, clrRed);
         if (closedPSAR) {
            Print("🛑 PSAR exit hit. Ticket=", ticket);
         } else {
            Print("❌ PSAR exit failed. Error: ", GetLastError());
         }
      }
   }
}

#endif
