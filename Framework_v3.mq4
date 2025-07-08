#include "SignalModule.mqh"
#include "RiskModule.mqh"
#include "ExecutionModule.mqh"
#include "TradeManagementModule.mqh"
#include "ReportingModule.mqh"

// === Inputs ===
input int magicNumber = 12345;
input int atrPeriod = 14;
input double lotRiskPercent = 2.0;
input double StopLossATRMultiplier = 1.0;
input double TakeProfitATRMultiplier = 1.5;
input double BreakEvenATRMultiplier = 1.0;
input double ScaleOutATRMultiplier = 1.0;
input int Slippage = 3;

// === Flags for Signal Logic ===
extern bool UsePullback = true;
extern bool UseADXDeclineFilter = true;

// === Global Variables ===
double atr;

int OnInit() {
   Print("📊 Framework_v3 initialized.");
   return INIT_SUCCEEDED;
}

void OnTick() {
   // Refresh ATR value
   atr = iATR(Symbol(), 0, atrPeriod, 0);
   if (atr <= 0) return;

   ManageOpenTrades(atr, magicNumber);

   // Prevent multiple trades
   if (OrdersTotal() > 0) return;

   // Entry Logic
   if (CheckBuySignal()) {
      double stopLossPoints = StopLossATRMultiplier * atr / Point;
      double takeProfitPoints = TakeProfitATRMultiplier * atr / Point;
      double lotSize = CalculateLotSize(lotRiskPercent, stopLossPoints);
      ExecuteBuy(lotSize, stopLossPoints, takeProfitPoints, Slippage, magicNumber);
   } if (CheckSellSignal()) {
      double stopLossPoints = StopLossATRMultiplier * atr / Point;
      double takeProfitPoints = TakeProfitATRMultiplier * atr / Point;
      double lotSize = CalculateLotSize(lotRiskPercent, stopLossPoints);
      ExecuteSell(lotSize, stopLossPoints, takeProfitPoints, Slippage, magicNumber);
   }
}

void OnDeinit(const int reason) {
   Print("🔚 Framework_v3 deinitialized.");
}
