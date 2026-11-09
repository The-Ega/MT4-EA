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
input int             GameOverLineWidth = 3;              // Width of the red "GAME OVER" margin line
input double          CustomMLDefault   = 200.0;          // Custom margin level line: default %
input color           CustomMLColor     = clrGold;        // Custom margin level line: color
input ENUM_LINE_STYLE CustomMLStyle     = STYLE_DASHDOT;  // Custom margin level line: style
input int             CloseLastNDefault = 1;              // "Close Last N": default number of orders
input double          RiskUSDDefault    = 100.0;          // Risk Tool: default risk (account currency)
input bool            RiskStartPending  = false;          // Risk Tool: start in PENDING mode (false = MARKET)
input bool            RiskConfirmDefault= true;           // Risk Tool: confirmation window ON at start
input double          RiskCommPerLot    = 0.0;            // Risk Tool: round-turn commission per lot (included in risk)
input int             RiskMagic         = 0;              // Risk Tool: magic number (used if MagicFilter = -1)
input double          RiskInitDistPct   = 0.5;            // Risk Tool: initial SL distance from price (%)
input color           RiskSLColor       = clrRed;         // Risk Tool: SL line color
input color           RiskEntryColor    = clrDarkTurquoise; // Risk Tool: entry line color (pending mode)
input int             DailyOpenHour     = 1;              // Daily % : day open hour (MT4 server time)
input double          DailyPctStep      = 1.0;            // Daily % : step between lines (%)
input int             DailyPctCount     = 7;              // Daily % : number of lines above and below
input color           DailyPctColor     = clrDarkGreen;   // Daily % : line color
input bool            DailyPctFullWidth = false;          // Daily % : full-width lines (false = start at day open)

//--- NY Levels (from NY_Session_Levels script) ----------------------
enum NY_LABEL_SIDE { NYL_LEFT = 0, NYL_RIGHT = 1 };
input string          NY_Settings        = "------ NY Levels ------";
input int             NY_To_Server_Hours = 7;             // NY Levels: server time = NY time + hours
input int             NY_DaysToLookBack  = 7;             // NY Levels: NY calendar days back (0 = today)
input string          NY_ON_Start        = "00:00";       // NY Levels: Overnight range start (NY)
input string          NY_ON_End          = "05:00";       // NY Levels: Overnight range end (NY)
input string          NY_PM_Start        = "07:00";       // NY Levels: PreMarket range start (NY)
input string          NY_PM_End          = "09:00";       // NY Levels: PreMarket range end (NY)
input string          NY_MidnightOpen    = "00:00";       // NY Levels: Midnight open time (NY)
input string          NY_PrevClose       = "16:14";       // NY Levels: Prev day close candle (NY)
input string          NY_ExtOpen         = "18:00";       // NY Levels: Extended hour open (NY)
input color           NY_ON_Color        = clrDodgerBlue; // NY Levels: Overnight color
input color           NY_PM_Color        = clrOrange;     // NY Levels: PreMarket color
input color           NY_Midnight_Color  = clrMagenta;    // NY Levels: Midnight open color
input color           NY_PrevClose_Color = clrRed;        // NY Levels: Prev close color
input color           NY_ExtOpen_Color   = clrLime;       // NY Levels: Extended open color
input int             NY_LineWidth       = 1;             // NY Levels: line width
input ENUM_LINE_STYLE NY_LineStyle       = STYLE_SOLID;   // NY Levels: line style
input bool            NY_ShowLabels      = true;          // NY Levels: show labels
input NY_LABEL_SIDE   NY_LabelSide       = NYL_RIGHT;     // NY Levels: label side
input int             NY_LabelBarsAhead  = 3;             // NY Levels: live labels, bars right of last candle
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
#define BTN_NY    "BEML_BtnNYLevels"
#define LN_CML     "BEML_CML"
#define EDT_CML    "BEML_EdtCML"
#define BTN_CML    "BEML_BtnCML"
#define BTN_CMLAUTO "BEML_BtnCMLAuto"
#define EDT_LASTN  "BEML_EdtLastN"
#define BTN_LASTN  "BEML_BtnLastN"
#define BTN_RISK   "BEML_BtnRisk"
#define BTN_RMODE  "BEML_BtnRiskMode"
#define EDT_RISK   "BEML_EdtRisk"
#define BTN_RTRADE "BEML_BtnRiskTrade"
#define BTN_RCONF  "BEML_BtnRiskConfirm"
#define R_PFX      "BEML_R_"
#define LN_RSL     "BEML_R_SL"
#define LN_RENT    "BEML_R_ENT"
#define NY_PFX    "BEML_NY_"
#define NY_TOL    600                     // max data gap tolerance (seconds)

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

bool     g_nyOn        = false;   // NY Levels visible
bool     g_nyValid     = false;   // inputs parsed OK
bool     g_nyWarned    = false;   // "not enough M1 history" already printed
datetime g_nyLastBar   = 0;       // M1 bar of last redraw
int      m_ONs, m_ONe, m_PMs, m_PMe, m_Mid, m_Close, m_Ext;

string NyGVName() { return "BEML_NYON_" + IntegerToString(ChartID()); }

double g_cmlPct        = 200.0;   // custom margin level % (on-chart box)
double g_cmlBid        = 0;       // custom margin level line (Bid price), 0 = none
bool   g_mlAuto        = false;   // auto-follow custom ML line with SL/TP
uint   g_lastMLAttempt = 0;
double g_V             = 0;       // money per 1.0 price move (last Recalc), used for dragging
int    g_lastN         = 1;       // "Close Last N" box value

//--- Risk Tool state
bool   g_riskOn      = false;
bool   g_riskPending = false;
double g_riskUSD     = 100.0;
bool   g_riskConfirm = true;      // show confirmation window before sending
double g_rslSaved    = 0;         // last SL line price (survives timeframe change)
double g_rentSaved   = 0;         // last entry line price
// result of RiskCalc()
int    g_rType  = -1;             // OP_BUY..OP_SELLSTOP, -1 = invalid
double g_rLots  = 0, g_rRisk = 0, g_rEntry = 0, g_rSL = 0;
string g_rErr   = "";

string PctStr(double p) { return DoubleToString(p, MathAbs(p - MathRound(p)) < 1e-9 ? 0 : 1); }

// is this margin level at/below the broker's stop-out (only when stop-out is in %)
bool BelowStopout(double pct)
{
   return AccountStopoutMode() == 0 && pct <= AccountStopoutLevel();
}

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
   CreateButton(BTN_NY,   "", 295, 58, 95);
   g_nyValid    = NY_ParseAll();
   g_nyOn       = g_nyValid && GlobalVariableCheck(NyGVName()) && GlobalVariableGet(NyGVName()) > 0;
   g_nyLastBar  = 0;
   UpdateNyBtn();
   // 3rd row: [ML % box] [Set ML SL/TP] [ML Auto]
   g_cmlPct = (CustomMLDefault > 0) ? CustomMLDefault : 200.0;
   CreateEdit(EDT_CML, PctStr(g_cmlPct), 10, 86, 90);
   ObjectSetInteger(0, EDT_CML, OBJPROP_BORDER_COLOR, CustomMLColor);
   CreateButton(BTN_CML,     "Set ML SL/TP", 105, 86, 95, clrGoldenrod);
   CreateButton(BTN_CMLAUTO, "",             205, 86, 95);
   UpdateMlAutoBtn();
   // [N box] [Close Last N]
   g_lastN = MathMax(1, CloseLastNDefault);
   CreateEdit(EDT_LASTN, IntegerToString(g_lastN), 310, 86, 50);
   ObjectSetInteger(0, EDT_LASTN, OBJPROP_BORDER_COLOR, clrCrimson);
   CreateButton(BTN_LASTN, "Close Last N", 365, 86, 95, clrCrimson);
   // 4th row: [Risk Tool] [Mode] [risk USD] [BUY 0.37]
   if(g_riskUSD <= 0 || !g_riskOn) g_riskUSD = (RiskUSDDefault > 0) ? RiskUSDDefault : 100.0;
   if(!g_riskOn) g_riskPending = RiskStartPending;
   CreateButton(BTN_RISK,   "", 10,  114, 90);
   CreateButton(BTN_RMODE,  "", 105, 114, 95);
   CreateEdit(EDT_RISK, DoubleToString(g_riskUSD, 2), 205, 114, 70);
   ObjectSetInteger(0, EDT_RISK, OBJPROP_BORDER_COLOR, RiskSLColor);
   CreateButton(BTN_RTRADE, "", 280, 114, 130);
   CreateButton(BTN_RCONF,  "", 415, 114, 95);
   // keep the user's choice on timeframe/symbol change, otherwise use the input
   if(UninitializeReason() != REASON_CHARTCHANGE) g_riskConfirm = RiskConfirmDefault;
   UpdateRiskBtns();
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
   if(reason == REASON_REMOVE) { GlobalVariableDel(DpGVName()); GlobalVariableDel(NyGVName()); }
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
   //--- gold margin-level line dragged -> work out the new margin level %
   //--- Risk Tool lines dragged
   if(id == CHARTEVENT_OBJECT_DRAG && (sparam == LN_RSL || sparam == LN_RENT))
   {
      ObjectSetInteger(0, sparam, OBJPROP_SELECTED, false);
      Recalc();
      return;
   }
   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == EDT_RISK)
   {
      double v = StringToDouble(ObjectGetString(0, EDT_RISK, OBJPROP_TEXT));
      if(v > 0) g_riskUSD = v;
      ObjectSetString(0, EDT_RISK, OBJPROP_TEXT, DoubleToString(g_riskUSD, 2));
      Recalc();
      return;
   }
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_RISK)
   {
      g_riskOn = !g_riskOn;
      if(!g_riskOn)
      {
         ObjectsDeleteAll(0, R_PFX);
         g_rslSaved = 0; g_rentSaved = 0;     // next ON starts near current price
      }
      Recalc();
      return;
   }
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_RMODE)
   {
      g_riskPending = !g_riskPending;
      if(!g_riskPending)
      {
         ObjectDelete(0, LN_RENT);
         ObjectDelete(0, LN_RENT + "_t");
         g_rentSaved = 0;
      }
      Recalc();
      return;
   }
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_RCONF)
   {
      if(g_riskConfirm)
      {
         string w = "Turn OFF the Risk Tool confirmation?\n\n" +
                    "Orders will be sent with ONE CLICK on the trade button, without confirmation.\n" +
                    "Safety checks (risk, stop level, margin) still apply.\n\nContinue?";
         if(MessageBox(w, "One-click trading", MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2) == IDYES)
            g_riskConfirm = false;
      }
      else g_riskConfirm = true;
      UpdateRiskBtns();
      ChartRedraw();
      return;
   }
   if(id == CHARTEVENT_OBJECT_CLICK && sparam == BTN_RTRADE)
   {
      ObjectSetInteger(0, BTN_RTRADE, OBJPROP_STATE, false);
      ChartRedraw();
      if(g_riskOn) RiskTrade();
      Recalc();
      return;
   }
   if(id == CHARTEVENT_OBJECT_DRAG && sparam == LN_CML)
   {
      double p = ObjectGetDouble(0, LN_CML, OBJPROP_PRICE);
      ObjectSetInteger(0, LN_CML, OBJPROP_SELECTED, false);
      RefreshRates();
      double M = AccountMargin();
      if(MathAbs(g_V) > 1e-12 && M > 0)
      {
         double eq  = AccountEquity() + g_V * (p - Bid);   // equity if price were at p
         double pct = eq / M * 100.0;
         if(eq <= 0)
            Alert("Margin level line: equity would be zero or negative at that price - line moved back.");
         else
         {
            g_cmlPct = NormalizeDouble(pct, 1);
            ObjectSetString(0, EDT_CML, OBJPROP_TEXT, PctStr(g_cmlPct));
            if(BelowStopout(g_cmlPct))
               Alert("Margin level ", PctStr(g_cmlPct), "% is at/below broker stop-out (",
                     DoubleToString(AccountStopoutLevel(), 0), "%). Positions would be stopped out first.");
         }
      }
      Recalc();          // snaps line/label to the (new) level
      return;
   }
   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == EDT_CML)
   {
      double v = StringToDouble(ObjectGetString(0, EDT_CML, OBJPROP_TEXT));
      if(v > 0) g_cmlPct = v;
      ObjectSetString(0, EDT_CML, OBJPROP_TEXT, PctStr(g_cmlPct));
      if(BelowStopout(g_cmlPct))
         Alert("Margin level ", PctStr(g_cmlPct), "% is at/below broker stop-out (",
               DoubleToString(AccountStopoutLevel(), 0), "%). Positions would be stopped out first.");
      Recalc();
      return;
   }
   if(id == CHARTEVENT_OBJECT_ENDEDIT && sparam == EDT_LASTN)
   {
      int v = (int)StringToInteger(ObjectGetString(0, EDT_LASTN, OBJPROP_TEXT));
      if(v > 0) g_lastN = v;
      ObjectSetString(0, EDT_LASTN, OBJPROP_TEXT, IntegerToString(g_lastN));   // reset invalid input
      ChartRedraw();
      return;
   }
   if(id != CHARTEVENT_OBJECT_CLICK) return;
   if(sparam == BTN_LASTN)
   {
      ObjectSetInteger(0, BTN_LASTN, OBJPROP_STATE, false);
      ChartRedraw();
      CloseLastN();
      Recalc();
      return;
   }
   if(sparam == BTN_CML)
   {
      ObjectSetInteger(0, BTN_CML, OBJPROP_STATE, false);
      SetMLSLTP(true);
      Recalc();
      return;
   }
   if(sparam == BTN_CMLAUTO)
   {
      g_mlAuto = !g_mlAuto;
      if(g_mlAuto)
      {
         if(g_auto) { g_auto = false; UpdateAutoBtn(); }   // both would fight over TPs
         if(BelowStopout(g_cmlPct))
            Alert("Warning: ", PctStr(g_cmlPct), "% is at/below broker stop-out level.");
      }
      UpdateMlAutoBtn();
      Recalc();
      return;
   }
   if(sparam == BTN_DPCT)
   {
      g_dpOn = !g_dpOn;
      GlobalVariableSet(DpGVName(), g_dpOn ? 1 : 0);
      UpdateDpBtn();
      g_dpAnchor = 0;               // force redraw / delete
      Recalc();
      return;
   }
   if(sparam == BTN_NY)
   {
      if(!g_nyOn && !g_nyValid)
         Alert("NY Levels: invalid time inputs. Use HH:MM and make range end later than start.");
      else
      {
         g_nyOn = !g_nyOn;
         GlobalVariableSet(NyGVName(), g_nyOn ? 1 : 0);
         ObjectsDeleteAll(0, NY_PFX);
         g_nyLastBar = 0;            // force redraw
         g_nyWarned  = false;
      }
      UpdateNyBtn();
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
      if(g_mlAuto) { g_mlAuto = false; UpdateMlAutoBtn(); }
      SetTPs(true);
      ObjectSetInteger(0, BTN_SET, OBJPROP_STATE, false);
   }
   else if(sparam == BTN_AUTO)
   {
      g_auto = !g_auto;
      if(g_auto && g_mlAuto) { g_mlAuto = false; UpdateMlAutoBtn(); }
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
   g_V = V;
   double E = AccountEquity();
   double B = AccountBalance();
   double M = AccountMargin();

   g_beBid  = 0;
   g_mlBid  = 0;
   g_cmlBid = 0;
   bool hedged = (nSym > 0 && MathAbs(netLots) < 1e-8);

   if(nSym > 0 && MathAbs(V) > 1e-12)
   {
      double be = Bid + (B - E) / V;
      if(be > 0) g_beBid = be;

      if(M > 0)
      {
         double ml = Bid + (MarginLevelTarget / 100.0 * M - E) / V;
         if(ml > 0) g_mlBid = ml;

         double cml = Bid + (g_cmlPct / 100.0 * M - E) / V;
         if(cml > 0) g_cmlBid = cml;
      }
   }

   //--- lines
   double pip = PipSize();
   DrawLevel(LN_BE, g_beBid, BEColor, BEStyle,
             "Equity = Balance  " + DoubleToString(g_beBid, Digits) +
             "  (" + Sgn((g_beBid - Bid) / pip, 1) + " pips)");
   DrawLevel(LN_ML, g_mlBid, MLColor, MLStyle,
             "GAME OVER  " + PctStr(MarginLevelTarget) + "%  " +
             DoubleToString(g_mlBid, Digits) +
             "  (" + Sgn((g_mlBid - Bid) / pip, 1) + " pips)",
             GameOverLineWidth, "Arial Black");

   double cmlEq = g_cmlPct / 100.0 * M;                // equity at the custom level
   DrawLevel(LN_CML, g_cmlBid, CustomMLColor, CustomMLStyle,
             "ML " + PctStr(g_cmlPct) + "%  " + DoubleToString(g_cmlBid, Digits) +
             "   Equity " +
             DoubleToString(cmlEq, 2) + " (" + Sgn(cmlEq - E, 2) + ")" +
             (BelowStopout(g_cmlPct) ? "   BELOW STOP-OUT!" : ""));
   if(ObjectFind(0, LN_CML) >= 0)                       // gold line can be dragged
      ObjectSetInteger(0, LN_CML, OBJPROP_SELECTABLE, true);

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

   //--- NY levels (redrawn once per new M1 bar)
   UpdateNYLevels();

   //--- risk tool lines / lot size
   RiskUpdate();

   //--- auto TP (throttled)
   if(g_auto && g_beBid > 0 && GetTickCount() - g_lastTPAttempt >= 2000)
      SetTPs(false);

   //--- auto-follow custom ML line (throttled)
   if(g_mlAuto && g_cmlBid > 0 && GetTickCount() - g_lastMLAttempt >= 2000)
      SetMLSLTP(false);

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
//| Risk Tool: lot size from a fixed money risk and a draggable SL   |
//| MARKET : SL below price = BUY, above = SELL                      |
//| PENDING: SL below entry = BUY, above = SELL; LIMIT/STOP is       |
//|          chosen from where the entry line sits vs. price         |
//+------------------------------------------------------------------+
string OTName(int t)
{
   switch(t)
   {
      case OP_BUY:       return "BUY";
      case OP_SELL:      return "SELL";
      case OP_BUYLIMIT:  return "BUY LIMIT";
      case OP_SELLLIMIT: return "SELL LIMIT";
      case OP_BUYSTOP:   return "BUY STOP";
      case OP_SELLSTOP:  return "SELL STOP";
   }
   return "?";
}

int RiskMagicNo() { return (MagicFilter >= 0) ? MagicFilter : RiskMagic; }

void RiskLine(string name, double price, color c, int width)
{
   if(ObjectFind(0, name) >= 0) return;               // user owns the position once created
   ObjectCreate(0, name, OBJ_HLINE, 0, 0, NormalizeDouble(price, Digits));
   ObjectSetInteger(0, name, OBJPROP_COLOR, c);
   ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void RiskLabel(string name, double price, string txt, color c)
{
   string t = name + "_t";
   int    sh = MathMin(15, Bars - 1);                   // a bit left of the current bar
   if(ObjectFind(0, t) < 0)
   {
      ObjectCreate(0, t, OBJ_TEXT, 0, Time[sh], price);
      ObjectSetInteger(0, t, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, t, OBJPROP_FONTSIZE, FontSize);
      ObjectSetString(0, t, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, t, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, t, OBJPROP_HIDDEN, true);
   }
   else
      ObjectMove(0, t, 0, Time[sh], price);
   ObjectSetInteger(0, t, OBJPROP_COLOR, c);
   ObjectSetString(0, t, OBJPROP_TEXT, txt);
}

// fills g_rType, g_rLots, g_rRisk, g_rEntry, g_rSL, g_rErr from the lines
void RiskCalc()
{
   g_rType = -1; g_rLots = 0; g_rRisk = 0; g_rEntry = 0; g_rErr = "";
   g_rSL = NormalizeDouble(ObjectGetDouble(0, LN_RSL, OBJPROP_PRICE), Digits);
   double stop = MarketInfo(Symbol(), MODE_STOPLEVEL) * Point;
   double dist;
   bool   isBuy;

   if(g_riskPending)
   {
      g_rEntry = NormalizeDouble(ObjectGetDouble(0, LN_RENT, OBJPROP_PRICE), Digits);
      isBuy = (g_rSL < g_rEntry);
      if(isBuy) g_rType = (g_rEntry < Ask) ? OP_BUYLIMIT  : OP_BUYSTOP;
      else      g_rType = (g_rEntry > Bid) ? OP_SELLLIMIT : OP_SELLSTOP;
      dist = MathAbs(g_rEntry - g_rSL);

      double gap = (g_rType == OP_BUYLIMIT)  ? Ask - g_rEntry :
                   (g_rType == OP_BUYSTOP)   ? g_rEntry - Ask :
                   (g_rType == OP_SELLLIMIT) ? g_rEntry - Bid : Bid - g_rEntry;
      if(gap < stop) { g_rErr = "Entry too close to price"; return; }
   }
   else
   {
      isBuy    = (g_rSL < Bid);
      g_rType  = isBuy ? OP_BUY : OP_SELL;
      g_rEntry = isBuy ? Ask : Bid;
      dist     = isBuy ? Ask - g_rSL : g_rSL - Bid;     // spread included
      double gap = isBuy ? Bid - g_rSL : g_rSL - Ask;
      if(gap <= 0)   { g_rErr = "SL inside the spread"; return; }
      if(gap < stop) { g_rErr = "SL too close to price"; return; }
   }
   if(dist <= 0)    { g_rErr = "SL equals entry"; return; }
   if(dist < stop)  { g_rErr = "SL too close to entry"; return; }

   double tv = MarketInfo(Symbol(), MODE_TICKVALUE);
   double ts = MarketInfo(Symbol(), MODE_TICKSIZE);
   if(tv <= 0 || ts <= 0) { g_rErr = "No tick value"; return; }

   double perLot = dist * tv / ts + RiskCommPerLot;      // money lost per 1 lot at SL
   double step   = MarketInfo(Symbol(), MODE_LOTSTEP);
   double minl   = MarketInfo(Symbol(), MODE_MINLOT);
   double maxl   = MarketInfo(Symbol(), MODE_MAXLOT);
   if(step <= 0) step = 0.01;

   double lots = MathFloor(g_riskUSD / perLot / step + 1e-9) * step;   // round DOWN
   lots = NormalizeDouble(MathMin(lots, maxl), 2);
   if(lots < minl)
   {
      g_rErr = "Risk too small (min " + DoubleToString(minl, 2) + " lot = " +
               DoubleToString(minl * perLot, 2) + ")";
      return;
   }
   g_rLots = lots;
   g_rRisk = lots * perLot;
}

void RiskUpdate()
{
   UpdateRiskBtns();
   if(!g_riskOn) return;

   double pct = MathMax(0.05, RiskInitDistPct) / 100.0;
   // create lines (re-use last positions after a timeframe change)
   double sl0 = (g_rslSaved > 0) ? g_rslSaved : Bid * (1.0 - (g_riskPending ? 2 * pct : pct));
   RiskLine(LN_RSL, sl0, RiskSLColor, 2);
   if(g_riskPending)
   {
      double sl  = ObjectGetDouble(0, LN_RSL, OBJPROP_PRICE);
      double en0 = (g_rentSaved > 0) ? g_rentSaved : (Bid + sl) / 2.0;
      RiskLine(LN_RENT, en0, RiskEntryColor, 2);
   }
   g_rslSaved = ObjectGetDouble(0, LN_RSL, OBJPROP_PRICE);
   if(g_riskPending) g_rentSaved = ObjectGetDouble(0, LN_RENT, OBJPROP_PRICE);

   RiskCalc();

   string slTxt = "RISK SL " + DoubleToString(g_rSL, Digits) + "  |  ";
   if(g_rErr != "") slTxt += g_rErr;
   else slTxt += OTName(g_rType) + " " + DoubleToString(g_rLots, 2) + " lots  |  Risk " +
                 DoubleToString(g_rRisk, 2) + " " + AccountCurrency();
   RiskLabel(LN_RSL, g_rSL, slTxt, RiskSLColor);

   if(g_riskPending && ObjectFind(0, LN_RENT) >= 0)
      RiskLabel(LN_RENT, g_rEntry, "ENTRY " + DoubleToString(g_rEntry, Digits) +
                (g_rType >= 0 ? "  (" + OTName(g_rType) + ")" : ""), RiskEntryColor);

   UpdateRiskBtns();
}

void UpdateRiskBtns()
{
   ObjectSetString(0, BTN_RISK, OBJPROP_TEXT, g_riskOn ? "Risk Tool: ON" : "Risk Tool: OFF");
   ObjectSetInteger(0, BTN_RISK, OBJPROP_BGCOLOR, g_riskOn ? clrSteelBlue : clrDimGray);
   ObjectSetInteger(0, BTN_RISK, OBJPROP_STATE, false);

   ObjectSetString(0, BTN_RMODE, OBJPROP_TEXT, g_riskPending ? "Mode: PENDING" : "Mode: MARKET");
   ObjectSetInteger(0, BTN_RMODE, OBJPROP_BGCOLOR, g_riskPending ? clrDarkTurquoise : clrSlateGray);
   ObjectSetInteger(0, BTN_RMODE, OBJPROP_STATE, false);

   ObjectSetString(0, BTN_RCONF, OBJPROP_TEXT, g_riskConfirm ? "Confirm: ON" : "Confirm: OFF");
   ObjectSetInteger(0, BTN_RCONF, OBJPROP_BGCOLOR, g_riskConfirm ? clrSeaGreen : clrDarkOrange);
   ObjectSetInteger(0, BTN_RCONF, OBJPROP_STATE, false);

   string txt; color bg;
   if(!g_riskOn)          { txt = "-";                                       bg = clrDimGray; }
   else if(g_rErr != "" || g_rType < 0) { txt = "Can't trade";               bg = clrDimGray; }
   else
   {
      txt = OTName(g_rType) + " " + DoubleToString(g_rLots, 2);
      bg  = (g_rType % 2 == 0) ? clrSeaGreen : clrCrimson;   // buys even, sells odd
   }
   ObjectSetString(0, BTN_RTRADE, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, BTN_RTRADE, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, BTN_RTRADE, OBJPROP_STATE, false);
}

void RiskTrade()
{
   RefreshRates();
   RiskCalc();
   if(g_rErr != "" || g_rType < 0)
   {
      Alert("Risk Tool: ", (g_rErr != "" ? g_rErr : "invalid order"));
      return;
   }

   bool market = (g_rType == OP_BUY || g_rType == OP_SELL);
   string msg = OTName(g_rType) + "  " + Symbol() + "\n\n" +
                "Lots:   " + DoubleToString(g_rLots, 2) + "\n" +
                "Entry:  " + (market ? "market (~" + DoubleToString(g_rEntry, Digits) + ")"
                                     : DoubleToString(g_rEntry, Digits)) + "\n" +
                "SL:     " + DoubleToString(g_rSL, Digits) + "\n" +
                "TP:     none\n\n" +
                "Risk:   " + DoubleToString(g_rRisk, 2) + " " + AccountCurrency() +
                "  (limit " + DoubleToString(g_riskUSD, 2) + ")\n" +
                (market ? "\nSlippage may change the actual risk slightly.\n" : "") +
                "\nSend this order?";
   if(g_riskConfirm &&
      MessageBox(msg, "Confirm Risk Tool order", MB_YESNO | MB_ICONQUESTION | MB_DEFBUTTON2) != IDYES)
      return;

   if(!IsTradeAllowed())
   {
      Alert("Trading not allowed - enable AutoTrading / 'Allow live trading'.");
      return;
   }

   // price may have moved while the window was open -> recalculate
   RefreshRates();
   RiskCalc();
   if(g_rErr != "" || g_rType < 0)
   {
      Alert("Risk Tool: price moved - ", g_rErr, ". Order not sent.");
      return;
   }
   market = (g_rType == OP_BUY || g_rType == OP_SELL);

   ResetLastError();
   if(AccountFreeMarginCheck(Symbol(), (g_rType % 2 == 0) ? OP_BUY : OP_SELL, g_rLots) <= 0 ||
      GetLastError() == ERR_NOT_ENOUGH_MONEY)
   {
      Alert("Risk Tool: not enough free margin for ", DoubleToString(g_rLots, 2), " lots.");
      return;
   }

   double price = market ? ((g_rType == OP_BUY) ? Ask : Bid) : g_rEntry;
   int ticket = OrderSend(Symbol(), g_rType, g_rLots, NormalizeDouble(price, Digits), Slippage,
                          g_rSL, 0, "RiskTool", RiskMagicNo(), 0, clrNONE);
   int err = (ticket < 0) ? GetLastError() : 0;

   // some brokers (market execution) refuse SL on a market order: send, then add SL
   if(ticket < 0 && market && err == ERR_INVALID_STOPS)
   {
      RefreshRates();
      price  = (g_rType == OP_BUY) ? Ask : Bid;
      ticket = OrderSend(Symbol(), g_rType, g_rLots, NormalizeDouble(price, Digits), Slippage,
                         0, 0, "RiskTool", RiskMagicNo(), 0, clrNONE);
      if(ticket < 0) err = GetLastError();
      if(ticket >= 0 && OrderSelect(ticket, SELECT_BY_TICKET))
         if(!OrderModify(ticket, OrderOpenPrice(), g_rSL, 0, 0, clrNONE))
            Alert("Risk Tool: order #", ticket, " opened but SL could not be set (err ",
                  GetLastError(), "). SET IT MANUALLY!");
   }

   if(ticket < 0)
   {
      Alert("Risk Tool: OrderSend failed, err ", err);
      return;
   }
   Print("Risk Tool: ", OTName(g_rType), " ", DoubleToString(g_rLots, 2), " ", Symbol(),
         " #", ticket, " SL ", DoubleToString(g_rSL, Digits), " risk ~",
         DoubleToString(g_rRisk, 2), " ", AccountCurrency());
}

//+------------------------------------------------------------------+
//| Close Last N: close the N most recently opened positions         |
//| (newest open time first, higher ticket wins a tie)               |
//+------------------------------------------------------------------+
void CloseLastN()
{
   // collect positions in scope
   int      tk[];
   datetime tm[];
   int cnt = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!InCloseScope()) continue;
      ArrayResize(tk, cnt + 1);
      ArrayResize(tm, cnt + 1);
      tk[cnt] = OrderTicket();
      tm[cnt] = OrderOpenTime();
      cnt++;
   }

   string scope = CloseAllSymbols ? "ALL symbols" : Symbol();
   if(cnt == 0)
   {
      Alert("Close Last N: no open positions on ", scope, ".");
      return;
   }

   // sort newest first
   for(int a = 0; a < cnt - 1; a++)
      for(int b = a + 1; b < cnt; b++)
         if(tm[b] > tm[a] || (tm[b] == tm[a] && tk[b] > tk[a]))
         {
            datetime t0 = tm[a]; tm[a] = tm[b]; tm[b] = t0;
            int      k0 = tk[a]; tk[a] = tk[b]; tk[b] = k0;
         }

   int n = MathMin(g_lastN, cnt);

   // confirmation window listing what will close
   string list = "";
   double total = 0;
   int    shown = 0;
   for(int j = 0; j < n; j++)
   {
      if(!OrderSelect(tk[j], SELECT_BY_TICKET)) continue;
      double pl = NetProfit();
      total += pl;
      if(shown < 15)
      {
         int dg = (int)MarketInfo(OrderSymbol(), MODE_DIGITS);
         list += "#" + IntegerToString(OrderTicket()) + "  " +
                 (CloseAllSymbols ? OrderSymbol() + " " : "") +
                 (OrderType() == OP_BUY ? "BUY " : "SELL") + "  " +
                 DoubleToString(OrderLots(), 2) + "  @ " + DoubleToString(OrderOpenPrice(), dg) +
                 "   P/L " + Sgn(pl, 2) + "\n";
         shown++;
      }
   }
   if(n > shown) list += "... and " + IntegerToString(n - shown) + " more\n";

   string msg = "Close the " + IntegerToString(n) + " most recent position(s) on " + scope + "?";
   if(g_lastN > cnt)
      msg += "\n(You asked for " + IntegerToString(g_lastN) + ", only " + IntegerToString(cnt) + " open.)";
   msg += "\n\n" + list + "\nTotal P/L: " + Sgn(total, 2) + " " + AccountCurrency() +
          "\n\nThis cannot be undone.";

   if(MessageBox(msg, "Confirm Close Last N", MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2) != IDYES)
      return;

   if(!IsTradeAllowed())
   {
      Alert("Trading not allowed - enable AutoTrading / 'Allow live trading'.");
      return;
   }

   int closed = 0, failed = 0;
   double realized = 0;
   for(int j = 0; j < n; j++)
   {
      if(!OrderSelect(tk[j], SELECT_BY_TICKET) || OrderCloseTime() != 0) continue;
      double pl = NetProfit();
      if(CloseWithRetry(tk[j], OrderLots())) { closed++; realized += pl; }
      else failed++;
   }

   string res = "Close Last N: closed " + IntegerToString(closed) + " of " + IntegerToString(n) +
                ", approx P/L " + DoubleToString(realized, 2) + " " + AccountCurrency();
   if(failed > 0) res += ", FAILED " + IntegerToString(failed) + " (see Experts log)";
   Print(res);
   if(failed > 0) Alert(res);
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
   if(g_mlAuto)
   {
      g_mlAuto = false;
      UpdateMlAutoBtn();
      Print("ML Auto switched OFF because fixed TP was set.");
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
      ObjectSetInteger(0, name, OBJPROP_XDISTANCE, 400);
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

//+------------------------------------------------------------------+
//| NY Levels (ported from NY_Session_Levels script)                 |
//| Overnight & PreMarket high/low, Midnight open, Prev close,       |
//| Extended hour open. Draw only - never touches orders.            |
//+------------------------------------------------------------------+
int NY_ParseHM(string s)
{
   StringTrimLeft(s); StringTrimRight(s);
   int p = StringFind(s, ":");
   if(p < 1) return -1;
   int h = (int)StringToInteger(StringSubstr(s, 0, p));
   int m = (int)StringToInteger(StringSubstr(s, p + 1));
   if(h < 0 || h > 24 || m < 0 || m > 59) return -1;
   if(h == 24 && m != 0) return -1;
   return h * 60 + m;
}

bool NY_ParseAll()
{
   m_ONs = NY_ParseHM(NY_ON_Start);     m_ONe   = NY_ParseHM(NY_ON_End);
   m_PMs = NY_ParseHM(NY_PM_Start);     m_PMe   = NY_ParseHM(NY_PM_End);
   m_Mid = NY_ParseHM(NY_MidnightOpen); m_Close = NY_ParseHM(NY_PrevClose);
   m_Ext = NY_ParseHM(NY_ExtOpen);
   if(m_ONs < 0 || m_ONe < 0 || m_PMs < 0 || m_PMe < 0 || m_Mid < 0 || m_Close < 0 || m_Ext < 0)
   {
      Print("NY Levels: invalid time format. Use HH:MM (e.g. 07:00).");
      return false;
   }
   if(m_ONe <= m_ONs || m_PMe <= m_PMs)
   {
      Print("NY Levels: range end must be later than range start.");
      return false;
   }
   if(NY_To_Server_Hours < -14 || NY_To_Server_Hours > 14)
   {
      Print("NY Levels: NY_To_Server_Hours out of range.");
      return false;
   }
   return true;
}

// first M1 bar with open time >= t, -1 if none/gap too big
int NY_FirstBarAtOrAfter(datetime t)
{
   int s = iBarShift(Symbol(), PERIOD_M1, t, false);
   if(s < 0) return -1;
   if(iTime(Symbol(), PERIOD_M1, s) < t) s--;
   if(s < 0) return -1;
   if(iTime(Symbol(), PERIOD_M1, s) - t > NY_TOL) return -1;
   return s;
}

// last M1 bar with open time <= t, -1 if none/gap too big
int NY_LastBarAtOrBefore(datetime t)
{
   int s = iBarShift(Symbol(), PERIOD_M1, t, false);
   if(s < 0) return -1;
   datetime bt = iTime(Symbol(), PERIOD_M1, s);
   if(bt > t) return -1;
   if(t - bt > NY_TOL) return -1;
   return s;
}

// high/low of completed range [a, b) in server time
bool NY_GetRange(datetime a, datetime b, double &hi, double &lo)
{
   if(b > TimeCurrent()) return false;                 // range not finished yet
   int s = NY_FirstBarAtOrAfter(a);
   int e = NY_LastBarAtOrBefore(b - 1);
   if(s < 0 || e < 0 || e > s) return false;
   if(iTime(Symbol(), PERIOD_M1, e) < a) return false;
   hi = -DBL_MAX; lo = DBL_MAX;
   for(int i = e; i <= s; i++)
   {
      double h = iHigh(Symbol(), PERIOD_M1, i);
      double l = iLow(Symbol(),  PERIOD_M1, i);
      if(h > hi) hi = h;
      if(l < lo) lo = l;
   }
   return (hi >= lo);
}

void NY_DrawLevel(string key, datetime dayNY, datetime t1, datetime t2,
                  double price, color clr, string label)
{
   string name = NY_PFX + key + "_" + TimeToString(dayNY, TIME_DATE);
   string txt  = label + " " + DoubleToString(price, Digits);

   if(ObjectFind(0, name) >= 0) ObjectDelete(0, name);
   if(!ObjectCreate(0, name, OBJ_TREND, 0, t1, price, t2, price))
   {
      Print("NY Levels: cannot create ", name, " err=", GetLastError());
      return;
   }
   ObjectSetInteger(0, name, OBJPROP_COLOR,      clr);
   ObjectSetInteger(0, name, OBJPROP_STYLE,      NY_LineStyle);
   ObjectSetInteger(0, name, OBJPROP_WIDTH,      NY_LineWidth);
   ObjectSetInteger(0, name, OBJPROP_RAY,        false);
   ObjectSetInteger(0, name, OBJPROP_BACK,       false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);   // EA redraws them, edits would be lost
   ObjectSetInteger(0, name, OBJPROP_HIDDEN,     true);
   ObjectSetString (0, name, OBJPROP_TOOLTIP,    txt);

   if(!NY_ShowLabels) return;

   string tn = name + "_txt";
   if(ObjectFind(0, tn) >= 0) ObjectDelete(0, tn);

   datetime          lt;
   ENUM_ANCHOR_POINT anc;
   if(NY_LabelSide == NYL_LEFT)
   {
      lt  = t1;
      anc = ANCHOR_LEFT_LOWER;
   }
   else
   {
      datetime now = TimeCurrent();
      if(t2 > now)    // still running: label right of last candle
      {
         lt  = now + (datetime)(NY_LabelBarsAhead * PeriodSeconds());
         anc = ANCHOR_LEFT_LOWER;
      }
      else            // finished line: label ends at right end
      {
         lt  = t2;
         anc = ANCHOR_RIGHT_LOWER;
      }
   }

   if(ObjectCreate(0, tn, OBJ_TEXT, 0, lt, price))
   {
      ObjectSetString (0, tn, OBJPROP_TEXT, txt);
      ObjectSetString (0, tn, OBJPROP_FONT, "Arial");
      ObjectSetInteger(0, tn, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, tn, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, tn, OBJPROP_ANCHOR, anc);
      ObjectSetInteger(0, tn, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, tn, OBJPROP_HIDDEN, true);
   }
}

// returns false if it could not draw (e.g. M1 history not loaded) -> retried later
bool NY_DrawAll()
{
   if(iBars(Symbol(), PERIOD_M1) < 100)
   {
      if(!g_nyWarned)
      {
         Print("NY Levels: not enough M1 history for ", Symbol(),
               ". Open an M1 chart and scroll back to load data; lines appear automatically.");
         g_nyWarned = true;
      }
      return false;
   }

   ObjectsDeleteAll(0, NY_PFX);

   long off    = (long)NY_To_Server_Hours * 3600;
   long nowSrv = (long)TimeCurrent();
   long nowNY  = nowSrv - off;
   long day0   = nowNY - (nowNY % 86400);               // today 00:00 New York

   for(int k = 0; k <= NY_DaysToLookBack; k++)
   {
      long     dayNYl     = day0 - (long)k * 86400;
      datetime dayNY      = (datetime)dayNYl;
      long     dayStartSv = dayNYl + off;                // that NY day 00:00 in server time
      datetime dayEnd     = (datetime)(dayStartSv + 86400);

      // end of next trading weekday (levels that matter the next day)
      int dow = TimeDayOfWeek(dayNY);
      int add = 1;
      if(dow == 5) add = 3;                              // Friday -> Monday
      else if(dow == 6) add = 2;                         // Saturday -> Monday
      datetime nextEnd = (datetime)(dayStartSv + (long)(add + 1) * 86400);

      double hi, lo;

      //--- Overnight high/low
      datetime a = (datetime)(dayStartSv + (long)m_ONs * 60);
      datetime b = (datetime)(dayStartSv + (long)m_ONe * 60);
      if(NY_GetRange(a, b, hi, lo))
      {
         NY_DrawLevel("ON_HIGH", dayNY, a, dayEnd, hi, NY_ON_Color, "Overnight Trade High");
         NY_DrawLevel("ON_LOW",  dayNY, a, dayEnd, lo, NY_ON_Color, "Overnight Trade Low");
      }

      //--- PreMarket high/low
      a = (datetime)(dayStartSv + (long)m_PMs * 60);
      b = (datetime)(dayStartSv + (long)m_PMe * 60);
      if(NY_GetRange(a, b, hi, lo))
      {
         NY_DrawLevel("PM_HIGH", dayNY, a, dayEnd, hi, NY_PM_Color, "PreMarket High");
         NY_DrawLevel("PM_LOW",  dayNY, a, dayEnd, lo, NY_PM_Color, "PreMarket Low");
      }

      //--- Midnight open
      datetime t = (datetime)(dayStartSv + (long)m_Mid * 60);
      if((long)t <= nowSrv)
      {
         int i = NY_FirstBarAtOrAfter(t);
         if(i >= 0)
            NY_DrawLevel("MID_OPEN", dayNY, t, dayEnd,
                         iOpen(Symbol(), PERIOD_M1, i), NY_Midnight_Color, "Midnight Open");
      }

      //--- Previous day regular close (close of the candle opening at that time)
      t = (datetime)(dayStartSv + (long)m_Close * 60);
      if((long)t + 60 <= nowSrv)
      {
         int i = NY_LastBarAtOrBefore(t);
         if(i >= 0)
            NY_DrawLevel("PREV_CLOSE", dayNY, t, nextEnd,
                         iClose(Symbol(), PERIOD_M1, i), NY_PrevClose_Color, "Prev Day Regular Close");
      }

      //--- Extended hour open
      t = (datetime)(dayStartSv + (long)m_Ext * 60);
      if((long)t <= nowSrv)
      {
         int i = NY_FirstBarAtOrAfter(t);
         if(i >= 0)
            NY_DrawLevel("EXT_OPEN", dayNY, t, nextEnd,
                         iOpen(Symbol(), PERIOD_M1, i), NY_ExtOpen_Color, "Extended Hour Open");
      }
   }
   return true;
}

void UpdateNYLevels()
{
   if(!g_nyOn) return;
   datetime m1 = iTime(Symbol(), PERIOD_M1, 0);
   if(m1 == 0 || m1 == g_nyLastBar) return;   // only once per new M1 bar
   if(NY_DrawAll()) g_nyLastBar = m1;
}

void UpdateNyBtn()
{
   ObjectSetString(0, BTN_NY, OBJPROP_TEXT, g_nyOn ? "NY Levels: ON" : "NY Levels: OFF");
   ObjectSetInteger(0, BTN_NY, OBJPROP_BGCOLOR, g_nyOn ? clrMediumPurple : clrDimGray);
   ObjectSetInteger(0, BTN_NY, OBJPROP_STATE, false);
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
//| Custom margin level line -> SL or TP for every open order        |
//| (option A: MT4 rules decide per order, so the whole basket       |
//|  closes together at that level)                                  |
//+------------------------------------------------------------------+
void SetMLSLTP(bool verbose)
{
   g_lastMLAttempt = GetTickCount();
   if(g_cmlBid <= 0)
   {
      if(verbose) Alert(Symbol(), ": no margin level line (no positions, fully hedged or no margin).");
      return;
   }
   if(!IsTradeAllowed())
   {
      if(verbose) Alert("Trading not allowed - enable AutoTrading / 'Allow live trading'.");
      return;
   }
   if(verbose && BelowStopout(g_cmlPct))
   {
      string w = "Margin level " + PctStr(g_cmlPct) + "% is at/below your broker's stop-out level (" +
                 DoubleToString(AccountStopoutLevel(), 0) + "%).\n\n" +
                 "The broker will close positions BEFORE price reaches this line.\n\nSet SL/TP anyway?";
      if(MessageBox(w, "Warning", MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2) != IDYES) return;
   }
   if(g_auto)   // Auto BE TP would move the TPs back to the BE line
   {
      g_auto = false;
      UpdateAutoBtn();
      Print("Auto BE TP switched OFF because ML SL/TP was set.");
   }

   RefreshRates();
   double stop   = MathMax(MarketInfo(Symbol(), MODE_STOPLEVEL),
                           MarketInfo(Symbol(), MODE_FREEZELEVEL)) * Point;
   double spread = Ask - Bid;
   double minChg = MathMax(1, MinTPChangePoints) * Point;
   int nSL = 0, nTP = 0, skipped = 0, failed = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      if(!OrderSelect(i, SELECT_BY_POS, MODE_TRADES)) continue;
      if(!Managed()) continue;

      bool   isBuy = (OrderType() == OP_BUY);
      double cur   = isBuy ? Bid : Ask;
      double lvl   = NormalizeDouble(isBuy ? g_cmlBid : g_cmlBid + spread, Digits);  // sells close on Ask
      double sl    = OrderStopLoss();
      double tp    = OrderTakeProfit();

      bool asTP;
      if(lvl > cur + stop)      asTP = isBuy;     // above price: TP for buy, SL for sell
      else if(lvl < cur - stop) asTP = !isBuy;    // below price: SL for buy, TP for sell
      else { skipped++; continue; }               // too close to price

      if(asTP) { if(MathAbs(tp - lvl) < minChg) continue; tp = lvl; }
      else     { if(MathAbs(sl - lvl) < minChg) continue; sl = lvl; }

      if(OrderModify(OrderTicket(), OrderOpenPrice(), sl, tp, 0, clrNONE))
      {
         if(asTP) nTP++; else nSL++;
      }
      else
      {
         failed++;
         Print("ML SL/TP modify failed #", OrderTicket(), " level=", DoubleToString(lvl, Digits),
               " err=", GetLastError());
      }
   }

   string res = "ML " + PctStr(g_cmlPct) + "% (" + DoubleToString(g_cmlBid, Digits) + "): SL set " +
                IntegerToString(nSL) + ", TP set " + IntegerToString(nTP);
   if(skipped > 0) res += ", skipped " + IntegerToString(skipped) + " (too close to price)";
   if(failed  > 0) res += ", FAILED " + IntegerToString(failed) + " (see Experts log)";
   if(verbose || failed > 0) Print(res);
   if(verbose && (skipped > 0 || failed > 0)) Alert(res);
}

void UpdateMlAutoBtn()
{
   ObjectSetString(0, BTN_CMLAUTO, OBJPROP_TEXT, g_mlAuto ? "ML Auto: ON" : "ML Auto: OFF");
   ObjectSetInteger(0, BTN_CMLAUTO, OBJPROP_BGCOLOR, g_mlAuto ? clrSeaGreen : clrDimGray);
   ObjectSetInteger(0, BTN_CMLAUTO, OBJPROP_STATE, false);
}

//+------------------------------------------------------------------+
//| Drawing                                                          |
//+------------------------------------------------------------------+
void DrawLevel(string name, double price, color c, ENUM_LINE_STYLE st, string txt,
               int width = 0, string font = "Arial")
{
   if(width <= 0) width = LineWidth;
   // user is dragging this line: don't move it under the mouse
   if(ObjectFind(0, name) >= 0 && ObjectGetInteger(0, name, OBJPROP_SELECTED))
   {
      ObjectSetString(0, name, OBJPROP_TEXT, txt);
      return;
   }
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
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
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
      ObjectSetString(0, t, OBJPROP_FONT, font);
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
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, 184 - row * 16);
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
