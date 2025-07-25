//+------------------------------------------------------------------+
//|                                                    TrendBreakout.mq4 |
//|         Clean Trend-Following EA with EMA, ADX, ATR, PSAR         |
//+------------------------------------------------------------------+
#property strict

// --- Inputs
input int    EMA_Period             = 50;
input int    ADX_Period             = 14;
input double ADX_Threshold          = 20;
input int    ATR_Period             = 14;
input double RiskPercent            = 2.0;
input double StopLoss_ATR_Mult      = 1.5;
input double ScaleOut_ATR_Mult      = 1.0;
input double Slippage              = 3;
input int    MagicNumber           = 123456;

// --- Global vars
bool TradeOpen = false;
int  Ticket = -1;
double EntryPrice, StopLossPrice, TakeProfitPrice;

//+------------------------------------------------------------------+
int OnInit() {
    Print("✅ TrendBreakout EA initialized");
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
void OnTick() {
    if (TradeOpen) {
        ManageTrade();
        return;
    }

    if (!IsEntryTime()) return;

    double ema = iMA(Symbol(), 0, EMA_Period, 0, MODE_EMA, PRICE_CLOSE, 1);
    double adx = iADX(Symbol(), 0, ADX_Period, PRICE_CLOSE, MODE_MAIN, 1);
    double atr = iATR(Symbol(), 0, ATR_Period, 1);
    double psar = iSAR(Symbol(), 0, 0.02, 0.2, 1);

    double stopLoss = StopLoss_ATR_Mult * atr;
    double takeProfit = 0; // Not used — we'll exit via PSAR

    double lotSize = CalculateLotSize(RiskPercent, stopLoss);

    // Long Entry
    if (Close[1] > ema && adx >= ADX_Threshold && Close[1] > psar) {
        EntryPrice = Ask;
        StopLossPrice = EntryPrice - stopLoss;
        Ticket = OrderSend(Symbol(), OP_BUY, lotSize, EntryPrice, Slippage,
                           StopLossPrice, 0, "TrendBuy", MagicNumber, 0, clrBlue);
        if (Ticket > 0) {
            TradeOpen = true;
            Print("📈 Long Trade Opened at ", EntryPrice);
        }
    }

    // Short Entry
    else if (Close[1] < ema && adx >= ADX_Threshold && Close[1] < psar) {
        EntryPrice = Bid;
        StopLossPrice = EntryPrice + stopLoss;
        Ticket = OrderSend(Symbol(), OP_SELL, lotSize, EntryPrice, Slippage,
                           StopLossPrice, 0, "TrendSell", MagicNumber, 0, clrRed);
        if (Ticket > 0) {
            TradeOpen = true;
            Print("📉 Short Trade Opened at ", EntryPrice);
        }
    }
}

//+------------------------------------------------------------------+
void ManageTrade() {
    if (!OrderSelect(Ticket, SELECT_BY_TICKET)) return;
    double atr = iATR(Symbol(), 0, ATR_Period, 0);
    double psar = iSAR(Symbol(), 0, 0.02, 0.2, 0);
    double price = MarketInfo(Symbol(), MODE_BID);

    // Breakeven + Scale Out
    if (OrderType() == OP_BUY && price >= EntryPrice + ScaleOut_ATR_Mult * atr) {
        OrderModify(Ticket, OrderOpenPrice(), EntryPrice, 0, 0, clrYellow);
        double halfLot = OrderLots() / 2.0;
        OrderClose(Ticket, halfLot, Bid, Slippage, clrYellow);
        Print("🔁 Buy Trade scaled out, SL moved to breakeven.");
    }
    else if (OrderType() == OP_SELL && price <= EntryPrice - ScaleOut_ATR_Mult * atr) {
        OrderModify(Ticket, OrderOpenPrice(), EntryPrice, 0, 0, clrYellow);
        double halfLot = OrderLots() / 2.0;
        OrderClose(Ticket, halfLot, Ask, Slippage, clrYellow);
        Print("🔁 Sell Trade scaled out, SL moved to breakeven.");
    }

    // Full Exit on PSAR flip
    if ((OrderType() == OP_BUY && psar > price) ||
        (OrderType() == OP_SELL && psar < price)) {
        OrderClose(Ticket, OrderLots(), price, Slippage, clrOrange);
        TradeOpen = false;
        Ticket = -1;
        Print("🚪 PSAR flip exit.");
    }
}

//+------------------------------------------------------------------+
bool IsEntryTime() {
    // Entry only in final 10 seconds of the candle
    datetime candleTime = Time[0];
    return (TimeCurrent() >= (candleTime + PeriodSeconds() - 10));
}

//+------------------------------------------------------------------+
double CalculateLotSize(double riskPercent, double stopLossPoints) {
    double balance = AccountBalance();
    double riskAmount = balance * (riskPercent / 100.0);
    double pipValue = MarketInfo(Symbol(), MODE_TICKVALUE);
    double stopLossPips = stopLossPoints / Point;
    double rawLot = riskAmount / (stopLossPips * pipValue);
    double lotStep = MarketInfo(Symbol(), MODE_LOTSTEP);
    return NormalizeDouble(MathFloor(rawLot / lotStep) * lotStep, 2);
}
