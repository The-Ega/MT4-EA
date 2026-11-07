//+------------------------------------------------------------------+
//|                                        BE_MarginLevel_Lines.mq4  |
//|  1) Line where Equity = Balance                                  |
//|  2) Line where Margin Level = X% (default 120%)                  |
//|  3) Set each order's TP to the Equity=Balance level, only when   |
//|     that level is a valid TP for the order (else ignored)        |
//+------------------------------------------------------------------+
#property copyright "cAghee"
#property version   "1.00"
#property strict
#property description "Draws Equity=Balance and Margin-Level lines for the chart symbol (updates in real time)."
#property description "Button / auto mode sets TP to the Equity=Balance level when it is a TP for that order."

//--- inputs
input double          MarginLevelTarget = 120.0;          // Margin level % for 2nd line
input int             MagicFilter       = -1;             // Orders to set TP / close (-1 = all)
input bool            AutoSetTP         = false;          // Auto-update TP to BE level (start state)
input bool            BasketCloseAtBE   = false;          // Close all symbol orders when Equity reaches Balance
input int             MinTPChangePoints = 3;              // Min TP change (points) before re-modify
input int             Slippage          = 5;              // Slippage for closing (points)
input bool            CloseAllSymbols   = false;          // Close buttons act on ALL symbols (false = this chart only)
input bool            ConfirmProfitClose= false;          // Ask confirmation for Close Profit / Half Profit too
input int             FixedTPPoints     = 6000;           // Default TP distance (points) for "Set TP" button
input int             DailyOpenHour     = 1;              // Daily % : day open hour (MT4 server time)
input double          DailyPctStep      = 1.0;            // Daily % : step between lines (%)
input int             DailyPctCount     = 7;              // Daily % : number of lines above and below
input color           DailyPctColor     = clrDarkGreen;   // Daily % : line color
input bool            DailyPctFullWidth = false;          // Daily % : full-width lines (false = start at day open)
input int             TimerMs           = 500;            // Refresh interval (ms)
input color           BEColor           = clrDodgerBlue;  // Equity=Balance line color
input color           MLColor           = clrOrangeRed;   // Margin level line color
input ENUM_LINE_STYLE BEStyle           = STYLE_SOLID;    // Equity=Balance line style
input ENUM_LINE_STYLE MLStyle           = STYLE_DASH;     // Margin level line style
input int             LineWidth         = 1;              // Line width
input int             FontSize          = 9;              // Text size

//--- object names
#define PFX      "BEML_"
#define LN_BE    "BEML_BE"
#define LN_ML    "BEML_ML"
#define BTN_SET  "BEML_BtnSet"
#define BTN_AUTO "BEML_BtnAuto"
#define LBL      "BEML_Lbl"
#define BTN_CPROF "BEML_BtnCloseProfit"
#define BTN_HPROF "BEML_BtnHalfProfit"
#define BTN_CALL  "BEML_BtnCloseAll"
#define BTN_FTP   "BEML_BtnFixedTP"
#define EDT_FTP   "BEML_EdtFixedTP"
#define LBL_FTP   "BEML_LblFixedTP"
#define BTN_HLOSS "BEML_BtnHalfLoss"
#define BTN_DPCT  "BEML_BtnDailyPct"
#define DP_PFX    "BEML_DP_"

#define MODE_CLOSE_PROFIT 0
#define MODE_HALF_PROFIT  1
#define MODE_CLOSE_ALL    2
#define MODE_HALF_LOSS    3

//--- state
bool   g_auto          = false;
bool   g_armed         = false;   // for basket close: equity was below balance
double g_beBid         = 0;       // Equity=Balance level (Bid price), 0 = none
double g_mlBid         = 0;       // Margin level target (Bid price), 0 = none
uint   g_lastTPAttempt = 0;
int    g_tpPoints      = 6000;    // current value of the on-chart TP points box
bool     g_dpOn        = false;   // Daily % lines visible
datetime g_dpAnchor    = 0;       // time of the day-open bar currently drawn
double   g_dpOpen      = 0;       // day-open price currently drawn

string DpGVName() { return "BEML_DPON_" + IntegerToString(ChartID()); }

//+------------------------------------------------------------------+
int OnInit()
{
   g_auto = AutoSetTP;
   CreateButton(BTN_SET,  "Set BE TP", 10, 30, 90);
   CreateButton(BTN_AUTO, "",         105, 30, 90);
   CreateButton(BTN_CPROF, "Close Profit", 200, 30, 95, clrSeaGreen);
   CreateButton(BTN_HPROF, "Half Profit",  300, 30, 95, clrDarkCyan);
   CreateButton(BTN_CALL,  "CLOSE ALL",    400, 30, 95, clrCrimson);
   CreateButton(BTN_HLOSS, "Half Loss",    500, 30, 95, clrDarkRed);
   // 2nd row: [points box] [Set TP] = xx.xx price
   g_tpPoints = MathMax(1, FixedTPPoints);
   CreateEdit(EDT_FTP, IntegerToString(g_tpPoints), 10, 58, 90);
   CreateButton(BTN_FTP, "Set TP (pts)", 105, 58, 90, clrDarkOrange);
   CreateButton(BTN_DPCT, "", 200, 58, 90);
   // Daily % toggle survives timeframe changes
   g_dpOn = GlobalVariableCheck(DpGVName()) && GlobalVariableGet(DpGVName()) > 0;
   g_dpAnchor = 0;                 // objects were deleted on deinit -> force redraw
   UpdateDpBtn();
   UpdateFixedTPLabel();
   UpdateAutoBtn();
   EventSetMillisecondTimer(MathMax(100, TimerMs));
   Recalc();
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   if(reason == REASON_REMOVE) GlobalVariableDel(DpGVName());
   ObjectsDeleteAll(0, PFX);
   ChartRedraw();
}

void OnTick()  { Recalc(); }
void OnTimer() { RefreshRates(); Recalc(); }   // catches new/closed orders even without ticks

void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == EDT_FTP)
   {
      int v = (int)StringToInteger(ObjectGetString(0, EDT_FTP, OBJPROP_TEXT));
      if(v > 0) g_tpPoints = v;
      ObjectSetString(0, EDT_FTP, OBJPROP_TEXT, IntegerToString(g_tpPoints));   // reset invalid input
      UpdateFixedTPLabel();
      ChartRedraw();
      return;
   }
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(sparam == BTN_DPCT)
   {
      g_dpOn = !g_dpOn;
      GlobalVariableSet(DpGVName(), g_dpOn ? 1 : 0);
      UpdateDpBtn();
      g_dpAnchor = 0;               // force redraw / delete
      Recalc();
      return;
   }
   if(sparam == BTN_FTP)
   {
      ObjectSetInteger(0, BTN_FTP, OBJPROP_STATE, false);
      SetFixedTP();
      Recalc();
      return;
   }
   if(sparam == BTN_SET)
   {
      SetTPs(true);
      ObjectSetInteger(0, BTN_SET, OBJPROP_STATE, false);
   }
   else if(sparam == BTN_AUTO)
   {
      g_auto = !g_auto;
      UpdateAutoBtn();
   }
   else if(sparam == BTN_CPROF || sparam == BTN_HPROF || sparam == BTN_CALL || sparam == BTN_HLOSS)
   {
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ChartRedraw();
      int mode = (sparam == BTN_CPROF) ? MODE_CLOSE_PROFIT :
                 (sparam == BTN_HPROF) ? MODE_HALF_PROFIT  :
                 (sparam == BTN_HLOSS) ? MODE_HALF_LOSS    : MODE_CLOSE_ALL;
      if(ConfirmClose(mode)) CloseOrders(mode);
   }
   Recalc();
}

//+------------------------------------------------------------------+
//| Helpers                                                          |
//+------------------------------------------------------------------+
double PipSize() { return (Digits == 3 || Digits == 5) ? Point * 10 : Point; }

// order (already selected) is one we are allowed to modify/close
bool Managed()
{
   return OrderSymbol() == Symbol()
       && OrderType() <= OP_SELL
       && (MagicFilter < 0 || OrderMagicNumber() == MagicFilter);
}

string Sgn(double v, int d) { return (v >= 0 ? "+" : "") + DoubleToString(v, d); }

//+------------------------------------------------------------------+
//| Core calculation                                                 |
//|  Equity(P) = E0 + V*(P - Bid),  V = net lots * TickValue/TickSize |
//+------------------------------------------------------------------+
void Recalc()
{
   double tv = MarketInfo(Symbol(), MODE_TICKVALUE);
   double ts = MarketInfo(Symbol(), MODE_TICKSIZE);

   double netLots = 0;
   int    nSym = 0, nOther = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderType() > OP_SELL) continue;                   // ignore pending
      if(OrderSymbol() != Symbol()) { nOther++; continue; }
      nSym++;
      netLots += (OrderType() == OP_BUY ? 1.0 : -1.0) * OrderLots();
   }

   double V = (ts > 0) ? netLots * tv / ts : 0;   // money per 1.0 price move
   double E = AccountEquity();
   double B = AccountBalance();
   double M = AccountMargin();

   g_beBid = 0;
   g_mlBid = 0;
   bool hedged = (nSym > 0 && MathAbs(netLots) < 1e-8);

   if(nSym > 0 && MathAbs(V) > 1e-12)
   {
      double be = Bid + (B - E) / V;
      if(be > 0) g_beBid = be;

      if(M > 0)
      {
         double ml = Bid + (MarginLevelTarget / 100.0 * M - E) / V;
         if(ml > 0) g_mlBid = ml;
      }
   }

   //--- lines
   double pip = PipSize();
   DrawLevel(LN_BE, g_beBid, BEColor, BEStyle,
             "Equity = Balance  " + DoubleToString(g_beBid, Digits) +
             "  (" + Sgn((g_beBid - Bid) / pip, 1) + " pips)");
   DrawLevel(LN_ML, g_mlBid, MLColor, MLStyle,
             "Margin Level " + DoubleToString(MarginLevelTarget, 0) + "%  " +
             DoubleToString(g_mlBid, Digits) +
             "  (" + Sgn((g_mlBid - Bid) / pip, 1) + " pips)");

   //--- info panel
   color fg = (color)ChartGetInteger(0, CHART_COLOR_FOREGROUND);
   string ml = (M > 0) ? DoubleToString(E / M * 100.0, 1) + "%" : "-";
   SetLabel(0, "Net lots " + Sgn(netLots, 2) + "  (" + IntegerToString(nSym) + " orders)   " +
               AccountCurrency() + "/pip: " + Sgn(V * pip, 2), fg);
   SetLabel(1, "Balance " + DoubleToString(B, 2) + "   Equity " + DoubleToString(E, 2) +
               "   Margin lvl " + ml, fg);
   string warn = "";
   if(nSym == 0)      warn = "No open positions on " + Symbol();
   else if(hedged)    warn = "Fully hedged (net 0 lots): equity doesn't change with price - no lines";
   else if(nOther > 0) warn = IntegerToString(nOther) + " order(s) on other symbols - assumed fixed";
   SetLabel(2, warn, clrGoldenrod);

   //--- basket close (virtual basket TP)
   if(BasketCloseAtBE && nSym > 0)
   {
      if(E < B) g_armed = true;
      else if(g_armed) { CloseBasket(); g_armed = false; }
   }
   else if(nSym == 0) g_armed = false;

   //--- daily % lines
   UpdateDailyPct();

   //--- auto TP (throttled)
   if(g_auto && g_beBid > 0 && GetTickCount() - g_lastTPAttempt >= 2000)
      SetTPs(false);

   ChartRedraw();
}

//+------------------------------------------------------------------+
//| Set TP = Equity=Balance level, only where it is a TP             |
//+------------------------------------------------------------------+
void SetTPs(bool verbose)
{
   g_lastTPAttempt = GetTickCount();
   if(g_beBid <= 0)
   {
      if(verbose) Alert(Symbol(), ": no Equity=Balance level to set TP to.");
      return;
   }
   if(!IsTradeAllowed())
   {
      if(verbose) Alert("Trading not allowed - enable AutoTrading / 'Allow live trading'.");
      return;
   }

   RefreshRates();
   double stop   = MathMax(MarketInfo(Symbol(), MODE_STOPLEVEL),
                           MarketInfo(Symbol(), MODE_FREEZELEVEL)) * Point;
   double spread = Ask - Bid;
   double minChg = MinTPChangePoints * Point;
   int done = 0, skipped = 0, failed = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!Managed()) continue;

      double tp;
      if(OrderType() == OP_BUY)
      {
         // buy closes on Bid; TP must be above Bid
         tp = NormalizeDouble(g_beBid, Digits);
         if(tp <= Bid + stop) { skipped++; continue; }      // would act as SL -> ignore
      }
      else
      {
         // sell closes on Ask; Ask = Bid + spread at the BE level
         tp = NormalizeDouble(g_beBid + spread, Digits);
         if(tp >= Ask - stop) { skipped++; continue; }      // would act as SL -> ignore
      }

      if(OrderTakeProfit() > 0 && MathAbs(OrderTakeProfit() - tp) < minChg) continue;

      if(OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tp, 0, clrNONE))
         done++;
      else
      {
         failed++;
         Print("TP modify failed #", OrderTicket(), " tp=", DoubleToString(tp, Digits),
               " err=", GetLastError());
      }
   }

   if(verbose)
      Print(Symbol(), " Set BE TP: modified ", done, ", ignored (SL side) ", skipped, ", failed ", failed);
}

//+------------------------------------------------------------------+
void CloseBasket()
{
   if(!IsTradeAllowed()) return;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!Managed()) continue;
      RefreshRates();
      double px = (OrderType() == OP_BUY) ? Bid : Ask;
      if(!OrderClose(OrderTicket(), OrderLots(), px, Slippage, clrNONE))
         Print("Basket close failed #", OrderTicket(), " err=", GetLastError());
   }
   Print(Symbol(), ": Equity reached Balance - basket closed.");
}

//+------------------------------------------------------------------+
//| Close buttons                                                    |
//+------------------------------------------------------------------+
// order (already selected) is in scope of the close buttons
bool InCloseScope()
{
   return OrderType() <= OP_SELL
       && (CloseAllSymbols || OrderSymbol() == Symbol())
       && (MagicFilter < 0 || OrderMagicNumber() == MagicFilter);
}

double NetProfit() { return OrderProfit() + OrderSwap() + OrderCommission(); }

// does a position with this net P/L belong to the button's selection?
bool MatchesMode(int mode, double pl)
{
   if(mode == MODE_CLOSE_ALL) return true;
   if(mode == MODE_HALF_LOSS) return pl < 0;
   return pl > 0;                      // Close Profit / Half Profit
}

// summary of what a button would do, used in the confirmation window
bool ConfirmClose(int mode)
{
   if((mode == MODE_CLOSE_PROFIT || mode == MODE_HALF_PROFIT) && !ConfirmProfitClose) return true;

   int n = 0; double lots = 0, pl = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!InCloseScope()) continue;
      if(!MatchesMode(mode, NetProfit())) continue;
      n++; lots += OrderLots(); pl += NetProfit();
   }
   string scope = CloseAllSymbols ? "ALL symbols" : Symbol();
   if(n == 0)
   {
      Alert("No matching positions on ", scope, ".");
      return false;
   }

   string what = (mode == MODE_CLOSE_ALL)   ? "FORCE CLOSE ALL positions" :
                 (mode == MODE_HALF_LOSS)   ? "Close HALF of each LOSING position" :
                 (mode == MODE_HALF_PROFIT) ? "Close HALF of each profitable position" :
                                              "Close all profitable positions";
   bool half = (mode == MODE_HALF_PROFIT || mode == MODE_HALF_LOSS);
   string msg = what + " on " + scope + "?\n\n" +
                "Positions: " + IntegerToString(n) + "\n" +
                "Lots: " + DoubleToString(lots, 2) + (half ? "  (about half will be closed)" : "") + "\n" +
                "Current P/L: " + DoubleToString(pl, 2) + " " + AccountCurrency() + "\n";
   if(mode == MODE_HALF_LOSS)
      msg += "\nAbout " + DoubleToString(pl / 2.0, 2) + " " + AccountCurrency() +
             " LOSS will be realized into your balance.\n";
   msg += "\nThis cannot be undone.";
   bool danger = (mode == MODE_CLOSE_ALL || mode == MODE_HALF_LOSS);
   int flags = MB_YESNO | (danger ? MB_ICONWARNING | MB_DEFBUTTON2 : MB_ICONQUESTION);
   return MessageBox(msg, "Confirm", flags) == IDYES;
}

bool CloseWithRetry(int ticket, double lots)
{
   for(int attempt = 0; attempt < 3; attempt++)
   {
      if(!OrderSelect(ticket, SELECT_BY_TICKET)) return false;
      RefreshRates();
      string sym = OrderSymbol();
      int    dg  = (int)MarketInfo(sym, MODE_DIGITS);
      double px  = (OrderType() == OP_BUY) ? MarketInfo(sym, MODE_BID) : MarketInfo(sym, MODE_ASK);
      if(OrderClose(ticket, lots, NormalizeDouble(px, dg), Slippage, clrNONE)) return true;
      int err = GetLastError();
      Print("Close failed #", ticket, " lots=", DoubleToString(lots, 2), " err=", err);
      if(err != ERR_REQUOTE && err != ERR_PRICE_CHANGED && err != ERR_OFF_QUOTES &&
         err != ERR_TRADE_CONTEXT_BUSY && err != ERR_SERVER_BUSY) return false;
      Sleep(300);
   }
   return false;
}

void CloseOrders(int mode)
{
   if(!IsTradeAllowed())
   {
      Alert("Trading not allowed - enable AutoTrading / 'Allow live trading'.");
      return;
   }

   // collect tickets first: partial closes create new tickets and shift indexes
   int tickets[];
   int cnt = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!InCloseScope()) continue;
      ArrayResize(tickets, cnt + 1);
      tickets[cnt++] = OrderTicket();
   }

   int closed = 0, skippedSign = 0, skippedLot = 0, failed = 0;
   double realized = 0;

   for(int k = 0; k < cnt; k++)
   {
      if(!OrderSelect(tickets[k], SELECT_BY_TICKET) || OrderCloseTime() != 0) continue;

      double pl = NetProfit();
      if(!MatchesMode(mode, pl)) { skippedSign++; continue; }   // wrong side (winner/loser)

      double lots = OrderLots();
      if(mode == MODE_HALF_PROFIT || mode == MODE_HALF_LOSS)
      {
         string sym  = OrderSymbol();
         double step = MarketInfo(sym, MODE_LOTSTEP);
         double minl = MarketInfo(sym, MODE_MINLOT);
         if(step <= 0) step = 0.01;
         double half = MathFloor(lots / 2.0 / step + 1e-9) * step;
         half = NormalizeDouble(half, 2);
         if(half < minl || NormalizeDouble(lots - half, 2) < minl)
         {
            skippedLot++;    // e.g. 0.01 lot can't be split
            continue;
         }
         pl  *= half / lots;
         lots = half;
      }

      if(CloseWithRetry(tickets[k], lots)) { closed++; realized += pl; }
      else failed++;
   }

   string name = (mode == MODE_CLOSE_ALL)   ? "Close All" :
                 (mode == MODE_HALF_LOSS)   ? "Half Loss" :
                 (mode == MODE_HALF_PROFIT) ? "Half Profit" : "Close Profit";
   string res = name + ": closed " + IntegerToString(closed) +
                ", approx P/L " + DoubleToString(realized, 2) + " " + AccountCurrency();
   if(skippedSign > 0) res += (mode == MODE_HALF_LOSS ? ", ignored profitable " : ", ignored losing ") +
                              IntegerToString(skippedSign);
   if(skippedLot  > 0) res += ", too small to halve " + IntegerToString(skippedLot);
   if(failed      > 0) res += ", FAILED " + IntegerToString(failed) + " (see Experts log)";
   Print(res);
   if(failed > 0 || skippedLot > 0) Alert(res);
}

//+------------------------------------------------------------------+
//| Fixed TP button: TP = entry +/- N points, open AND pending       |
//| (chart symbol only, because a "point" differs per symbol)        |
//+------------------------------------------------------------------+
void SetFixedTP()
{
   if(!IsTradeAllowed())
   {
      Alert("Trading not allowed - enable AutoTrading / 'Allow live trading'.");
      return;
   }

   // Auto BE TP would move the TPs back to the BE line -> switch it off
   if(g_auto)
   {
      g_auto = false;
      UpdateAutoBtn();
      Print("Auto BE TP switched OFF because fixed TP was set.");
   }

   RefreshRates();
   double dist   = g_tpPoints * Point;
   double stop   = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   double minChg = Point / 2;
   int done = 0, same = 0, skipped = 0, failed = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(OrderSymbol() != Symbol()) continue;
      if(MagicFilter >= 0 && OrderMagicNumber() != MagicFilter) continue;

      int  type  = OrderType();             // 0 BUY,1 SELL,2 BUYLIMIT,3 SELLLIMIT,4 BUYSTOP,5 SELLSTOP
      bool isBuy = (type % 2 == 0);
      double tp  = NormalizeDouble(OrderOpenPrice() + (isBuy ? dist : -dist), Digits);

      bool ok;
      if(type == OP_BUY)       ok = (tp > Bid + stop);   // price already past the TP?
      else if(type == OP_SELL) ok = (tp < Ask - stop);
      else                     ok = (dist >= stop);      // pending: TP vs its own entry
      if(!ok) { skipped++; continue; }

      if(MathAbs(OrderTakeProfit() - tp) < minChg) { same++; continue; }

      if(OrderModify(OrderTicket(), OrderOpenPrice(), OrderStopLoss(), tp, OrderExpiration(), clrNONE))
         done++;
      else
      {
         failed++;
         Print("Fixed TP modify failed #", OrderTicket(), " tp=", DoubleToString(tp, Digits),
               " err=", GetLastError());
      }
   }

   string res = "Set TP " + IntegerToString(g_tpPoints) + " pts (" + DoubleToString(dist, Digits) +
                " price): modified " + IntegerToString(done);
   if(same    > 0) res += ", already set " + IntegerToString(same);
   if(skipped > 0) res += ", skipped " + IntegerToString(skipped) + " (price already beyond TP / too close)";
   if(failed  > 0) res += ", FAILED " + IntegerToString(failed) + " (see Experts log)";
   Print(res);
   if(skipped > 0 || failed > 0) Alert(res);
}

void UpdateFixedTPLabel()
{
   string name = LBL_FTP;
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 300);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 47);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrDarkOrange);
   ObjectSetString(0, name, OBJPROP_TEXT,
                   "= " + DoubleToString(g_tpPoints * Point, Digits) + " price from entry  (" +
                   Symbol() + ", " + IntegerToString(Digits) + " digits)");
}

//+------------------------------------------------------------------+
//| Daily % lines: day open at DailyOpenHour (server time) = 0%,     |
//| then +/- step% ... +/- count*step%                               |
//+------------------------------------------------------------------+
// finds the first H1 bar at/after the most recent day-open time
bool FindDayOpen(datetime &barTime, double &price)
{
   datetime now    = TimeCurrent();
   long     secs   = (long)now;
   datetime anchor = (datetime)(secs - secs % 86400 + DailyOpenHour * 3600);
   if(now < anchor) anchor -= 86400;

   for(int d = 0; d < 7; d++)                       // walk back over weekends/holidays
   {
      datetime a  = anchor - d * 86400;
      int      sh = iBarShift(Symbol(), PERIOD_H1, a, false);
      if(sh < 0) continue;
      if(iTime(Symbol(), PERIOD_H1, sh) < a) sh--;   // bar at or after the open hour
      if(sh < 0) continue;
      datetime t = iTime(Symbol(), PERIOD_H1, sh);
      if(t == 0 || t >= a + 86400) continue;         // no bar that day
      barTime = t;
      price   = iOpen(Symbol(), PERIOD_H1, sh);
      return price > 0;
   }
   return false;
}

void UpdateDailyPct()
{
   if(!g_dpOn)
   {
      if(g_dpAnchor != 0 || ObjectFind(0, DP_PFX + "100") >= 0)
      {
         ObjectsDeleteAll(0, DP_PFX);
         g_dpAnchor = 0;
      }
      return;
   }

   datetime t; double open;
   if(!FindDayOpen(t, open)) return;                 // H1 history not loaded yet - retry next tick
   if(t == g_dpAnchor && MathAbs(open - g_dpOpen) < Point / 2) return;   // nothing changed

   ObjectsDeleteAll(0, DP_PFX);
   g_dpAnchor = t;
   g_dpOpen   = open;

   int    cnt = MathMax(1, DailyPctCount);
   int    pd  = (MathAbs(DailyPctStep - MathRound(DailyPctStep)) < 1e-9) ? 0 : 2;
   for(int k = -cnt; k <= cnt; k++)
   {
      double lvl  = NormalizeDouble(open * (1.0 + k * DailyPctStep / 100.0), Digits);
      string name = DP_PFX + IntegerToString(k + 100);
      string txt  = (k == 0) ? "0%  Daily open " + DoubleToString(lvl, Digits)
                             : (k > 0 ? "+" : "") + DoubleToString(k * DailyPctStep, pd) + "%  " +
                               DoubleToString(lvl, Digits);

      if(DailyPctFullWidth)
         ObjectCreate(0, name, OBJ_HLINE, 0, 0, lvl);
      else
      {
         ObjectCreate(0, name, OBJ_TREND, 0, t, lvl, t + 3600, lvl);
         ObjectSetInteger(0, name, OBJPROP_RAY, true);
      }
      ObjectSetInteger(0, name, OBJPROP_COLOR, DailyPctColor);
      ObjectSetInteger(0, name, OBJPROP_STYLE, k == 0 ? STYLE_SOLID : STYLE_DOT);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, k == 0 ? 2 : 1);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
      ObjectSetString(0, name, OBJPROP_TEXT, txt);

      string tn = name + "_t";
      ObjectCreate(0, tn, OBJ_TEXT, 0, t, lvl);
      ObjectSetInteger(0, tn, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, tn, OBJPROP_COLOR, DailyPctColor);
      ObjectSetInteger(0, tn, OBJPROP_FONTSIZE, FontSize);
      ObjectSetString(0, tn, OBJPROP_FONT, "Arial");
      ObjectSetString(0, tn, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, tn, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, tn, OBJPROP_HIDDEN, true);
   }
   Print("Daily % lines anchored at ", TimeToString(t), " server time, open ", DoubleToString(open, Digits));
}

void UpdateDpBtn()
{
   ObjectSetString(0, BTN_DPCT, OBJPROP_TEXT, g_dpOn ? "Daily %: ON" : "Daily %: OFF");
   ObjectSetInteger(0, BTN_DPCT, OBJPROP_BGCOLOR, g_dpOn ? clrDarkGreen : clrDimGray);
   ObjectSetInteger(0, BTN_DPCT, OBJPROP_STATE, false);
}

void CreateEdit(string name, string txt, int x, int y, int w)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrBlack);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrDarkOrange);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Drawing                                                          |
//+------------------------------------------------------------------+
void DrawLevel(string name, double price, color c, ENUM_LINE_STYLE st, string txt)
{
   string t = name + "_t";
   if(price <= 0)
   {
      ObjectDelete(0, name);
      ObjectDelete(0, t);
      return;
   }

   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, c);
      ObjectSetInteger(0, name, OBJPROP_STYLE, st);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, LineWidth);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   else if(MathAbs(ObjectGetDouble(0, name, OBJPROP_PRICE) - price) > Point / 2)
      ObjectMove(0, name, 0, 0, price);
   ObjectSetString(0, name, OBJPROP_TEXT, txt);

   if(ObjectFind(0, t) < 0)
   {
      ObjectCreate(0, t, OBJ_TEXT, 0, Time[0], price);
      ObjectSetInteger(0, t, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, t, OBJPROP_COLOR, c);
      ObjectSetInteger(0, t, OBJPROP_FONTSIZE, FontSize);
      ObjectSetString(0, t, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, t, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, t, OBJPROP_HIDDEN, true);
   }
   else
      ObjectMove(0, t, 0, Time[0], price);
   ObjectSetString(0, t, OBJPROP_TEXT, txt);
}

void SetLabel(int row, string txt, color c)
{
   string name = LBL + IntegerToString(row);
   if(ObjectFind(0, name) < 0)
   {
      ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 128 - row * 16);
      ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
      ObjectSetString(0, name, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetString(0, name, OBJPROP_TEXT, (txt == "" ? " " : txt));
}

void CreateButton(string name, string txt, int x, int y, int w, color bg = clrSteelBlue)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_LOWER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 22);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, FontSize);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void UpdateAutoBtn()
{
   ObjectSetString(0, BTN_AUTO, OBJPROP_TEXT, g_auto ? "Auto TP: ON" : "Auto TP: OFF");
   ObjectSetInteger(0, BTN_AUTO, OBJPROP_BGCOLOR, g_auto ? clrSeaGreen : clrDimGray);
   ObjectSetInteger(0, BTN_AUTO, OBJPROP_STATE, false);
}
//+------------------------------------------------------------------+
