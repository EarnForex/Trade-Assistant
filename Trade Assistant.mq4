//+------------------------------------------------------------------+
//|                                              Trade_Assistant.mq4 |
//|                                 Copyright © 2010-2022, EarnForex |
//|                                        https://www.earnforex.com |
//|                           Based on indicator by Tom Balfe (2008) |
//+------------------------------------------------------------------+
#property copyright "www.EarnForex.com, 2010-2022"
#property link      "https://www.earnforex.com/metatrader-indicators/Trade-Assistant/"
#property version   "1.02"
#property strict

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

// For alerts
int Confluence[9] = {0, 0, 0, 0, 0, 0, 0, 0, 0};
int Confluence_prev[9] = {0, 0, 0, 0, 0, 0, 0, 0, 0};

// Spacing
int scaleX = 100, scaleY = 20, offsetX = 90, offsetY = 20, fontSize = 8;
// Internal indicator parameters
ENUM_TIMEFRAMES TF[]   = {PERIOD_M1, PERIOD_M5, PERIOD_M15, PERIOD_M30, PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
int             eCCI[] = {14, 14, 14, 6, 6, 6, 6, 5, 4};
int             tCCI[] = {100, 50, 34, 14, 14, 14, 14, 12, 10};
// Text labels
string signalNameStr[] = {"Stoch", "RSI", "Entry CCI", "Trend CCI"};

int OnInit()
{
    IndicatorShortName(ShortName);
    
    if ((!Enable_M1) && (!Enable_M5) && (!Enable_M15) && (!Enable_M30) && (!Enable_H1) && (!Enable_H4) && (!Enable_D1) && (!Enable_W1) && (!Enable_MN1)) return INIT_FAILED;
    
    return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
    ObjectsDeleteAll(ChartID(), IndicatorWindow, OBJ_LABEL);
}

int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime& time[],
                const double& open[],
                const double& high[],
                const double& low[],
                const double& close[],
                const long& tick_volume[],
                const long& volume[],
                const int& spread[]
)
{
    if (IndicatorWindow == -1) // Only once.
    {
        IndicatorWindow = WindowFind(ShortName);
        // Labels and placeholders.
        for (int x = 0, x_m = 0; x < 9; x++)
        {
            if (!TimeframeCheck(TF[x])) continue;
    
            for (int y = 0; y < 4; y++)
            {
                string suffix = IntegerToString(x) + IntegerToString(y);

                // Create timeframe text labels.
                string name = "tPs" + suffix;
                ObjectCreate(name, OBJ_LABEL, IndicatorWindow, 0, 0);
                ObjectSetText(name, StringSubstr(EnumToString(TF[x]), 7), fontSize, "Arial Bold", TFColor);
                ObjectSet(name, OBJPROP_CORNER, 0);
                ObjectSet(name, OBJPROP_XDISTANCE, x_m * scaleX + offsetX);
                ObjectSet(name, OBJPROP_YDISTANCE, y * scaleY + offsetY);
                ObjectSet(name, OBJPROP_SELECTABLE, false);
    
                // Create blanks for arrows.
                name = "dI" + suffix;
                ObjectCreate(name, OBJ_LABEL, IndicatorWindow, 0, 0);
                ObjectSetText(name, " ", 10);
                ObjectSet(name, OBJPROP_CORNER, 0);
                ObjectSet(name, OBJPROP_XDISTANCE, x_m * scaleX + (offsetX + 60));
                ObjectSet(name, OBJPROP_YDISTANCE, y * scaleY + offsetY);
                ObjectSet(name, OBJPROP_SELECTABLE, false);
    
                // Create blanks for text.
                name = "tI" + suffix;
                ObjectCreate(name, OBJ_LABEL, IndicatorWindow, 0, 0);
                ObjectSetText(name, "    ", 9);
                ObjectSet(name, OBJPROP_CORNER, 0);
                ObjectSet(name, OBJPROP_XDISTANCE, x_m * scaleX + (offsetX + 25));
                ObjectSet(name, OBJPROP_YDISTANCE, y * scaleY + offsetY);
                ObjectSet(name, OBJPROP_SELECTABLE, false);
    
            }
            x_m++; // Multiplier for object position. Increased only for enabled timeframes.
        }

        // Create indicator text labels.
        for (int y = 0; y < 4; y++)
        {
            string name = "tInd" + IntegerToString(y);
            ObjectCreate(name, OBJ_LABEL, IndicatorWindow, 0, 0);
            ObjectSetText(name, signalNameStr[y], fontSize, "Arial Bold", IndicatorColor);
            ObjectSet(name, OBJPROP_CORNER, 0);
            ObjectSet(name, OBJPROP_XDISTANCE, offsetX - 80);
            ObjectSet(name, OBJPROP_YDISTANCE, y * scaleY + offsetY);
            ObjectSet(name, OBJPROP_SELECTABLE, false);
        }
    }

    // Main indicator values.
    for (int x = 0; x < 9; x++)
    {
        if (!TimeframeCheck(TF[x])) continue;

        Confluence[x] = 0; // For alerts.
        
        // Stochastic arrows and text.
        string name_arrow = "dI" + IntegerToString(x) + "0";
        string name_text = "tI" + IntegerToString(x) + "0";
        if ((iStochastic(NULL, TF[x], PercentK, PercentD, Slowing, MODE_SMA, 0, MODE_MAIN, CheckCandle)) >
            (iStochastic(NULL, TF[x], PercentK, PercentD, Slowing, MODE_SMA, 0, MODE_SIGNAL, CheckCandle)))
        {
            ObjectSetText(name_arrow, CharToString(sBuy), fontSize, "Wingdings", BuyColor);
            ObjectSetText(name_text, " BUY", 9, "Arial Bold", BuyColor);
            Confluence[x]++;
        }
        else if
           ((iStochastic(NULL, TF[x], PercentK, PercentD, Slowing, MODE_SMA, 0, MODE_SIGNAL, CheckCandle)) >
            (iStochastic(NULL, TF[x], PercentK, PercentD, Slowing, MODE_SMA, 0, MODE_MAIN, CheckCandle)))
        {
            ObjectSetText(name_arrow, CharToString(sSell), fontSize, "Wingdings", SellColor);
            ObjectSetText(name_text, "SELL", 9, "Arial Bold", SellColor);
            Confluence[x]--;
        }
        else
        {
            ObjectSetText(name_arrow, CharToString(sWait), 10, "Wingdings", NeutralColor);
            ObjectSetText(name_text, "WAIT", 9, "Arial Bold", NeutralColor);
        }

        // RSI arrows and text.
        name_arrow = "dI" + IntegerToString(x) + "1";
        name_text = "tI" + IntegerToString(x) + "1";
        if ((iRSI(NULL, TF[x], RSIP1, PRICE_TYPICAL, 0)) > (iRSI(NULL, TF[x], RSIP2, PRICE_TYPICAL, CheckCandle)))
        {
            ObjectSetText(name_arrow, CharToString(sBuy), fontSize, "Wingdings", BuyColor);
            ObjectSetText(name_text, " BUY", 9, "Arial Bold", BuyColor);
            Confluence[x]++;
        }
        else if
           ((iRSI(NULL, TF[x], RSIP2, PRICE_TYPICAL, 0)) > (iRSI(NULL, TF[x], RSIP1, PRICE_TYPICAL, CheckCandle)))
        {
            ObjectSetText(name_arrow, CharToString(sSell), fontSize, "Wingdings", SellColor);
            ObjectSetText(name_text, "SELL", 9, "Arial Bold", SellColor);
            Confluence[x]--;
        }
        else
        {
            ObjectSetText(name_arrow, CharToString(sWait), fontSize, "Wingdings", NeutralColor);
            ObjectSetText(name_text, "WAIT", 9, "Arial Bold", NeutralColor);
        }


        // Entry CCI arrows and text.
        name_arrow = "dI" + IntegerToString(x) + "2";
        name_text = "tI" + IntegerToString(x) + "2";
        if ((iCCI(NULL, TF[x], eCCI[x], PRICE_TYPICAL, CheckCandle)) > 0) // If entry CCI is greater than zero.
        {
            if ((iCCI(NULL, TF[x], eCCI[x], PRICE_TYPICAL, CheckCandle)) > (iCCI(NULL, TF[x], eCCI[x], PRICE_TYPICAL, CheckCandle + 1)))
            {
                ObjectSetText(name_arrow, CharToString(sBuy), fontSize, "Wingdings", BuyColor);
                ObjectSetText(name_text, " BUY", 9, "Arial Bold", BuyColor);
                Confluence[x]++;
            }
            else
            {
                ObjectSetText(name_arrow, CharToString(sCCIAgainstBuy), fontSize, "Wingdings", SellColor);
                ObjectSetText(name_text, "SELL", 9, "Arial Bold", SellColor);
                Confluence[x]--;
            }
        }
        else if
          ((iCCI(NULL, TF[x], eCCI[x], PRICE_TYPICAL, CheckCandle)) < 0) // If entry CCI is less than zero.
        {
            if ((iCCI(NULL, TF[x], eCCI[x], PRICE_TYPICAL, CheckCandle)) < (iCCI(NULL, TF[x], eCCI[x], PRICE_TYPICAL, CheckCandle + 1)))
            {
                ObjectSetText(name_arrow, CharToString(sSell), fontSize, "Wingdings", SellColor);
                ObjectSetText(name_text, "SELL", 9, "Arial Bold", SellColor);
                Confluence[x]--;
            }
            else
            {
                ObjectSetText(name_arrow, CharToString(sCCIAgainstSell), fontSize, "Wingdings", BuyColor);
                ObjectSetText(name_text, " BUY", 9, "Arial Bold", BuyColor);
                Confluence[x]++;
            }
        }
        else
        {
            ObjectSetText(name_arrow, CharToString(sWait), 10, "Wingdings", NeutralColor);
            ObjectSetText(name_text, "WAIT", 9, "Arial Bold", NeutralColor);
        }


        // Trend CCI arrows and text.
        name_arrow = "dI" + IntegerToString(x) + "3";
        name_text = "tI" + IntegerToString(x) + "3";
        if ((iCCI(NULL, TF[x], tCCI[x], PRICE_TYPICAL, CheckCandle)) > 0) // If trend CCI greater than zero.
        {
            if ((iCCI(NULL, TF[x], tCCI[x], PRICE_TYPICAL, CheckCandle)) > (iCCI(NULL, TF[x], tCCI[x], PRICE_TYPICAL, CheckCandle + 1)))
            {
                ObjectSetText(name_arrow, CharToString(sBuy), fontSize, "Wingdings", BuyColor);
                ObjectSetText(name_text, " BUY", 9, "Arial Bold", BuyColor);
                Confluence[x]++;
            }
            else
            {
                ObjectSetText(name_arrow, CharToString(sCCIAgainstBuy), fontSize, "Wingdings", SellColor);
                ObjectSetText(name_text, "SELL", 9, "Arial Bold", SellColor);
                Confluence[x]--;
            }
        }
        else if
           ((iCCI(NULL, TF[x], tCCI[x], PRICE_TYPICAL, CheckCandle)) < 0) // If trend CCI less than zero.
        {
            if ((iCCI(NULL, TF[x], tCCI[x], PRICE_TYPICAL, CheckCandle)) < (iCCI(NULL, TF[x], tCCI[x], PRICE_TYPICAL, CheckCandle + 1)))
            {
                ObjectSetText(name_arrow, CharToString(sSell), fontSize, "Wingdings", SellColor);
                ObjectSetText(name_text, "SELL", 9, "Arial Bold", SellColor);
                Confluence[x]--;
            }
            else
            {
                ObjectSetText(name_arrow, CharToString(sCCIAgainstSell), fontSize, "Wingdings", BuyColor);
                ObjectSetText(name_text, " BUY", 9, "Arial Bold", BuyColor);
                Confluence[x]++;
            }
        }
        else
        {
            ObjectSetText(name_arrow, CharToString(sWait), 10, "Wingdings", NeutralColor);
            ObjectSetText(name_text, "WAIT", 9, "Arial Bold", NeutralColor);
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