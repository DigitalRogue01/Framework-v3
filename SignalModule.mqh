#ifndef __SIGNAL_MODULE__
#define __SIGNAL_MODULE__

// These should be defined as extern in your main Framework.mq4:
// extern bool UsePullback = true;
// extern bool UseADXDeclineFilter = true;

bool CheckBuySignal()
{
   double ema        = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
   double adx        = iADX(Symbol(), 0, 14, PRICE_CLOSE, MODE_MAIN, 1);
   double adxPrev    = iADX(Symbol(), 0, 14, PRICE_CLOSE, MODE_MAIN, 2);
   double plusDI     = iADX(Symbol(), 0, 14, PRICE_CLOSE, MODE_PLUSDI, 1);
   double minusDI    = iADX(Symbol(), 0, 14, PRICE_CLOSE, MODE_MINUSDI, 1);
   double psar       = iSAR(Symbol(), 0, 0.02, 0.2, 1);
   double rsi        = iRSI(Symbol(), 0, 14, PRICE_CLOSE, 1);

   bool priceAboveEMA    = Close[1] > ema;
   bool isPullback       = true;
   if (UsePullback)
      isPullback = (Close[1] < Open[1] && Low[1] > ema);

   bool adxTrend         = (adx > 30 && plusDI > minusDI);
   bool adxNotDeclining  = (!UseADXDeclineFilter || adx >= adxPrev);
   bool psarBullish      = (psar < Low[1]);

   return priceAboveEMA && isPullback && adxTrend && adxNotDeclining && psarBullish;
}

bool CheckSellSignal()
{
   double ema        = iMA(Symbol(), 0, 50, 0, MODE_EMA, PRICE_CLOSE, 1);
   double adx        = iADX(Symbol(), 0, 14, PRICE_CLOSE, MODE_MAIN, 1);
   double adxPrev    = iADX(Symbol(), 0, 14, PRICE_CLOSE, MODE_MAIN, 2);
   double plusDI     = iADX(Symbol(), 0, 14, PRICE_CLOSE, MODE_PLUSDI, 1);
   double minusDI    = iADX(Symbol(), 0, 14, PRICE_CLOSE, MODE_MINUSDI, 1);
   double psar       = iSAR(Symbol(), 0, 0.02, 0.2, 1);
   double rsi        = iRSI(Symbol(), 0, 14, PRICE_CLOSE, 1);

   bool priceBelowEMA    = Close[1] < ema;
   bool isPullback       = true;
   if (UsePullback)
      isPullback = (Close[1] > Open[1] && High[1] < ema);

   bool adxTrend         = (adx > 30 && minusDI > plusDI);
   bool adxNotDeclining  = (!UseADXDeclineFilter || adx >= adxPrev);
   bool psarBearish      = (psar > High[1]);

   return priceBelowEMA && isPullback && adxTrend && adxNotDeclining && psarBearish;
}

#endif
