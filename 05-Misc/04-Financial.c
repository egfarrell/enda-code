//+----------------------------------------------------------------------+
// Phase_Analysis.mq4
//
// Levy phase of price signal and volatility.
// Code for Demonstration purposes only.
//
// Copyright 2012, Enda Farrell
//+----------------------------------------------------------------------+
#property copyright "Copyright 2012, Enda Farrell"

// Note:
// function "calc_alpha_signal",
// function "calc_alpha_volatility":
// function "calc_volatility":
// adapted from files supplied by J. BLACKLEDGE 2012

// Enda Farrell 2013
// Enda Farrell 2013
// Enda Farrell 2013
// Enda Farrell 2013

// Don't draw the Levy indicator
// on top of main Pricing Window
#property indicator_separate_window

// Seven plot lines are calculated
// although not all lines are displayed
#property indicator_buffers 7

// Set default width for each output line
#property indicator_width1 1
#property indicator_width2 1
#property indicator_width3 1
#property indicator_width4 1
#property indicator_width5 1
#property indicator_width6 1
#property indicator_width7 3

// Set default style for each output line
#property indicator_style1 STYLE_DASH
#property indicator_style2 STYLE_DASH
#property indicator_style3 STYLE_DASH
#property indicator_style4 STYLE_DASH
#property indicator_style5 STYLE_DASH
#property indicator_style6 STYLE_DASHDOTDOT
#property indicator_style7 STYLE_SOLID

// Set default colour for each output line
#property indicator_color1 Orange
#property indicator_color2 PaleGreen
#property indicator_color3 SandyBrown
#property indicator_color4 Gray
#property indicator_color5 Blue
#property indicator_color6 Blue
#property indicator_color7 OrangeRed

// Switch on Debugging?
// 0 = Debugging Off
// 1 = Debugging On
#define DEBUG 0

// Misc Variables
#define THRESHOLD 0
#define PI 3.14186
#define PI_HALF 1.570796
#define M_PI 3.14186
#define E 2.7182818284

// Debugging info is written out to a .txt file.
// location: "c:\<<alpari directory>>\experts\files\"
int file_result;
int file_handle;
string file_name;
string bar_info;

// Size of calculation window
extern int Lookback = 50;

// Lookback size for phase calculations (and for regression line).
// This is a very important value and in Hurst.mq4 is hardcoded to 1000.
// If this size < 1000 then invalid values MAY appear in the phase array. (Why?)
extern int phase_lookback = 1000;

// Main Calculation arrays
double vols[];
double levy_signal[];
double levy_vol[];
double phase_wrapped[];
double phase_unwrapped[];
double phase_adjusted[];
double least_squares_line[];

// Needed in functions:
// "calc_alpha_signal"
// "calc_alpha_volatility"
// "BuildRArray"
double T[];
double R[];

//-----------------------------------------------------------------------------------------------
int init()
{
   // E Farrell 2013

   IndicatorDigits(10);
   IndicatorShortName("LEVY PHASE (F. Farrell)");

   // Show or Hide a particular line?
   //
   // Use "DRAW_NONE" to hide a line
   // Use "DRAW_LINE" to display a line

   // Line 0:
   // Stochastic Volatility Line
   SetIndexBuffer     (0, vols);
   SetIndexLabel      (0, "Volatility");
   SetIndexDrawBegin  (0, Lookback);
   SetIndexStyle      (0, DRAW_NONE);
   //SetIndexStyle      (0, DRAW_LINE);

   // Line 1:
   // Levy Index of closing price (signal)
   SetIndexBuffer     (1, levy_signal);
   SetIndexLabel      (1, "levy_signal");
   SetIndexDrawBegin  (1, Lookback*2);
   SetIndexStyle      (1, DRAW_NONE);
   //SetIndexStyle      (1, DRAW_LINE);

   // Line 2:
   // Levy Index of Volatility
   SetIndexBuffer     (2, levy_vol);
   SetIndexLabel      (2, "levy_vol");
   SetIndexDrawBegin  (2, Lookback*2);
   SetIndexStyle      (2, DRAW_NONE);
   //SetIndexStyle      (2, DRAW_LINE);

   // Line 3:
   // Wrapped Phase Line
   SetIndexBuffer     (3, phase_wrapped);
   SetIndexLabel      (3, "Phase (wrapped)");
   SetIndexDrawBegin  (3, Lookback*2);
   //SetIndexStyle      (3, DRAW_NONE);
   SetIndexStyle      (3, DRAW_LINE);

   // Line 4:
   // Unwrapped Phase Line
   SetIndexBuffer     (4, phase_unwrapped);
   SetIndexLabel      (4, "Phase (Unwrapped)");
   SetIndexDrawBegin  (4, Lookback*2);
   //SetIndexStyle      (4, DRAW_NONE);
   SetIndexStyle      (4, DRAW_LINE);

  // Line 5:
  // Linear approximation of unwrapped phase
  SetIndexBuffer      (5, least_squares_line);
  SetIndexLabel       (5, "Regression Line");
  SetIndexDrawBegin   (5, Lookback*2);
  //SetIndexStyle       (5, DRAW_NONE);
  SetIndexStyle       (5, DRAW_LINE);

  // Line 6:
  // Final Adjusted Phase Line
  SetIndexBuffer      (6, phase_adjusted);
  SetIndexLabel       (6, "Phase (Adjusted)");
  SetIndexDrawBegin   (6, Lookback*2);
  SetIndexStyle       (6, DRAW_LINE);

   if (DEBUG == 1)
   {
      // Create Debug File to show array values.
      // It is CSV style, with ";" as field seperators.
      //
      // Name:       'Debug File HH-MM.txt'
      // Location:   'c:\<<alpari directory>>\experts\files\'
      //
      file_name  = "DebugFile ";
      file_name  = StringConcatenate (file_name, DoubleToStr(Hour()-2,0), "-");
      file_name  = StringConcatenate (file_name, DoubleToStr(Minute(),0), ".txt");

      file_handle = FileOpen (file_name, FILE_CSV|FILE_WRITE, ";");
      Print (file_name, " was opened.");

      if(file_handle == -1) {
         // File Error occurred
         Alert ("An error while opening the file. Last Error: ", GetLastError());
      }
   }

   return(0);
}

//-----------------------------------------------------------------------------------------------
int deinit()
{

   if (DEBUG == 1)
   {
      // Close debug file
      FileClose (file_handle);
      Print (file_name," was closed.");
   }

   ObjectDelete("X-Axis");

   return(0);
}

//-----------------------------------------------------------------------------------------------
int start()   {

   // E Farrell 2013
   // Store these values at the start
   // because they are dynamic and
   // get changed during processing later.
   int store_bars              = Bars;
   int store_indicator_counted = IndicatorCounted();
   int store_counted_bars      = store_bars - store_indicator_counted - 1;

   // Three ways of debugging:
   // Alert(...):    display popup MessageBox
   // Comment(...):  display on left corner of MAIN chart
   // Print(...):    write to "experts log"

   if (DEBUG == 1)
   {
     // Print msg to "Experts Log"
     // i.e. not to debug file
     bar_info = "";
     bar_info = StringConcatenate(bar_info, "Store_bars: ", DoubleToStr(store_bars,0), "; ");
     bar_info = StringConcatenate(bar_info, "store_indicator_counted: ", DoubleToStr(store_indicator_counted,0), "; ");
     Print (bar_info);
   }

   // Create X-Axis line along zero value
   ObjectCreate ("X-Axis", OBJ_HLINE, 1, 0, 0);
   ObjectSet    ("X-Axis", OBJPROP_COLOR, Black);
   ObjectSet    ("X-Axis", OBJPROP_WIDTH, 2);

   // vols[]
   // Compute stochastic volatility
   calc_volatility (store_bars, store_counted_bars);

   // levy_signal[]
   // Compute Levy Index
   // of Closing Price (i.e. the signal)
   calc_alpha_signal (Close, store_counted_bars);

   // levy_vol[]
   // Compute Levy Index
   // of stochastic volatility.
   calc_alpha_volatility (vols, store_counted_bars);

   // phase_wrapped[]
   // Compute WRAPPED phase
   // of levy_signal[] and levy_vol[].
   // i.e. instantaneous phase between -PI and +PI
   calc_phase (store_counted_bars);

   // Make a copy of the "phase_wrapped" array.
   // The new copy "phase_unwrapped" will be
   // worked on by the "calc_unwrap" function.
   for (int i = store_counted_bars; i >= 0; i--)
   {
         phase_unwrapped[i] = phase_wrapped[i];
   }

   // phase_unwrapped[]
   // UNWRAP the instantaneous phase
   calc_unwrap (phase_unwrapped, store_counted_bars);

   // least_squares_line[]
   // Compute regression line for unwrapped phase
   calc_regression (phase_unwrapped, phase_lookback);

   // phase_adjusted[]
   // Create a "lower" unwrapped Phase which hugs the x-axis
   calc_phase_adjusted (phase_lookback);

   return(0);
}

//-----------------------------------------------------------------------------------------------
void calc_volatility(int param_bars, int param_counted_bars)   {

   // Output: vols[] array
   // Compute volatility using log price differences.

   // Adapted by E Farrell 2013
   // from code supplied by J Blackledge 2012

   for (int i = param_counted_bars; i >= 0; i--)
   {
      double sumHat1 = 0;
      double sumHat2 = 0;

      if( i >= param_bars - Lookback ){
         Print("setting vols to zero!");
         vols[i] = 0;
         continue;
      }

      for (int j = i + Lookback - 2; j >= i; j--){
         sumHat1 += MathPow( MathAbs( MathLog( Close[j] / Close[j+1] ) ), 2);
         sumHat2 += MathLog(Close[j]/Close[j+1]);
      }

      // Calculate Volatility
      sumHat1 = MathSqrt(sumHat1);
      sumHat2 = sumHat2 / MathSqrt(Lookback-1);
      vols[i] = sumHat1- sumHat2;

      if (DEBUG == 1) {
         // Output array values to Expert Log
         //Print("\t vols[\t", DoubleToStr(i,0), "\t] \t", DoubleToStr(vols[i],6));
         //Print("\t Close[\t", DoubleToStr(i,0), "\t] \t", DoubleToStr(Close[i],6));

         // Write values to debug file
         file_result = FileWrite (file_handle, "close", i, Close[i], "vols", i, vols[i]);
      }

   }

}

//-----------------------------------------------------------------------------------------------
void calc_alpha_signal (double Input_Array[], int param_counted_bars)
{
   // Calculate alpha index of close[]
   // using least squares algorithm

   // Adapted by E Farrell 2013
   // source supplied by J Blackledge 2012

   // initialize R & T
   ArrayResize(T,Lookback);
   ArrayResize(R,Lookback);

   // set up the T array
   for(int t = 1; t <= Lookback; t++)
      T[t-1] = MathLog(t);

   for (int i = phase_lookback; i >= 0; i--)
   {
      // Create autocorrelation array for R,
      // based on "Input_Array"
      BuildRArray (Lookback, i, Input_Array);

      // Calculate alpha index
      // of closing price (signal)
      levy_signal[i] = -GetHurstExponent(Lookback, T, R);

      if (DEBUG == 1){
         // Output array values to Expert Log
         //Print("\t levy_signal[\t", DoubleToStr(i,0), "\t] \t", DoubleToStr(levy_signal[i],6));
         file_result = FileWrite (file_handle, "levy_signal", i, levy_signal[i]);
      }
   }

}

//-----------------------------------------------------------------------------------------------
void calc_alpha_volatility (double Input_Array[], int param_counted_bars)
{
   // Calculate alpha index of vols[]
   // using least squares algorithm.

   // Adapted by E Farrell 2013
   // source supplied by J Blackledge 2012

   // initialize R & T
   ArrayResize(T,Lookback);
   ArrayResize(R,Lookback);

   // set up the T array
   for(int t = 1; t <= Lookback; t++)
      T[t-1] = MathLog(t);

   for(int i = phase_lookback; i >= 0; i--)
   {
      // Create autocorrelation array for R,
      // based on "Input_Array"
      BuildRArray (Lookback, i, Input_Array);

      // Calculate alpha index
      // of volatility
      levy_vol[i] = -GetHurstExponent(Lookback, T, R);

      if (DEBUG == 1)
      {
         // Output array values to Expert Log
         //Print("\t levy_vol[\t", DoubleToStr(i,0), "\t] \t", DoubleToStr(levy_vol[i],6));
         file_result = FileWrite (file_handle, "levy_vol", i, levy_vol[i]);
      }

   }

}

//-----------------------------------------------------------------------------------------------
void calc_phase (int param_counted_bars)
{
      // E Farrell 2013
      // Compute Wrapped Phase signal.
      // using Arctangent function ("MathArctan" in mq4)

      double x;
      double y;

      for (int i = param_counted_bars; i >= 0; i--)
      {
         // "arctan(y, x)" is an alias for "arg(x, y)".
         // arg(x,y) returns the argument of the complex
         // number with real part "x" and imaginary part "y".

         // See MATLAB Notes:
         // http://www.mathworks.co.uk/help/symbolic/mupad_ref/arg.html

         // Calculate the phase, aka the "complex argument".
         // This is the core calculation of the whole indicator.
         x = levy_signal[i];
         y = levy_vol[i];
         phase_wrapped[i] = MathArctan(y/x) + (PI_HALF * calc_sign(y) * (1 - calc_sign(x)));

         if (DEBUG == 1) {
            // Output handy debugging info
            // Print ("phase_wrapped[", DoubleToStr(i,0), "] ", DoubleToStr(phase_wrapped[i],10));
            file_result = FileWrite (file_handle, "phase_wrapped", i, phase_wrapped[i]);
         }
      }

}

//-----------------------------------------------------------------------------------------------
int calc_sign (double some_value)
{
   // E Farrell 2013
   // See MATLAB Notes:
   // http://www.mathworks.co.uk/help/matlab/ref/sign.html

   // Return +1 if "some_value" positive
   // Return -1 if "some_value" negative
   // Return  0 if "some_value" zero

   // start by assuming zero
   int sign = 0;

   // Check for positive
   if (some_value > 0)
      sign = 1;

   // Check for negative
   if (some_value < 0)
      sign = -1;

   // return 0, +1 or -1
   return(sign);
}

//-----------------------------------------------------------------------------------------------
// Code adapted by E Farrell 2013
// from original at:
// http://medphysics.wisc.edu/~ethan/phaseunwrap/unwrap.c
// Ethan Brodsky <brodskye@cae.wisc.edu>

#define MAX_LENGTH 10000

void calc_unwrap (double& p[], int N)
{
    double dp[MAX_LENGTH];
    double dps[MAX_LENGTH];
    double dp_corr[MAX_LENGTH];
    double cumsum[MAX_LENGTH];
    double cutoff = M_PI;               /* default value in matlab */
    int j;

    //assert(N <= MAX_LENGTH);

   // incremental phase variation
   // MATLAB: dp = diff(p, 1, 1);
    for (j = 0; j < N-1; j++)
      dp[j] = p[j+1] - p[j];

   // equivalent phase variation in [-pi, pi]
   // MATLAB: dps = mod(dp+dp,2*pi) - pi;
    for (j = 0; j < N-1; j++)
      dps[j] = (dp[j]+M_PI) - MathFloor((dp[j]+M_PI) / (2*M_PI))*(2*M_PI) - M_PI;

   // preserve variation sign for +pi vs. -pi
   // MATLAB: dps(dps==pi & dp>0,:) = pi;
    for (j = 0; j < N-1; j++)
      if ((dps[j] == -M_PI) && (dp[j] > 0))
        dps[j] = M_PI;

   // incremental phase correction
   // MATLAB: dp_corr = dps - dp;
    for (j = 0; j < N-1; j++)
      dp_corr[j] = dps[j] - dp[j];

   // Ignore correction when incremental variation is smaller than cutoff
   // MATLAB: dp_corr(abs(dp)<cutoff,:) = 0;
    for (j = 0; j < N-1; j++)
      if (MathAbs(dp[j]) < cutoff)
        dp_corr[j] = 0;

   // Find cumulative sum of deltas
   // MATLAB: cumsum = cumsum(dp_corr, 1);
    cumsum[0] = dp_corr[0];
    for (j = 1; j < N-1; j++)
      cumsum[j] = cumsum[j-1] + dp_corr[j];

   // Integrate corrections and add to P to produce smoothed phase values
   // MATLAB: p(2:m,:) = p(2:m,:) + cumsum(dp_corr,1);
    for (j = 1; j < N; j++)
    {
        p[j] += cumsum[j-1];

        if (DEBUG == 1)
        {
            Print ("phase_unwrapped[", DoubleToStr(j,0), "] ", DoubleToStr(p[j],10));
            file_result = FileWrite (file_handle, "phase_unwrapped", j, p[j]);
        }
    }
}

//-----------------------------------------------------------------------------------------------
// Code adapted by E Farrell 2013
// from original at:
// www.ccas.ru/mmes/educat/lab04k/02/least-squares.c

void calc_regression (double y[], int n)
{
   // initialise array
   // to hold x values
   double x[];
   ArrayResize (x, n);

   int i;
   double SUMx, SUMy, SUMxy, SUMxx;
   double slope, y_intercept;

   SUMx = 0;
   SUMy = 0;
   SUMxy = 0;
   SUMxx = 0;

   for (i=0; i < n; i++)
   {
     x[i] = i;
     SUMx = SUMx + x[i];
     SUMy = SUMy + y[i];

     SUMxy = SUMxy + x[i]*y[i];
     SUMxx = SUMxx + x[i]*x[i];
   }

   // formula for regression line
   slope       = (SUMx*SUMy - n*SUMxy) / (SUMx*SUMx - n*SUMxx);
   y_intercept = (SUMy - slope*SUMx) / n;

   // create the regression line
   // using the formula from above
   for (i=0; i < n; i++)
   {
     least_squares_line[i] = slope*x[i] + y_intercept;
   }
}

//-----------------------------------------------------------------------------------------------
void calc_phase_adjusted (int n)
{
   // Basically just "pull down" the
   // unwrapped phase line so that
   // it hugs closely to the X-Axis

   for (int i=0; i < n; i++)
   {
     phase_adjusted[i] = phase_unwrapped[i] - least_squares_line[i];
   }
}

//-----------------------------------------------------------------------------------------------
void BuildRArray (int Lookback, int startIndex, double Base_Array[])
{
   for(int t = startIndex; t <= Lookback + startIndex; t++)
      R[t-startIndex] = (MathLog(Base_Array[t]));
}

//-----------------------------------------------------------------------------------------------
double GetHurstExponent (int Lookback, double T[], double R[])
{
   // Calculate the best fit for R & T
   double sumOfRTProduct = GetSumOfArrayElementProducts(T,R,Lookback);
   double productOfRTSums = GetProductOfRTSums(T,R,Lookback);

   double squaredSumOfT = GetSquaredSum(T,Lookback);
   double sumOfTSquaredElements = GetSumOfSquaredElements(T,Lookback);

   return ( (productOfRTSums - (Lookback * sumOfRTProduct)) / (squaredSumOfT - (Lookback * sumOfTSquaredElements)) );
}

//-----------------------------------------------------------------------------------------------
double GetSumOfArrayElementProducts (double a[], double b[], int Lookback)
{
   double sum = 0;

   for(int t = 0; t < Lookback; t++)
      sum += ( a[t] * b[t] );

   return (sum);
}

//-----------------------------------------------------------------------------------------------
double GetProductOfRTSums (double a[], double b[], int Lookback)
{
   double sumA = 0;
   double sumB = 0;

   for(int t = 0; t < Lookback; t++) {
      sumA += a[t];
      sumB += b[t];
   }

   //show = StringConcatenate("Sum A: ", DoubleToStr(sumA,4), "; Sum B: ", DoubleToStr(sumB,4), "\n");

   return (sumA * sumB);
}

//-----------------------------------------------------------------------------------------------
double GetSquaredSum (double b[], int Lookback)
{
   double sum = 0;

   for(int t = 0; t < Lookback; t++)
      sum += b[t];

   return (sum * sum);
}

//-----------------------------------------------------------------------------------------------
double GetSumOfSquaredElements (double b[], int Lookback) {

   double sum = 0;

   for(int t = 0; t < Lookback; t++)
      sum += ( b[t] * b[t] );

   return (sum);
}
