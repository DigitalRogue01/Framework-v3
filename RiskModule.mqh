#ifndef __RISK_MODULE__
#define __RISK_MODULE__

double CalculateLotSize(double riskPercent, double stopLossPoints)
{
   double accountBalance = AccountBalance();
   double riskAmount     = accountBalance * (riskPercent / 100.0);
   double pipValue       = MarketInfo(Symbol(), MODE_TICKVALUE);
   double stopLossPips   = stopLossPoints / 10.0;

   double rawLot = riskAmount / (stopLossPips * pipValue);
   double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
   double finalLot = MathFloor(rawLot / lotStep) * lotStep;
   return NormalizeDouble(finalLot, 2);
}

#endif
