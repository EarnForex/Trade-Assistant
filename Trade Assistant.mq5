//+------------------------------------------------------------------+
//|                                              Trade_Assistant.mq5 |
//|                                 Copyright © 2010-2022, EarnForex |
//|                                        https://www.earnforex.com |
//|                           Based on indicator by Tom Balfe (2008) |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2010-2022"
#property link      "https://www.earnforex.com/metatrader-indicators/Trade-Assistant/"
#property version   "1.02"

#property description "Trade Assistant - an indicator that shows simple trade recommendations based on the Stochastic, RSI, and CCI readings."
#property description "Alerts on indicator confluence."
#property description "Supported timeframes: M1, M5, M15, M30, H1, H4, D1, W1, MN1."

#property indicator_separate_window
#property indicator_plots 0

enum enum_candle_to_check
{
    Current,
    Previous
};

// Input parameters
input enum_candle_to_check CheckCandle = Previous; // CheckCandle: Affects both indications and alerts.

input string Stochastic_Settings = "=== Stochastic Settings ===";
input int    PercentK            = 8;
input int    PercentD            = 3;
input int    Slowing             = 3;

input string RSI_Settings        = "=== RSI Settings ===";
input int    RSIP1               = 14;
input int    RSIP2               = 70;

input string Timeframe_Settings  = "=== Timeframe Settings ===";
input bool   Enable_M1           = false; // Enable M1
input bool   Enable_M5           = true;  // Enable M5
input bool   Enable_M15          = true;  // Enable M15
input bool   Enable_M30          = true;  // Enable M30
input bool   Enable_H1           = true;  // Enable H1
input bool   Enable_H4           = true;  // Enable H4
input bool   Enable_D1           = true;  // Enable D1
input bool   Enable_W1           = true;  // Enable W1
input bool   Enable_MN1          = false; // Enable MN1

input string My_Alerts           = "=== Alerts ===";
input bool EnableNativeAlerts    = false;
input bool EnableEmailAlerts     = false;
input bool EnablePushAlerts      = false;

input string My_Colors           = "=== Colors ===";
input color  TFColor             = clrLightSteelBlue; // Timeframe Color
input color  IndicatorColor      = clrPaleGoldenrod;  // Indicator Color
input color  BuyColor            = clrLime;           // Buy Color
input color  SellColor           = clrRed;            // Sell Color
input color  NeutralColor        = clrKhaki;          // Neutral Color

input string My_Symbols          = "=== Wingdings Symbols ===";
input uchar  sBuy                = 233;
input uchar  sSell               = 234;
input uchar  sWait               = 54;
input uchar  sCCIAgainstBuy      = 238;
input uchar  sCCIAgainstSell     = 236;

// Global variables
int IndicatorWindow = -1;
string ShortName = "Trade Assistant";

// Indicator handles
int myStochastic[9], myRSI1[9], myRSI2[9], myCCIe[9], myCCIt[9];

// For alerts:
int Confluence[9] = {0, 0, 0, 0, 0, 0, 0, 0, 0};
int Confluence_prev[9] = {0, 0, 0, 0, 0, 0, 0, 0, 0};

// Spacing
int scaleX = 100, scaleY = 20, offsetX = 90, offsetY = 10, fontSize = 8;
// Internal indicator parameters
ENUM_TIMEFRAMES TF[]   = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
int             eCCI[] = {14, 14, 14, 6, 6, 6, 6, 5, 4};
int             tCCI[] = {100, 50, 34, 14, 14, 14, 14, 12, 10};
// Text labels
string signalNameStr[] = {"Stoch", "RSI", "Entry CCI", "Trend CCI"};

int OnInit()
{
    IndicatorSetString(INDICATOR_SHORTNAME, ShortName);
    
    if ((!Enable_M1) && (!Enable_M5) && (!Enable_M15) && (!Enable_M30) && (!Enable_H1) && (!Enable_H4) && (!Enable_D1) && (!Enable_W1) && (!Enable_MN1)) return INIT_FAILED;

    // Main indicator values.
    for (int x = 0; x < 9; x++)
    {
        if (!TimeframeCheck(TF[x])) continue;
        
        myStochastic[x] = iStochastic(NULL, TF[x], PercentK, PercentD, Slowing, MODE_SMA, STO_LOWHIGH);

        myRSI1[x] = iRSI(NULL, TF[x], RSIP1, PRICE_TYPICAL);
        myRSI2[x] = iRSI(NULL, TF[x], RSIP2, PRICE_TYPICAL);
    
        myCCIe[x] = iCCI(NULL, TF[x], eCCI[x], PRICE_TYPICAL);
        myCCIt[x] = iCCI(NULL, TF[x], tCCI[x], PRICE_TYPICAL);
    }
    
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    ObjectsDeleteAll(ChartID(), IndicatorWindow, OBJ_LABEL);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
    if (IndicatorWindow == -1) // Only once.
    {
        IndicatorWindow = ChartWindowFind(ChartID(), ShortName);
        // Labels and placeholders.
        for (int x = 0, x_m = 0; x < 9; x++)
        {
            if (!TimeframeCheck(TF[x])) continue;
    
            for (int y = 0; y < 4; y++)
            {
                string suffix = IntegerToString(x) + IntegerToString(y);

                // Create timeframe text labels.
                string name = "tPs" + suffix;
                ObjectCreate(0, name, OBJ_LABEL, IndicatorWindow, 0, 0);
                ObjectSetText(name, StringSubstr(EnumToString(TF[x]), 7), fontSize, "Arial Bold", TFColor);
                ObjectSetInteger(0, name, OBJPROP_CORNER, 0);
                ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_m * scaleX + offsetX);
                ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y * scaleY + offsetY);
                ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    
                // Create blanks for arrows.
                name = "dI" + suffix;
                ObjectCreate(0, name, OBJ_LABEL, IndicatorWindow, 0, 0);
                ObjectSetText(name, " ", 10);
                ObjectSetInteger(0, name, OBJPROP_CORNER, 0);
                ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_m * scaleX + (offsetX + 60));
                ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y * scaleY + offsetY);
                ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    
                // Create blanks for text.
                name = "tI" + suffix;
                ObjectCreate(0, name, OBJ_LABEL, IndicatorWindow, 0, 0);
                ObjectSetText(name, "    ", 9);
                ObjectSetInteger(0, name, OBJPROP_CORNER, 0);
                ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x_m * scaleX + (offsetX + 25));
                ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y * scaleY + offsetY);
                ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    
            }
            x_m++; // Multiplier for object position. Increased only for enabled timeframes.
        }

        // Create indicator text labels.
        for (int y = 0; y < 4; y++)
        {
            string name = "tInd" + IntegerToString(y);
            ObjectCreate(0, name, OBJ_LABEL, IndicatorWindow, 0, 0);
            ObjectSetText(name, signalNameStr[y], fontSize, "Arial Bold", IndicatorColor);
            ObjectSetInteger(0, name, OBJPROP_CORNER, 0);
            ObjectSetInteger(0, name, OBJPROP_XDISTANCE, offsetX - 80);
            ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y * scaleY + offsetY);
            ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
        }
    }

    // Main indicator values.
    for (int x = 0; x < 9; x++)
    {
        if (!TimeframeCheck(TF[x])) continue;

        Confluence[x] = 0; // For alerts.
        
        // Prepare the indicator buffers.
        double StochasticBuffer_Main[], StochasticBuffer_Signal[];
        double RSI1[], RSI2[];
        double CCI_Entry[], CCI_Trend[];
        ArraySetAsSeries(StochasticBuffer_Main, true);
        ArraySetAsSeries(StochasticBuffer_Signal, true);
        ArraySetAsSeries(RSI1, true);
        ArraySetAsSeries(RSI2, true);
        ArraySetAsSeries(CCI_Entry, true);
        ArraySetAsSeries(CCI_Trend, true);

        // Get indicators.
        if (CopyBuffer(myStochastic[x], 0, 0, 2, StochasticBuffer_Main) != 2) return 0;
        if (CopyBuffer(myStochastic[x], 1, 0, 2, StochasticBuffer_Signal) != 2) return 0;

        if (CopyBuffer(myRSI1[x], 0, 0, 2, RSI1) != 2) return 0;
        if (CopyBuffer(myRSI2[x], 0, 0, 2, RSI2) != 2) return 0;

        if (CopyBuffer(myCCIe[x], 0, 0, 3, CCI_Entry) != 3) return 0;
        if (CopyBuffer(myCCIt[x], 0, 0, 3, CCI_Trend) != 3) return 0;

        // Stochastics arrows and text.
        if (StochasticBuffer_Main[CheckCandle] > StochasticBuffer_Signal[CheckCandle])
        {
            ObjectSetText("dI" + IntegerToString(x) + "0", CharToString(sBuy), fontSize, "Wingdings", BuyColor);
            ObjectSetText("tI" + IntegerToString(x) + "0", " BUY", 9, "Arial Bold", BuyColor);
            Confluence[x]++;
        }
        else if (StochasticBuffer_Signal[CheckCandle] > StochasticBuffer_Main[CheckCandle])
        {
            ObjectSetText("dI" + IntegerToString(x) + "0", CharToString(sSell), fontSize, "Wingdings", SellColor);
            ObjectSetText("tI" + IntegerToString(x) + "0", "SELL", 9, "Arial Bold", SellColor);
            Confluence[x]--;
        }
        else
        {
            ObjectSetText("dI" + IntegerToString(x) + "0", CharToString(sWait), 10, "Wingdings", NeutralColor);
            ObjectSetText("tI" + IntegerToString(x) + "0", "WAIT", 9, "Arial Bold", NeutralColor);
        }

        // RSI arrows and text.
        if (RSI1[CheckCandle] > RSI2[CheckCandle])
        {
            ObjectSetText("dI" + IntegerToString(x) + "1", CharToString(sBuy), fontSize, "Wingdings", BuyColor);
            ObjectSetText("tI" + IntegerToString(x) + "1", " BUY", 9, "Arial Bold", BuyColor);
            Confluence[x]++;
        }
        else if (RSI1[CheckCandle] < RSI2[CheckCandle])
        {
            ObjectSetText("dI" + IntegerToString(x) + "1", CharToString(sSell), fontSize, "Wingdings", SellColor);
            ObjectSetText("tI" + IntegerToString(x) + "1", "SELL", 9, "Arial Bold", SellColor);
            Confluence[x]--;
        }
        else
        {
            ObjectSetText("dI" + IntegerToString(x) + "1", CharToString(sWait), fontSize, "Wingdings", NeutralColor);
            ObjectSetText("tI" + IntegerToString(x) + "1", "WAIT", 9, "Arial Bold", NeutralColor);
        }

        // EntryCCI arrows and text.
        if (CCI_Entry[CheckCandle] > 0) // If entry CCI above zero.
        {
            if (CCI_Entry[CheckCandle] > CCI_Entry[CheckCandle + 1])
            {
                ObjectSetText("dI" + IntegerToString(x) + "2", CharToString(sBuy), fontSize, "Wingdings", BuyColor);
                ObjectSetText("tI" + IntegerToString(x) + "2", " BUY", 9, "Arial Bold", BuyColor);
                Confluence[x]++;
            }
            else
            {
                ObjectSetText("dI" + IntegerToString(x) + "2", CharToString(sCCIAgainstBuy), fontSize, "Wingdings", SellColor);
                ObjectSetText("tI" + IntegerToString(x) + "2", "SELL", 9, "Arial Bold", SellColor);
                Confluence[x]--;
            }
        }
        else if (CCI_Entry[CheckCandle] < 0) // If entry CCI below zero
        {
            if (CCI_Entry[CheckCandle] < CCI_Entry[CheckCandle + 1])
            {
                ObjectSetText("dI" + IntegerToString(x) + "2", CharToString(sSell), fontSize, "Wingdings", SellColor);
                ObjectSetText("tI" + IntegerToString(x) + "2", "SELL", 9, "Arial Bold", SellColor);
                Confluence[x]--;
            }
            else
            {
                ObjectSetText("dI" + IntegerToString(x) + "2", CharToString(sCCIAgainstSell), fontSize, "Wingdings", BuyColor);
                ObjectSetText("tI" + IntegerToString(x) + "2", " BUY", 9, "Arial Bold", BuyColor);
                Confluence[x]++;
            }
        }
        else
        {
            ObjectSetText("dI" + IntegerToString(x) + "2", CharToString(sWait), 10, "Wingdings", NeutralColor);
            ObjectSetText("tI" + IntegerToString(x) + "2", "WAIT", 9, "Arial Bold", NeutralColor);
        }

        // TrendCCI arrows and text
        if (CCI_Trend[CheckCandle] > 0) // If entry CCI above zero
        {
            if (CCI_Trend[CheckCandle] > CCI_Trend[CheckCandle + 1])
            {
                ObjectSetText("dI" + IntegerToString(x) + "3", CharToString(sBuy), fontSize, "Wingdings", BuyColor);
                ObjectSetText("tI" + IntegerToString(x) + "3", " BUY", 9, "Arial Bold", BuyColor);
                Confluence[x]++;
            }
            else
            {
                ObjectSetText("dI" + IntegerToString(x) + "3", CharToString(sCCIAgainstBuy), fontSize, "Wingdings", SellColor);
                ObjectSetText("tI" + IntegerToString(x) + "3", "SELL", 9, "Arial Bold", SellColor);
                Confluence[x]--;
            }
        }
        else if (CCI_Trend[CheckCandle] < 0) // If entry CCI below zero
        {
            if (CCI_Trend[CheckCandle] < CCI_Trend[CheckCandle + 1])
            {
                ObjectSetText("dI" + IntegerToString(x) + "3", CharToString(sSell), fontSize, "Wingdings", SellColor);
                ObjectSetText("tI" + IntegerToString(x) + "3", "SELL", 9, "Arial Bold", SellColor);
                Confluence[x]--;
            }
            else
            {
                ObjectSetText("dI" + IntegerToString(x) + "3", CharToString(sCCIAgainstSell), fontSize, "Wingdings", BuyColor);
                ObjectSetText("tI" + IntegerToString(x) + "3", " BUY", 9, "Arial Bold", BuyColor);
                Confluence[x]++;
            }
        }
        else
        {
            ObjectSetText("dI" + IntegerToString(x) + "3", CharToString(sWait), 10, "Wingdings", NeutralColor);
            ObjectSetText("tI" + IntegerToString(x) + "3", "WAIT", 9, "Arial Bold", NeutralColor);
        }
    }

    // Alerts
    if ((EnableNativeAlerts) || (EnableEmailAlerts) || (EnablePushAlerts))
    {
        string buy_text = "Buy confluence:";
        string sell_text = "Sell confluence:";
        bool need_alert = false, buy = false, sell = false;
        static string Text_prev = "";
        for (int x = 0; x < 9; x++)
        {
            if (Confluence[x] == 4)
            {
                if (buy) buy_text += ",";
                buy_text += " " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)TF[x]), 7);
                if (Confluence_prev[x] != 4) need_alert = true;
                buy = true;
            }
            else if (Confluence[x] == -4)
            {
                if (sell) sell_text += ",";
                sell_text += " " + StringSubstr(EnumToString((ENUM_TIMEFRAMES)TF[x]), 7);
                if (Confluence_prev[x] != -4) need_alert = true;
                sell = true;
            }
            
            Confluence_prev[x] = Confluence[x];
        }
        // Confluence alert
        if (need_alert)
        {
            string Text = "TA: " + Symbol() + " - ";
            if (buy)
            {
                Text += buy_text;
                if (sell) Text += "; ";
            }
            if (sell) Text += sell_text;
            if (Text != Text_prev)
            {
                if (EnableNativeAlerts) Alert(Text);
                if (EnableEmailAlerts) SendMail("TA Alert", Text);
                if (EnablePushAlerts) SendNotification(Text);
                Text_prev = Text;
            }
        }
    }
    
    return rates_total;
}

//+------------------------------------------------------------------+
//| Imitation of the old MT4 function.                               |
//+------------------------------------------------------------------+
void ObjectSetText(const string name, const string text, const int size, string font = NULL, color colour = clrNONE)
{
    ObjectSetString(0,  name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, size);
    ObjectSetString(0,  name, OBJPROP_FONT, font);
    ObjectSetInteger(0, name, OBJPROP_COLOR, colour);
}

//+------------------------------------------------------------------+
//| Returns true if the given TF is enabled.                         |
//+------------------------------------------------------------------+
bool TimeframeCheck(ENUM_TIMEFRAMES tf)
{
    if ((tf == PERIOD_M1)  && (!Enable_M1))  return false;
    if ((tf == PERIOD_M5)  && (!Enable_M5))  return false;
    if ((tf == PERIOD_M15) && (!Enable_M15)) return false;
    if ((tf == PERIOD_M30) && (!Enable_M30)) return false;
    if ((tf == PERIOD_H1)  && (!Enable_H1))  return false;
    if ((tf == PERIOD_H4)  && (!Enable_H4))  return false;
    if ((tf == PERIOD_D1)  && (!Enable_D1))  return false;
    if ((tf == PERIOD_W1)  && (!Enable_W1))  return false;
    if ((tf == PERIOD_MN1) && (!Enable_MN1)) return false;
    return true;
}
//+------------------------------------------------------------------+