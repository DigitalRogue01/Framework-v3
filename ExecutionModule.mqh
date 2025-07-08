#ifndef __EXECUTION_MODULE__
#define __EXECUTION_MODULE__

void ExecuteBuy(double lotSize, double stopLossPips, double targetPips, int slippage, int magicNumParam)
{
   if (OrdersTotal() > 0) return;

   double sl = Bid - stopLossPips * Point;
   sl = NormalizeDouble(sl, Digits);

   int ticket = OrderSend(Symbol(), OP_BUY, lotSize, Ask, slippage, sl, 0, "Buy Entry", magicNumParam, 0, clrBlue);
   if (ticket < 0)
      Print("❌ OrderSend failed. Error: ", GetLastError());
   else
      Print("✅ Buy order placed. Ticket: ", ticket);
}

void ExecuteSell(double lotSize, double stopLossPips, double targetPips, int slippage, int magicNumParam)
{
   if (OrdersTotal() > 0) return;

   double sl = Ask + stopLossPips * Point;
   sl = NormalizeDouble(sl, Digits);

   int ticket = OrderSend(Symbol(), OP_SELL, lotSize, Bid, slippage, sl, 0, "Sell Entry", magicNumParam, 0, clrRed);
   if (ticket < 0)
      Print("❌ Sell OrderSend failed. Error: ", GetLastError());
   else
      Print("✅ Sell order placed. Ticket: ", ticket);
}
#endif
