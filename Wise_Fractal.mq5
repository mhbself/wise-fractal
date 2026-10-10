/* ------------------------------------------------------------------ *
** Wise_Fractal.mq5 — version 5.60 
** Copyright 2024, M.H.B
** Algorithm developed by M.H.B
** Discription (Finglish):
** In version nesbat be version 5.3 dar nahve taeen swing-e mo'tabar fargh dare.
** Be in sorat ke age swing-e up teshkil beshe va bad az un ye swing-e low-e dige
** teshkil beshe be sorati ke in swing-e low az swing-e low-e swing-e mo'tabar-e ghabl
** paeintar bashe, be onvan-e swing-e mo'tabar taeen mishe. 
** Change in Pips and Points
** Change in Reverse Position Elimination with Take Profit and Break Even
** Double Retracement
** ------------------------------------------------------------------ */

#property copyright "Copyright 2024, M.H.B"
#property link      "https://github.com/mhbself/wise-fractal"
#property version   "5.60"

#include <Trade/Trade.mqh>
CTrade Trade;

enum with_t
{     
  Line1 = 1,
  Line2 = 2,
  Line3 = 3,
  Line4 = 4,
  Line5 = 5,
};

enum target_t
{
	None = 0,
	Seller,
	Buyer,
	Both,
};

input group "Expiration"
input string Expiration = "===== The expiration date is 2025-06-30 =====";

input group "Risk Management"
input string RiskManagement = "===== Risk Management ====="; // Risk Management:
input double RiskPercent = 1.0;
input double RiskOnReward = 3.0;
input double RiskFree = 1.8;
input double RiskFreeSLOffset = 0;
input double StopLossOffset = 0;
input double PipAlertX = 7.47;
input double Retracement = 40.0;
input int SecondOffset = 0;

input group "Reverse Position"
input string ReversePosition = "===== Reverse Position ====="; // Reverse Position:
input bool ReversePositionEN = true;
input int DownLimit = 50;
input int UpLimit = 285;
input int UpLimitForSet = 185;

input group "Fractal Settings"
input string FractalParameters = "===== Fractal Parameters ====="; // Fractal Parameters:
input int FractalsNumber = 14;                      // 1. Fractals Number
input int DayNumber = 1;                          // 2. Day Number
input int StartHour = 16;                           // 3. StartHour
input int StartMinute = 30;                         // 4. Start Minute
input string FractalGraphics = "===== Fractal Graphics ====="; // Fractal Graphics:
input color UpFractalClr = clrOrange;             // 1. Up
input color DownFractalClr = clrGreenYellow;      // 2. Down
input with_t WithFractal = Line2;                     // 3. With
input ENUM_LINE_STYLE StyleFractal = STYLE_SOLID;   // 4. Style                                          

input group "Swing Parameters"
input string SwingParameters = "===== Swing Parameters =====";   //Swing Parameters:
input int CandleNumber = 0;                         // 1. Candle Number
input int DrawingStartOffset  = 2;                  // 2. Drawing Start Offset 
input int EndHour = 18;                             // 3. End Hour
input int EndMinute = 0;                           // 4. End Minute
input string SwingGraphics = "===== Fractal Graphics ====="; // Swing Graphics:
input color SwingLinesClr = C'212,202,183';       // 1. Swing Lines
input color ValidSwingUpClr = clrChartreuse;      // 2. Valid Swing Up
input color ValidSwingDownClr = clrDarkOrange;    // 3. Valid Swing Down

input group "Target Graphics"
input string TargetGraphics = "===== Target Graphics =====";  //Target Graphics:
input color TargetSellerArrowClr = clrDarkOrange; // 1. Target Seller Arrow
input color TargetBuyerArrowClr = clrChartreuse;  // 2. Target Buyer Arrow

input group "Order Comment"
input string OrderComment = "===== Order Comment =====";  //Order Comment:
input string BuyPosition = "Buy Position";
input string SellPosition = "Sell Position";
input string ReverseBuyPosition = "Reverse BuyPosition";
input string ReverseSellPosition = "Reverse SellPosition";

datetime ExpirationTime = D'2025.06.30 23:59:59';

target_t Target = None;
MqlDateTime LastStartDateTime, SetMqlDateTime;
datetime StartDateTime, EndDateTime, SellerTargetTime, BuyerTargetTime;
string BankHolidays[] = {"2025.01.01", "2025.01.20", "2025.02.12", "2025.02.17", "2025.05.26", "2025.06.19", "2025.07.04",
							"2025.09.01", "2025.10.13", "2025.11.04", "2025.11.11", "2025.11.27", "2025.12.25"};

bool Holiday = false, TargetLock = false, SetOrder = true, OrderIsOpen = false, FractalDirection[];
int FractalHandle, FractalCount = 0, ValidUpFractalCount = 0, ValidDownFractalCount = 0,
	 BuyerValidSwingTime, SellerValidSwingTime, FractalDateTime[];
double FractalUpValue = 0, FractalDownValue = 0, FractalValue[];
double SellerValidSwingValue = 0, BuyerValidSwingValue = 0, Pip = 1, PipAlert = 0;
int LastDeals = 0;
ulong OrderTicket = 0, ReverseOrderTicket = 0;

double OnTester()
{
   // Read critertions
   double Profit         = TesterStatistics(STAT_PROFIT);
   double Drawdown       = TesterStatistics(STAT_EQUITYDD_PERCENT);
   double TotalTrades    = TesterStatistics(STAT_TRADES);
   double PrfitTrades    = TesterStatistics(STAT_PROFIT_TRADES);
   double RecoveryFactor = TesterStatistics(STAT_RECOVERY_FACTOR);
   double ProfitFactor   = TesterStatistics(STAT_PROFIT_FACTOR);
   double SharpeRatio    = TesterStatistics(STAT_SHARPE_RATIO);
	double WinRate        = PrfitTrades / TotalTrades * 100;

   // if (SharpeRatio < 2.0 || SharpeRatio > 10.0)
   //    return(0.0); // Zeroing the score

   // Preventing division by zero in Drawdown
   if (Drawdown <= 0.0)
		Drawdown = 0.0001;

	if (Drawdown > 9.5)
		return(0.0); // Zeroing the score
	
   double Score = Profit
   //              * WinRate
   //              * RecoveryFactor
   //              * ProfitFactor
   //              * SharpeRatio
                / Drawdown;

	// double Score = Profit;
	// double Score = WinRate / TotalTrades * 100;
	// double Score = RecoveryFactor;
	// double Score = ProfitFactor;
	// double Score = SharpeRatio;
	// double Score = Drawdown;

   return(Score);
}

int OnInit()
{
	long digits = SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   Pip = point * (digits == 2 ? 10 : 1);

   StartDateTime = iTime(_Symbol, _Period, 0);
	EndDateTime = iTime(_Symbol, _Period, 0);

   TimeToStruct(StartDateTime, SetMqlDateTime);

	SetMqlDateTime.hour = StartHour;
	SetMqlDateTime.min = StartMinute;
	StartDateTime = StructToTime(SetMqlDateTime);

	SetMqlDateTime.hour = EndHour;
	SetMqlDateTime.min = EndMinute;
	EndDateTime = StructToTime(SetMqlDateTime);

	FractalHandle = iFractals(_Symbol, _Period);

	Fractal();
	Swing();
   	
	return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0);
}  

void OnTick()
{
	datetime OnDateTime = iTime(_Symbol, _Period, 0);
	MqlDateTime OnMqlDateTime;
	TimeToStruct(OnDateTime, OnMqlDateTime);

	datetime OnLocalTime = TimeLocal();
	MqlDateTime OnMqlLocalTime;
	TimeToStruct(OnLocalTime, OnMqlLocalTime);

	if (OnDateTime <= ExpirationTime)
	{
		if (OrderIsOpen)
		{
			if (HistorySelect(0, TimeCurrent()))
			{
				int NewDeals = HistoryDealsTotal();
				ulong LastDealTicket = HistoryDealGetTicket(NewDeals - 1);
				double Profit;

				if ((NewDeals - LastDeals) > 0)
				{
					if (HistoryDealGetDouble(LastDealTicket, DEAL_PROFIT, Profit))
					{
						double RiskAmount50Per100 = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / (-200);

						if (Profit > RiskAmount50Per100)
						{
							if (OrderSelect(ReverseOrderTicket))
							{
								if ((OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) ||
										(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP))
								{
									if (Trade.OrderDelete(ReverseOrderTicket))
										PrintFormat("Order deleted successfully.");
									
									else
										Print("Failed to delete limit order: ", GetLastError());
								}
							}
						}
					}
				}
			}

			if (ObjectFind(0, "Buy Open Order Line") >= 0)
			{
				double BidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
				double StopLoss = ObjectGetDouble(0, "Buy Stop Loss Line", OBJPROP_PRICE);
				double OpenPrice = ObjectGetDouble(0, "Buy Open Order Line", OBJPROP_PRICE);
				double StopLossPip = OpenPrice - StopLoss;

				if (BidPrice >= (OpenPrice + (StopLossPip * RiskFree)))
				{
					double TakeProfit = ObjectGetDouble(0, "Buy Take Profit Line", OBJPROP_PRICE);
					StopLoss = (OpenPrice + (RiskFreeSLOffset * Pip));

					Trade.PositionModify(OrderTicket, StopLoss, TakeProfit);
				}
			}

			else if (ObjectFind(0, "Sell Open Order Line") >= 0)
			{
				double AskPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
				double StopLoss = ObjectGetDouble(0, "Sell Stop Loss Line", OBJPROP_PRICE);
				double OpenPrice = ObjectGetDouble(0, "Sell Open Order Line", OBJPROP_PRICE);
				double StopLossPip = StopLoss - OpenPrice;

				if (AskPrice <= (OpenPrice - (StopLossPip * RiskFree)))
				{
					double TakeProfit = ObjectGetDouble(0, "Sell Take Profit Line", OBJPROP_PRICE);
					StopLoss = (OpenPrice - (RiskFreeSLOffset * Pip));

					Trade.PositionModify(OrderTicket, StopLoss, TakeProfit);
				}
			}
		}

		if ((SetMqlDateTime.year == OnMqlDateTime.year) && (SetMqlDateTime.mon == OnMqlDateTime.mon) &&
			(SetMqlDateTime.day == OnMqlDateTime.day))
		{
			if (!Holiday)
			{
				if (IsHoliday(OnDateTime))
					Holiday = true;

				else
				{
					if (OnDateTime >= StartDateTime)
					{	
						if (!OrderIsOpen)
						{
							if (PositionsTotal() > 0)
								OrderIsOpen = true;
							
							if (HistorySelect(0, TimeCurrent()))
								LastDeals = HistoryDealsTotal();
						}
								
						if ((LastStartDateTime.min != OnMqlDateTime.min) &&
							 (OnMqlLocalTime.sec >= SecondOffset))
						{
							LastStartDateTime.min = OnMqlDateTime.min;
							
							FractalHandle = iFractals(_Symbol, _Period);

							if (OnDateTime == StartDateTime)
							{
								BuyerValidSwingTime = ((StartHour - 2) * 60) + StartMinute;
								SellerValidSwingTime = ((StartHour - 2) * 60) + StartMinute;

								BuyerValidSwingValue = 0.0;
								SellerValidSwingValue = 0.0;	

								Target = None;
								SetOrder = true;
								TargetLock = false;
								OrderIsOpen = false;	

								if (ObjectFind(0, "Sell First Line") >= 0)
									ObjectDelete(0, "Sell First Line");
								if (ObjectFind(0, "Sell Stop Loss Line") >= 0)
									ObjectDelete(0, "Sell Stop Loss Line");
								if (ObjectFind(0, "Sell Open Order Line") >= 0)
									ObjectDelete(0, "Sell Open Order Line");
								if (ObjectFind(0, "Sell Take Profit Line") >= 0)
									ObjectDelete(0, "Sell Take Profit Line");

								if (ObjectFind(0, "Buy First Line") >= 0)
									ObjectDelete(0, "Buy First Line");
								if (ObjectFind(0, "Buy Stop Loss Line") >= 0)
									ObjectDelete(0, "Buy Stop Loss Line");
								if (ObjectFind(0, "Buy Open Order Line") >= 0)
									ObjectDelete(0, "Buy Open Order Line");
								if (ObjectFind(0, "Buy Take Profit Line") >= 0)
									ObjectDelete(0, "Buy Take Profit Line");

								Fractal();
								Swing();
							}
							
							else if (OnDateTime < EndDateTime)
							{
								SwingUpdate();
								SetTarget();
								ValidSwing();

								if (((OnMqlDateTime.hour * 60) + OnMqlDateTime.min) - ((StartHour * 60) + StartMinute) > 1)
									CheckToSetOrder();

								UpdateOrder();
							}

							else if (OnDateTime == EndDateTime)
							{
								if (OrderSelect(OrderTicket))
								{
									if ((OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT) ||
										(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT))
									{
										if (Trade.OrderDelete(OrderTicket))
											PrintFormat("Order deleted successfully.");
										
										else
											Print("Failed to delete sell limit order: ", GetLastError());
									}
								}
							
								if (!OrderIsOpen)
								{
									if (OrderSelect(ReverseOrderTicket))
									{
										if ((OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) ||
											(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP))
										{
											if (Trade.OrderDelete(ReverseOrderTicket))
												PrintFormat("Order deleted successfully.");
											
											else
												Print("Failed to delete sell limit order: ", GetLastError());
										}
									}
								}
							}

							MqlDateTime MqlTime;
							TimeToStruct(OnDateTime, MqlTime);

							if (((MqlTime.hour * 60) + MqlTime.min)  == 1380)
							{
								if (OrderSelect(ReverseOrderTicket))
								{
									if ((OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) ||
										(OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP))
									{
										if (Trade.OrderDelete(ReverseOrderTicket))
											PrintFormat("Order deleted successfully.");
										
										else
											Print("Failed to delete sell limit order: ", GetLastError());
									}
								}
							}
						}
					}
				}
			}
		}
		
		else
		{
			Holiday = false;

			SetMqlDateTime.year = OnMqlDateTime.year;
			SetMqlDateTime.mon = OnMqlDateTime.mon;
			SetMqlDateTime.day = OnMqlDateTime.day;
			
			SetMqlDateTime.hour = StartHour;
			SetMqlDateTime.min = StartMinute;
			StartDateTime = StructToTime(SetMqlDateTime);

			SetMqlDateTime.hour = EndHour;
			SetMqlDateTime.min = EndMinute;
			EndDateTime = StructToTime(SetMqlDateTime);
		}
	}

	else
	{
      Print("This expert has expired. Please contact support.");
      ExpertRemove();
      return;
   }
}

bool IsHoliday(datetime Date)
{
   string DateString = TimeToString(Date, TIME_DATE);

   for(int i = 0; i < ArraySize(BankHolidays); i++)
	{
      if(DateString == BankHolidays[i])
         return true;
   }
   return false;
}

void Fractal(void)
{
	MqlDateTime MqlTime;
	datetime PrimaryTime = iTime(_Symbol, _Period, 0), SeconderyTime;
	
	TimeToStruct(PrimaryTime, MqlTime);
	
	double UpFractalArray[];
	double DownFractalArray[];
	
	ArraySetAsSeries(UpFractalArray, true);
	ArraySetAsSeries(DownFractalArray, true);
		
	int StartBar = 0;
	ValidUpFractalCount = 0;
	ValidDownFractalCount = 0;
  
	for (int Day = 0; Day < DayNumber; Day++)
	{    
		if (Day == 0)
		{
			if ((MqlTime.hour > StartHour) || ((MqlTime.hour == StartHour) && (MqlTime.min > StartMinute)))
			{
				MqlTime.hour = StartHour;
				MqlTime.min = StartMinute - 1;
				MqlTime.sec = 0;
			}
			
			else
				MqlTime.min--;
		
			PrimaryTime = StructToTime(MqlTime);
				
			StartBar = iBarShift(_Symbol, _Period, PrimaryTime);

			for (int Index = 1; Index <= FractalsNumber; Index++)
			{
				if (ObjectFind(0, ("UpFractal " + (string) Index)) >= 0)
					ObjectDelete(0, ("UpFractal " + (string) Index));

				if (ObjectFind(0, ("DownFractal " + (string) Index)) >= 0)
					ObjectDelete(0, ("DownFractal " + (string) Index));
			}
		}
    
		else
		{
			MqlTime.hour = 23;
			MqlTime.min = 54;
			MqlTime.sec = 0;
	
			PrimaryTime = StructToTime(MqlTime);
		}
    
		MqlTime.hour = 0;
		MqlTime.min = 0;
		MqlTime.sec = 0;
		
		SeconderyTime = StructToTime(MqlTime);		
	
		CopyBuffer(FractalHandle, UPPER_LINE, PrimaryTime, SeconderyTime, UpFractalArray);
		CopyBuffer(FractalHandle, LOWER_LINE, PrimaryTime, SeconderyTime, DownFractalArray);
		
		ArrayRemove(FractalDirection, 1, ArraySize(FractalDirection));
		ArrayRemove(FractalDateTime, 1, ArraySize(FractalDateTime));
		ArrayRemove(FractalValue, 1, ArraySize(FractalValue));

		ArrayResize(FractalDirection, ArraySize(UpFractalArray));
		ArrayResize(FractalDateTime, ArraySize(UpFractalArray));
		ArrayResize(FractalValue, ArraySize(UpFractalArray));
		
		for (int Index = 0; Index < ArraySize(UpFractalArray); Index++)
		{
			double UpFractalValue = NormalizeDouble(UpFractalArray[Index], Digits());
			double DownFractalValue = NormalizeDouble(DownFractalArray[Index], Digits());
			
			if (UpFractalValue != EMPTY_VALUE)
			{
				int StartIndex = iBarShift(_Symbol, _Period, PrimaryTime);
				int Shift = Index + StartIndex - StartBar;
				
				if (Shift < 0)
					Shift = 0;
				
				double Price = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, Shift, StartBar));

				if (((UpFractalValue > Price) && (ValidUpFractalCount <= FractalsNumber)) || ((Index == 0) && Day == 0))
				{
					datetime Time = iTime(_Symbol, _Period, (Index + StartIndex - 1));
					MqlDateTime MqlTimeL;
					TimeToStruct(Time, MqlTimeL);
					MqlTimeL.min--;
					Time = StructToTime(MqlTimeL);

					if (ValidUpFractalCount == 0)
						FractalUpValue = UpFractalValue;

					ObjectCreate(0, ("UpFractal " + (string) Time), OBJ_ARROW, 0, Time, UpFractalValue);
					ObjectSetInteger(0, ("UpFractal " + (string) Time), OBJPROP_ARROWCODE, 217);
					ObjectSetInteger(0, ("UpFractal " + (string) Time), OBJPROP_COLOR, UpFractalClr);
					ObjectSetInteger(0, ("UpFractal " + (string) Time), OBJPROP_WIDTH, WithFractal);
					ObjectSetInteger(0, ("UpFractal " + (string) Time), OBJPROP_STYLE, StyleFractal);
					ObjectSetInteger(0, ("UpFractal " + (string) Time), OBJPROP_ANCHOR, ANCHOR_BOTTOM);
					ObjectSetInteger(0, ("UpFractal " + (string) Time), OBJPROP_SELECTABLE, false);
					
					ValidUpFractalCount++;
				}
			}
			
			if (DownFractalValue != EMPTY_VALUE)
			{
				int StartIndex = iBarShift(_Symbol, _Period, PrimaryTime);
				int Shift = Index + StartIndex - StartBar;
				
				if (Shift < 0)
						Shift = 0;
						
				double Price = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, Shift, StartBar));
				
				if (((DownFractalValue < Price) && (ValidDownFractalCount <= FractalsNumber)) || ((Index == 0) && Day == 0))
				{
					datetime Time = iTime(_Symbol, _Period, (Index + StartIndex - 1));
					MqlDateTime MqlTimeL;
					TimeToStruct(Time, MqlTimeL);
					MqlTimeL.min--;
					Time = StructToTime(MqlTimeL);

					if (ValidDownFractalCount == 0)
						FractalDownValue = DownFractalValue;
					
					ObjectCreate(0, ("DownFractal " + (string) Time), OBJ_ARROW, 0, Time, DownFractalValue);
					ObjectSetInteger(0, ("DownFractal " + (string) Time), OBJPROP_ARROWCODE, 218);
					ObjectSetInteger(0, ("DownFractal " + (string) Time), OBJPROP_COLOR, DownFractalClr);
					ObjectSetInteger(0, ("DownFractal " + (string) Time), OBJPROP_WIDTH, WithFractal);
					ObjectSetInteger(0, ("DownFractal " + (string) Time), OBJPROP_STYLE, StyleFractal);
					ObjectSetInteger(0, ("DownFractal " + (string) Time), OBJPROP_ANCHOR, ANCHOR_TOP);
					ObjectSetInteger(0, ("DownFractal " + (string) Time), OBJPROP_SELECTABLE, false);
					
					ValidDownFractalCount++;
				}
			}
			
			if ((ValidUpFractalCount >= FractalsNumber) && (ValidDownFractalCount >= FractalsNumber))
			{
				Day = DayNumber;
				Index = ArraySize(UpFractalArray);
			}
		}
		
		MqlTime.day--;
		PrimaryTime = StructToTime(MqlTime);
		TimeToStruct(PrimaryTime, MqlTime);
			
		if (MqlTime.day_of_week == 0)
		{
			MqlTime.day = MqlTime.day - 2;
			MqlTime.day_of_week = 5;
		}
			
		if (MqlTime.day_of_week == 6)
		{
			MqlTime.day--;
			MqlTime.day_of_week = 5;
		}
	}
}

void Swing(void)
{
	datetime SeconderyTime, SwingPrimaryTime = iTime(_Symbol, _Period, 0);

	MqlDateTime MqlTime;
	TimeToStruct(SwingPrimaryTime, MqlTime);

	int StartBar = (MqlTime.hour * 60) + MqlTime.min;
	int EndBar = (EndHour * 60) + EndMinute;

	if (StartBar > EndBar)
	{
		StartBar = EndBar;

		MqlTime.hour = EndHour;
		MqlTime.min = EndMinute;
	}
	
	if (MqlTime.hour >= DrawingStartOffset)
		MqlTime.hour = MqlTime.hour - DrawingStartOffset;

	else
		MqlTime.hour = 23 + MqlTime.hour - DrawingStartOffset;
	
	SeconderyTime = StructToTime(MqlTime);
	
	double UpFractalArray[];
	double DownFractalArray[];
	
	ArraySetAsSeries(UpFractalArray, true);
	ArraySetAsSeries(DownFractalArray, true);

	CopyBuffer(FractalHandle, UPPER_LINE, SwingPrimaryTime, SeconderyTime, UpFractalArray);
	CopyBuffer(FractalHandle, LOWER_LINE, SwingPrimaryTime, SeconderyTime, DownFractalArray);
	
	bool firstInit = false;
	FractalCount = 0;

	for (int Index = (ArraySize(UpFractalArray) - 1); Index >= 0; Index--)
	{
		double UpFractalValue = NormalizeDouble(UpFractalArray[Index], Digits());
		double DownFractalValue = NormalizeDouble(DownFractalArray[Index], Digits());
			
		if (UpFractalValue != EMPTY_VALUE)
		{
			if (!firstInit)
			{
				firstInit = true;
				FractalDirection[FractalCount] = true;
				FractalDateTime[FractalCount] = StartBar - Index;
				FractalValue[FractalCount] = UpFractalValue;
			}
			
			else
			{
				if (FractalDirection[FractalCount] == true)
				{
					if (UpFractalValue > FractalValue[FractalCount])
					{
						FractalDateTime[FractalCount] = StartBar - Index;
						FractalValue[FractalCount] = UpFractalValue;

						if (FractalCount > 0)
						{
							MqlTime.hour = FractalDateTime[FractalCount] / 60;
							MqlTime.min = FractalDateTime[FractalCount] % 60;
							datetime Time1  = StructToTime(MqlTime);

							MqlTime.hour = FractalDateTime[FractalCount - 1] / 60;
							MqlTime.min = FractalDateTime[FractalCount - 1] % 60;
							datetime Time2  = StructToTime(MqlTime);

							if (ObjectFind(0, ("TrendLine " + (string) Time2)) >= 0)
								ObjectDelete(0, ("TrendLine " + (string) Time2));
								
							ObjectCreate(0, ("TrendLine " + (string) Time2), OBJ_TREND, 0, Time1, FractalValue[FractalCount], Time2, FractalValue[FractalCount - 1]);
							ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_COLOR, SwingLinesClr);
							ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_WIDTH, 2);
							ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_STYLE, STYLE_SOLID);
							ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_SELECTABLE, false);
						}
					}
				}
				
				else if ((StartBar - Index - FractalDateTime[FractalCount] > CandleNumber) && (FractalValue[FractalCount] < UpFractalValue))
				{
					FractalCount++;
					FractalDirection[FractalCount] = true;
					FractalDateTime[FractalCount] = StartBar - Index;
					FractalValue[FractalCount] = UpFractalValue;

					MqlTime.hour = FractalDateTime[FractalCount] / 60;
					MqlTime.min = FractalDateTime[FractalCount] % 60;
					datetime Time1  = StructToTime(MqlTime);

					MqlTime.hour = FractalDateTime[FractalCount - 1] / 60;
					MqlTime.min = FractalDateTime[FractalCount - 1] % 60;
					datetime Time2  = StructToTime(MqlTime);
					
					ObjectCreate(0, ("TrendLine " + (string) Time2), OBJ_TREND, 0, Time1, FractalValue[FractalCount], Time2, FractalValue[FractalCount - 1]);
					ObjectSetInteger(0, ("TrendLin " + (string) Time2), OBJPROP_COLOR, SwingLinesClr);
					ObjectSetInteger(0, ("TrendLin " + (string) Time2), OBJPROP_WIDTH, 2);
					ObjectSetInteger(0, ("TrendLin " + (string) Time2), OBJPROP_STYLE, STYLE_SOLID);
					ObjectSetInteger(0, ("TrendLin " + (string) Time2), OBJPROP_SELECTABLE, false);
				}
			}
		}
			
		else if (DownFractalValue != EMPTY_VALUE)
		{
			if (!firstInit)
			{
				firstInit = true;
				FractalDirection[FractalCount] = false;
				FractalDateTime[FractalCount] = StartBar - Index;
				FractalValue[FractalCount] = DownFractalValue;
			}
			
			else
			{
				if (FractalDirection[FractalCount] == false)
				{
					if (DownFractalValue < FractalValue[FractalCount])
					{
						FractalDateTime[FractalCount] = StartBar - Index;
						FractalValue[FractalCount] = DownFractalValue;

						if (FractalCount > 0)
						{
							MqlTime.hour = FractalDateTime[FractalCount] / 60;
							MqlTime.min = FractalDateTime[FractalCount] % 60;
							datetime Time1  = StructToTime(MqlTime);

							MqlTime.hour = FractalDateTime[FractalCount - 1] / 60;
							MqlTime.min = FractalDateTime[FractalCount - 1] % 60;
							datetime Time2  = StructToTime(MqlTime);

							if (ObjectFind(0, ("TrendLine " + (string) Time1)) >= 0)
								ObjectDelete(0, ("TrendLine " + (string) Time1));
							
							ObjectCreate(0, ("TrendLine " + (string) Time2), OBJ_TREND, 0, Time1, FractalValue[FractalCount], Time2, FractalValue[FractalCount - 1]);
							ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_COLOR, SwingLinesClr);
							ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_WIDTH, 2);
							ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_STYLE, STYLE_SOLID);
							ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_SELECTABLE, false);
						}
					}
				}
				
				else if ((StartBar - Index - FractalDateTime[FractalCount] > CandleNumber) && (FractalValue[FractalCount] > DownFractalValue))
				{
					FractalCount++;
					FractalDirection[FractalCount] = false;
					FractalDateTime[FractalCount] = StartBar - Index;
					FractalValue[FractalCount] = DownFractalValue;

					MqlTime.hour = FractalDateTime[FractalCount] / 60;
					MqlTime.min = FractalDateTime[FractalCount] % 60;
					datetime Time1  = StructToTime(MqlTime);

					MqlTime.hour = FractalDateTime[FractalCount - 1] / 60;
					MqlTime.min = FractalDateTime[FractalCount - 1] % 60;
					datetime Time2  = StructToTime(MqlTime);
					
					ObjectCreate(0, ("TrendLine " + (string) Time2), OBJ_TREND, 0, Time1, FractalValue[FractalCount], Time2, FractalValue[FractalCount - 1]);
					ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_COLOR, SwingLinesClr);
					ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_WIDTH, 2);
					ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_STYLE, STYLE_SOLID);
					ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_SELECTABLE, false);
				}
			}
		}
	}
}

void SwingUpdate(void)
{
	datetime SeconderyTime, SwingPrimaryTime = iTime(_Symbol, _Period, 0);

	MqlDateTime MqlTime;
	TimeToStruct(SwingPrimaryTime, MqlTime);

	int StartBar = (MqlTime.hour * 60) + MqlTime.min - 3;
	
	if (MqlTime.hour >= DrawingStartOffset)
		MqlTime.hour = MqlTime.hour - DrawingStartOffset;

	else
		MqlTime.hour = 23 + MqlTime.hour - DrawingStartOffset;
	
	SeconderyTime = StructToTime(MqlTime);
	
	double UpFractalArray[];
	double DownFractalArray[];
	
	ArraySetAsSeries(UpFractalArray, true);
	ArraySetAsSeries(DownFractalArray, true);
	
	CopyBuffer(FractalHandle, UPPER_LINE, SwingPrimaryTime, SeconderyTime, UpFractalArray);
	CopyBuffer(FractalHandle, LOWER_LINE, SwingPrimaryTime, SeconderyTime, DownFractalArray);
	
	double UpFractalValue = NormalizeDouble(UpFractalArray[3], Digits());
	double DownFractalValue = NormalizeDouble(DownFractalArray[3], Digits());
	
   if (UpFractalValue != EMPTY_VALUE)
	{
		if (FractalDirection[FractalCount] == true)
		{
			if (UpFractalValue > FractalValue[FractalCount])
			{
				FractalDateTime[FractalCount] = StartBar;
				FractalValue[FractalCount] = UpFractalValue;

				if (FractalCount > 0)
				{
					MqlTime.hour = FractalDateTime[FractalCount] / 60;
					MqlTime.min = FractalDateTime[FractalCount] % 60;
					datetime Time1  = StructToTime(MqlTime);

					MqlTime.hour = FractalDateTime[FractalCount - 1] / 60;
					MqlTime.min = FractalDateTime[FractalCount - 1] % 60;
					datetime Time2  = StructToTime(MqlTime);

					if (ObjectFind(0, ("TrendLine " + (string) Time2)) >= 0)
						ObjectDelete(0, ("TrendLine " + (string) Time2));

					ObjectCreate(0, ("TrendLine " + (string) Time2), OBJ_TREND, 0, Time1, FractalValue[FractalCount], Time2, FractalValue[FractalCount - 1]);
					ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_COLOR, SwingLinesClr);
					ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_WIDTH, 2);
					ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_STYLE, STYLE_SOLID);
					ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_SELECTABLE, false);
				}
			}
		}
		
		else if ((StartBar - FractalDateTime[FractalCount] > CandleNumber) && (FractalValue[FractalCount] < UpFractalValue))
		{
			FractalCount++;
			FractalDirection[FractalCount] = true;
			FractalDateTime[FractalCount] = StartBar;
			FractalValue[FractalCount] = UpFractalValue;

			MqlTime.hour = FractalDateTime[FractalCount] / 60;
			MqlTime.min = FractalDateTime[FractalCount] % 60;
			datetime Time1  = StructToTime(MqlTime);

			MqlTime.hour = FractalDateTime[FractalCount - 1] / 60;
			MqlTime.min = FractalDateTime[FractalCount - 1] % 60;
			datetime Time2  = StructToTime(MqlTime);

			ObjectCreate(0, ("TrendLine " + (string) Time2), OBJ_TREND, 0, Time1, FractalValue[FractalCount], Time2, FractalValue[FractalCount - 1]);
			ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_COLOR, SwingLinesClr);
			ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_WIDTH, 2);
			ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_STYLE, STYLE_SOLID);
			ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_SELECTABLE, false);
		}
	}
		
	else if (DownFractalValue != EMPTY_VALUE)
	{
		if (FractalDirection[FractalCount] == false)
		{
			if (DownFractalValue < FractalValue[FractalCount])
			{
				FractalDateTime[FractalCount] = StartBar;
				FractalValue[FractalCount] = DownFractalValue;

				if (FractalCount > 0)
				{
					MqlTime.hour = FractalDateTime[FractalCount] / 60;
					MqlTime.min = FractalDateTime[FractalCount] % 60;
					datetime Time1  = StructToTime(MqlTime);

					MqlTime.hour = FractalDateTime[FractalCount - 1] / 60;
					MqlTime.min = FractalDateTime[FractalCount - 1] % 60;
					datetime Time2  = StructToTime(MqlTime);

					if (ObjectFind(0, ("TrendLine " + (string) Time2)) >= 0)
						ObjectDelete(0, ("TrendLine " + (string) Time2));

					ObjectCreate(0, ("TrendLine " + (string) Time2), OBJ_TREND, 0, Time1, FractalValue[FractalCount], Time2, FractalValue[FractalCount - 1]);
					ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_COLOR, SwingLinesClr);
					ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_WIDTH, 2);
					ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_STYLE, STYLE_SOLID);
					ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_SELECTABLE, false);
				}
			}
		}
		
		else if ((StartBar - FractalDateTime[FractalCount] > CandleNumber) && (FractalValue[FractalCount] > DownFractalValue))
		{
			FractalCount++;
			FractalDirection[FractalCount] = false;
			FractalDateTime[FractalCount] = StartBar;
			FractalValue[FractalCount] = DownFractalValue;

			MqlTime.hour = FractalDateTime[FractalCount] / 60;
			MqlTime.min = FractalDateTime[FractalCount] % 60;
			datetime Time1  = StructToTime(MqlTime);

			MqlTime.hour = FractalDateTime[FractalCount - 1] / 60;
			MqlTime.min = FractalDateTime[FractalCount - 1] % 60;
			datetime Time2  = StructToTime(MqlTime);

			ObjectCreate(0, ("TrendLine " + (string) Time2), OBJ_TREND, 0, Time1, FractalValue[FractalCount], Time2, FractalValue[FractalCount - 1]);
			ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_COLOR, SwingLinesClr);
			ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_WIDTH, 2);
			ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_STYLE, STYLE_SOLID);
			ObjectSetInteger(0, ("TrendLine " + (string) Time2), OBJPROP_SELECTABLE, false);
		}
	}
}

void SetTarget(void)
{
	if ((Target != Both) && SetOrder && !OrderIsOpen && !TargetLock)
	{
		datetime Time = iTime(_Symbol, _Period, 1);

		double Price = iHigh(_Symbol, _Period, 1);

		if (Target != Seller)
		{
			if (ValidUpFractalCount == 0)
			{
				SetMqlDateTime.hour = StartHour;
				SetMqlDateTime.min = StartMinute - 1;
				datetime PreStartMinute = StructToTime(SetMqlDateTime);

				double PreStartPrice = iHigh(_Symbol, _Period, iBarShift(_Symbol, _Period, PreStartMinute));

				if (PreStartPrice <= Price)
				{
					if (Target == None)
						Target = Seller;
				
					else
						Target = Both;

					SellerTargetTime = Time;

					ObjectCreate(0, "We are Seller " + (string) Time, OBJ_ARROW_DOWN, 0, Time, (Price + (12 * Pip)));
					ObjectSetInteger(0, "We are Seller " + (string) Time, OBJPROP_COLOR, TargetSellerArrowClr);
					ObjectSetInteger(0, "We are Seller " + (string) Time, OBJPROP_WIDTH, 5);
					ObjectSetInteger(0, "We are Seller " + (string) Time, OBJPROP_STYLE, STYLE_SOLID);
					ObjectSetInteger(0, "We are Seller " + (string) Time, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
					ObjectSetInteger(0, "We are Seller " + (string) Time, OBJPROP_SELECTABLE, false);
				}
			}

			else if (FractalUpValue <= Price)
			{
				if (Target == None)
					Target = Seller;
				
				else
					Target = Both;

				SellerTargetTime = Time;

				ObjectCreate(0, "We are Seller " + (string) Time, OBJ_ARROW_DOWN, 0, Time, (Price + (12 * Pip)));
				ObjectSetInteger(0, "We are Seller " + (string) Time, OBJPROP_COLOR, TargetSellerArrowClr);
				ObjectSetInteger(0, "We are Seller " + (string) Time, OBJPROP_WIDTH, 5);
				ObjectSetInteger(0, "We are Seller " + (string) Time, OBJPROP_STYLE, STYLE_SOLID);
				ObjectSetInteger(0, "We are Seller " + (string) Time, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
				ObjectSetInteger(0, "We are Seller " + (string) Time, OBJPROP_SELECTABLE, false);
			}
		}

		Price = iLow(_Symbol, _Period, 1);

		if ((Target != Buyer) && (Target != Both))
		{
			if (ValidDownFractalCount == 0)
			{
				SetMqlDateTime.hour = StartHour;
				SetMqlDateTime.min = StartMinute - 1;
				datetime PreStartMinute = StructToTime(SetMqlDateTime);

				double PreStartPrice = iLow(_Symbol, _Period, iBarShift(_Symbol, _Period, PreStartMinute));

				if (PreStartPrice >= Price)
				{
					if (Target == None)
						Target = Buyer;
					
					else
						Target = Both;
					
					BuyerTargetTime = Time;

					ObjectCreate(0, "We are Buyer " + (string) Time, OBJ_ARROW_UP, 0, Time, (Price - (12 * Pip)));
					ObjectSetInteger(0, "We are Buyer " + (string) Time, OBJPROP_COLOR, TargetBuyerArrowClr);
					ObjectSetInteger(0, "We are Buyer " + (string) Time, OBJPROP_WIDTH, 5);
					ObjectSetInteger(0, "We are Buyer " + (string) Time, OBJPROP_STYLE, STYLE_SOLID);
					ObjectSetInteger(0, "We are Buyer " + (string) Time, OBJPROP_ANCHOR, ANCHOR_TOP);
					ObjectSetInteger(0, "We are Buyer " + (string) Time, OBJPROP_SELECTABLE, false);
				}
			}

			else if (FractalDownValue >= Price)
			{
				if (Target == None)
					Target = Buyer;
				
				else
					Target = Both;

				BuyerTargetTime = Time;

				ObjectCreate(0, "We are Buyer " + (string) Time, OBJ_ARROW_UP, 0, Time, (Price - (12 * Pip)));
				ObjectSetInteger(0, "We are Buyer " + (string) Time, OBJPROP_COLOR, TargetBuyerArrowClr);
				ObjectSetInteger(0, "We are Buyer " + (string) Time, OBJPROP_WIDTH, 5);
				ObjectSetInteger(0, "We are Buyer " + (string) Time, OBJPROP_STYLE, STYLE_SOLID);
				ObjectSetInteger(0, "We are Buyer " + (string) Time, OBJPROP_ANCHOR, ANCHOR_TOP);
				ObjectSetInteger(0, "We are Buyer " + (string) Time, OBJPROP_SELECTABLE, false);
			}
		}
	
		if (Target == Both)
		{
			if (BuyerTargetTime == SellerTargetTime)
			{
				int Bar = iBarShift(_Symbol, _Period, BuyerTargetTime);
				double CandleOpen = iOpen(_Symbol, _Period, Bar);
				double CandleClose = iClose(_Symbol, _Period, Bar);

				if (CandleOpen > CandleClose)
				{
					Target = Seller;
					TargetLock = true;
					ObjectDelete(0, "We are Buyer " + (string) BuyerTargetTime);
				}
				
				else
				{
					Target = Buyer;
					TargetLock = true;
					ObjectDelete(0, "We are Seller " + (string) SellerTargetTime);
				}
			}
		}
	}
}

void ValidSwing(void)
{
	if (SetOrder && !OrderIsOpen)
	{
		MqlDateTime OnMqlDateTime;
		datetime OnDateTime;

		if (Target == Buyer)
		{
			if (BuyerValidSwingTime == ((StartHour - 2) * 60) + StartMinute)
			{
				OnDateTime = iTime(_Symbol, _Period, 0);
				TimeToStruct(OnDateTime, OnMqlDateTime);

				for (int Index = (FractalCount - 1); Index >= 0; Index--)
				{
					if (FractalDirection[Index] == true)
					{
						bool AllowToSet = true;
						int Shift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[Index] - 2;
						double HighestOpen = iOpen(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_OPEN, Shift, 1));
						double HighestClose = iClose(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_CLOSE, Shift, 1));
						double MaxPrice = HighestClose;

						if (HighestOpen > HighestClose)
							MaxPrice = HighestOpen;

						if (FractalDateTime[Index] > ((StartHour * 60) + StartMinute))
						{
							int BeforeShift = FractalDateTime[Index] - ((StartHour * 60) + StartMinute);
							int AfterShift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[Index];

							double BeforeLowest = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, BeforeShift, AfterShift));
							double AfterLowest = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, AfterShift, 1));

							if (BeforeLowest < AfterLowest)
								AllowToSet = false;
						}

						if ((FractalValue[Index] > MaxPrice) && AllowToSet)
						{
							BuyerValidSwingTime = FractalDateTime[Index];
							BuyerValidSwingValue = FractalValue[Index];

							OnMqlDateTime.hour = FractalDateTime[Index] / 60;
							OnMqlDateTime.min = FractalDateTime[Index] % 60;
							OnDateTime = StructToTime(OnMqlDateTime);

							string ObjectName = "Buyer Valid Swing up " + (string) OnDateTime;

							ObjectCreate(0, ObjectName, OBJ_ARROW_CHECK, 0, OnDateTime, (FractalValue[Index] + (24 * Pip)));
							ObjectSetInteger(0, ObjectName, OBJPROP_COLOR, ValidSwingUpClr);
							ObjectSetInteger(0, ObjectName, OBJPROP_WIDTH, 3);
							ObjectSetInteger(0, ObjectName, OBJPROP_STYLE, STYLE_SOLID);
							ObjectSetInteger(0, ObjectName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
							ObjectSetInteger(0, ObjectName, OBJPROP_SELECTABLE, false);

							Index = -1;
						}
					}
				}

				if (BuyerValidSwingValue == 0.0)
				{
					int Shift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[FractalCount - 1] - 2;
					int Bar = iHighest(_Symbol, _Period, MODE_HIGH, Shift, 2);
					double HighestHigh = iHigh(_Symbol, _Period, Bar);

					if (HighestHigh > iClose(_Symbol, _Period, 1))
					{
						OnDateTime = iTime(_Symbol, _Period, Bar);
						TimeToStruct(OnDateTime, OnMqlDateTime);
						BuyerValidSwingTime = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min;
						BuyerValidSwingValue = HighestHigh;

						string ObjectName = "Buyer Valid Swing up " + (string) OnDateTime;

						ObjectCreate(0, ObjectName, OBJ_ARROW_CHECK, 0, OnDateTime, (BuyerValidSwingValue + (24 * Pip)));
						ObjectSetInteger(0, ObjectName, OBJPROP_COLOR, ValidSwingUpClr);
						ObjectSetInteger(0, ObjectName, OBJPROP_WIDTH, 3);
						ObjectSetInteger(0, ObjectName, OBJPROP_STYLE, STYLE_SOLID);
						ObjectSetInteger(0, ObjectName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
						ObjectSetInteger(0, ObjectName, OBJPROP_SELECTABLE, false);
					}
				}
			}

			else
			{
				OnDateTime = iTime(_Symbol, _Period, 1);
				TimeToStruct(OnDateTime, OnMqlDateTime);

				if ((FractalDirection[FractalCount - 1] == true) &&
					 ((BuyerValidSwingTime != FractalDateTime[FractalCount - 1]) ||
					  (FractalDateTime[FractalCount - 1] == (StartHour * 60) + StartMinute)))
				{
					int AfterShift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[FractalCount - 1];

               double AfterHighestClose = iClose(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_CLOSE, (AfterShift - 1), 1));
               double AfterHighestOpen = iOpen(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_OPEN, (AfterShift - 1), 1));
               double MaxHighest = AfterHighestClose;

               if (AfterHighestOpen > AfterHighestClose)
                  MaxHighest = AfterHighestOpen;

               if (FractalValue[FractalCount - 1] > MaxHighest)
               {
						int BeforeShift = FractalDateTime[FractalCount - 1] - BuyerValidSwingTime;
						double BeforeLowest = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, BeforeShift, (AfterShift + 1)));
 
                  if ((FractalValue[FractalCount] <= BeforeLowest) || (FractalDateTime[FractalCount - 1] == (StartHour * 60) + StartMinute))
                  {
                     BuyerValidSwingTime = FractalDateTime[FractalCount - 1];
                     BuyerValidSwingValue = FractalValue[FractalCount - 1];

                     OnMqlDateTime.hour = FractalDateTime[FractalCount - 1] / 60;
                     OnMqlDateTime.min = FractalDateTime[FractalCount - 1] % 60;
                     OnDateTime = StructToTime(OnMqlDateTime);

							string ObjectName = "Buyer Valid Swing up " + (string) OnDateTime;

                     ObjectCreate(0, ObjectName, OBJ_ARROW_CHECK, 0, OnDateTime, (FractalValue[FractalCount - 1] + (24 * Pip)));
                     ObjectSetInteger(0, ObjectName, OBJPROP_COLOR, ValidSwingUpClr);
                     ObjectSetInteger(0, ObjectName, OBJPROP_WIDTH, 3);
                     ObjectSetInteger(0, ObjectName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, ObjectName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                     ObjectSetInteger(0, ObjectName, OBJPROP_SELECTABLE, false);
                  }
               }
				}
			}
		}

		else if (Target == Seller)
		{
			if (SellerValidSwingTime == ((StartHour - 2) * 60) + StartMinute)
			{
				OnDateTime = iTime(_Symbol, _Period, 0);
				TimeToStruct(OnDateTime, OnMqlDateTime);

				for (int Index = (FractalCount - 1); Index >= 0; Index--)
				{
					if (FractalDirection[Index] == false)
					{
						bool AllowToSet = true;
						int Shift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[Index] - 2;
						double LowestOpen = iOpen(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_OPEN, Shift, 1));
						double LowestClose = iClose(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_CLOSE, Shift, 1));
						double MinPrice = LowestClose;

						if (LowestOpen < LowestClose)
							MinPrice = LowestOpen;

						if (FractalDateTime[Index] > ((StartHour * 60) + StartMinute))
						{
							int BeforeShift = FractalDateTime[Index] - ((StartHour * 60) + StartMinute);
							int AfterShift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[Index];

							double BeforeHighest = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, BeforeShift, AfterShift));
							double AfterHighest = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, AfterShift, 1));

							if (BeforeHighest > AfterHighest)
								AllowToSet = false;
						}

						if ((FractalValue[Index] < MinPrice) && AllowToSet)
						{
							SellerValidSwingTime = FractalDateTime[Index];
							SellerValidSwingValue = FractalValue[Index];

							OnMqlDateTime.hour = FractalDateTime[Index] / 60;
							OnMqlDateTime.min = FractalDateTime[Index] % 60;
							OnDateTime = StructToTime(OnMqlDateTime);

							string ObjectName = "Seller Valid Swing up " + (string) OnDateTime;

							ObjectCreate(0, ObjectName, OBJ_ARROW_CHECK, 0, OnDateTime, (FractalValue[Index] - (24 * Pip)));
							ObjectSetInteger(0, ObjectName, OBJPROP_COLOR, ValidSwingDownClr);
							ObjectSetInteger(0, ObjectName, OBJPROP_WIDTH, 3);
							ObjectSetInteger(0, ObjectName, OBJPROP_STYLE, STYLE_SOLID);
							ObjectSetInteger(0, ObjectName, OBJPROP_ANCHOR, ANCHOR_TOP);
							ObjectSetInteger(0, ObjectName, OBJPROP_SELECTABLE, false);

							Index = -1;
						}
					}
				}

				if (SellerValidSwingValue == 0.0)
				{
					int Shift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[FractalCount - 1] - 2;
					int Bar = iLowest(_Symbol, _Period, MODE_LOW, Shift, 2);
					double LowestHigh = iLow(_Symbol, _Period, Bar);

					if (LowestHigh < iClose(_Symbol, _Period, 1))
					{
						OnDateTime = iTime(_Symbol, _Period, Bar);
						TimeToStruct(OnDateTime, OnMqlDateTime);
						SellerValidSwingTime = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min;
						SellerValidSwingValue = LowestHigh;

						string ObjectName = "Seller Valid Swing up " + (string) OnDateTime;

						ObjectCreate(0, ObjectName, OBJ_ARROW_CHECK, 0, OnDateTime, (SellerValidSwingValue - (24 * Pip)));
						ObjectSetInteger(0, ObjectName, OBJPROP_COLOR, ValidSwingDownClr);
						ObjectSetInteger(0, ObjectName, OBJPROP_WIDTH, 3);
						ObjectSetInteger(0, ObjectName, OBJPROP_STYLE, STYLE_SOLID);
						ObjectSetInteger(0, ObjectName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
						ObjectSetInteger(0, ObjectName, OBJPROP_SELECTABLE, false);
					}
				}
			}

			else
			{
				OnDateTime = iTime(_Symbol, _Period, 1);
				TimeToStruct(OnDateTime, OnMqlDateTime);
				
				if ((FractalDirection[FractalCount - 1] == false) && 
					 ((SellerValidSwingTime != FractalDateTime[FractalCount - 1]) ||
					  (FractalDateTime[FractalCount - 1] == (StartHour * 60) + StartMinute)))
				{
					int AfterShift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[FractalCount - 1];

               double AfterLowestClose = iClose(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_CLOSE, (AfterShift - 1), 1));
               double AfterLowestOpen = iOpen(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_OPEN, (AfterShift - 1), 1));
               double MinLowest = AfterLowestClose;

               if (AfterLowestOpen > AfterLowestClose)
                  MinLowest = AfterLowestOpen;

               if (FractalValue[FractalCount - 1] < MinLowest)
               {   
						int BeforeShift = FractalDateTime[FractalCount - 1] - SellerValidSwingTime;
						double BeforeHighest = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, BeforeShift, (AfterShift + 1)));
 
                  if ((FractalValue[FractalCount] >= BeforeHighest) || (FractalDateTime[FractalCount - 1] == (StartHour * 60) + StartMinute))
                  {
                     SellerValidSwingTime = FractalDateTime[FractalCount - 1];
                     SellerValidSwingValue = FractalValue[FractalCount - 1];

                     OnMqlDateTime.hour = FractalDateTime[FractalCount - 1] / 60;
                     OnMqlDateTime.min = FractalDateTime[FractalCount - 1] % 60;
                     OnDateTime = StructToTime(OnMqlDateTime);

							string ObjectName = "Seller Valid Swing up " + (string) OnDateTime;

                     ObjectCreate(0, ObjectName, OBJ_ARROW_CHECK, 0, OnDateTime, (FractalValue[FractalCount - 1] - (24 * Pip)));
                     ObjectSetInteger(0, ObjectName, OBJPROP_COLOR, ValidSwingDownClr);
                     ObjectSetInteger(0, ObjectName, OBJPROP_WIDTH, 3);
                     ObjectSetInteger(0, ObjectName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, ObjectName, OBJPROP_ANCHOR, ANCHOR_TOP);
                     ObjectSetInteger(0, ObjectName, OBJPROP_SELECTABLE, false);
                  }
               }
				}
			}
		}

		else if (Target == Both)
		{
			if (BuyerValidSwingTime == ((StartHour - 2) * 60) + StartMinute)
			{
				OnDateTime = iTime(_Symbol, _Period, 0);
				TimeToStruct(OnDateTime, OnMqlDateTime);
				
				for (int Index = (FractalCount - 1); Index >= 0; Index--)
				{
					if (FractalDirection[Index] == true)
					{
						bool AllowToSet = true;
						int Shift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[Index] - 2;
						double HighestOpen = iOpen(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_OPEN, Shift, 1));
						double HighestClose = iClose(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_CLOSE, Shift, 1));
						double MaxPrice = HighestClose;

						if (HighestOpen > HighestClose)
							MaxPrice = HighestOpen;

						if (FractalDateTime[Index] > ((StartHour * 60) + StartMinute))
						{
							int BeforeShift = FractalDateTime[Index] - ((StartHour * 60) + StartMinute);
							int AfterShift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[Index];

							double BeforeLowest = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, BeforeShift, AfterShift));
							double AfterLowest = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, AfterShift, 1));

							if (BeforeLowest < AfterLowest)
								AllowToSet = false;
						}

						if ((FractalValue[Index] > MaxPrice) && AllowToSet)
						{
							BuyerValidSwingTime = FractalDateTime[Index];
							BuyerValidSwingValue = FractalValue[Index];
							
							OnMqlDateTime.hour = FractalDateTime[Index] / 60;
							OnMqlDateTime.min = FractalDateTime[Index] % 60;
							OnDateTime = StructToTime(OnMqlDateTime);

							string ObjectName = "Buyer Valid Swing up " + (string) OnDateTime;

							ObjectCreate(0, ObjectName, OBJ_ARROW_CHECK, 0, OnDateTime, (FractalValue[Index] + (24 * Pip)));
							ObjectSetInteger(0, ObjectName, OBJPROP_COLOR, ValidSwingUpClr);
							ObjectSetInteger(0, ObjectName, OBJPROP_WIDTH, 3);
							ObjectSetInteger(0, ObjectName, OBJPROP_STYLE, STYLE_SOLID);
							ObjectSetInteger(0, ObjectName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
							ObjectSetInteger(0, ObjectName, OBJPROP_SELECTABLE, false);

							Index = -1;
						}
					}
				}

				if (BuyerValidSwingValue == 0.0)
				{
					int Shift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[FractalCount - 1] - 2;
					int Bar = iHighest(_Symbol, _Period, MODE_HIGH, Shift, 2);
					double HighestHigh = iHigh(_Symbol, _Period, Bar);

					if (HighestHigh > iClose(_Symbol, _Period, 1))
					{
						OnDateTime = iTime(_Symbol, _Period, Bar);
						TimeToStruct(OnDateTime, OnMqlDateTime);
						BuyerValidSwingTime = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min;
						BuyerValidSwingValue = HighestHigh;

						string ObjectName = "Buyer Valid Swing up " + (string) OnDateTime;

						ObjectCreate(0, ObjectName, OBJ_ARROW_CHECK, 0, OnDateTime, (BuyerValidSwingValue + (24 * Pip)));
						ObjectSetInteger(0, ObjectName, OBJPROP_COLOR, ValidSwingUpClr);
						ObjectSetInteger(0, ObjectName, OBJPROP_WIDTH, 3);
						ObjectSetInteger(0, ObjectName, OBJPROP_STYLE, STYLE_SOLID);
						ObjectSetInteger(0, ObjectName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
						ObjectSetInteger(0, ObjectName, OBJPROP_SELECTABLE, false);
					}
				}
			}

			else
			{
				OnDateTime = iTime(_Symbol, _Period, 1);
				TimeToStruct(OnDateTime, OnMqlDateTime);

				if ((FractalDirection[FractalCount - 1] == true) && 
					 ((BuyerValidSwingTime != FractalDateTime[FractalCount - 1]) ||
					  (FractalDateTime[FractalCount - 1] == (StartHour * 60) + StartMinute)))
				{
					int AfterShift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[FractalCount - 1];

               double AfterHighestClose = iClose(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_CLOSE, (AfterShift - 1), 1));
               double AfterHighestOpen = iOpen(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_OPEN, (AfterShift - 1), 1));
               double MaxHighest = AfterHighestClose;

               if (AfterHighestOpen > AfterHighestClose)
                  MaxHighest = AfterHighestOpen;

               if (FractalValue[FractalCount - 1] > MaxHighest)
               {    
						int BeforeShift = FractalDateTime[FractalCount - 1] - BuyerValidSwingTime;
						double BeforeLowest = iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, BeforeShift, (AfterShift + 1)));

                  if ((FractalValue[FractalCount] <= BeforeLowest) || (FractalDateTime[FractalCount - 1] == (StartHour * 60) + StartMinute))
                  {
                     BuyerValidSwingTime = FractalDateTime[FractalCount - 1];
                     BuyerValidSwingValue = FractalValue[FractalCount - 1];

                     OnMqlDateTime.hour = FractalDateTime[FractalCount - 1] / 60;
                     OnMqlDateTime.min = FractalDateTime[FractalCount - 1] % 60;
                     OnDateTime = StructToTime(OnMqlDateTime);

							string ObjectName = "Buyer Valid Swing up " + (string) OnDateTime;

                     ObjectCreate(0, ObjectName, OBJ_ARROW_CHECK, 0, OnDateTime, (FractalValue[FractalCount - 1] + (24 * Pip)));
                     ObjectSetInteger(0, ObjectName, OBJPROP_COLOR, ValidSwingUpClr);
                     ObjectSetInteger(0, ObjectName, OBJPROP_WIDTH, 3);
                     ObjectSetInteger(0, ObjectName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, ObjectName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
                     ObjectSetInteger(0, ObjectName, OBJPROP_SELECTABLE, false);
                  }
               }
				}
			}

			if (SellerValidSwingTime == ((StartHour - 2) * 60) + StartMinute)
			{
				OnDateTime = iTime(_Symbol, _Period, 0);
				TimeToStruct(OnDateTime, OnMqlDateTime);

				for (int Index = (FractalCount - 1); Index >= 0; Index--)
				{
					if (FractalDirection[Index] == false)
					{
						bool AllowToSet = true;
						int Shift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[Index] - 2;
						double LowestOpen = iOpen(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_OPEN, Shift, 1));
						double LowestClose = iClose(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_CLOSE, Shift, 1));
						double MinPrice = LowestClose;

						if (LowestOpen < LowestClose)
							MinPrice = LowestOpen;

						if (FractalDateTime[Index] > ((StartHour * 60) + StartMinute))
						{
							int BeforeShift = FractalDateTime[Index] - ((StartHour * 60) + StartMinute);
							int AfterShift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[Index];

							double BeforeHighest = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, BeforeShift, AfterShift));
							double AfterHighest = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, AfterShift, 1));

							if (BeforeHighest > AfterHighest)
								AllowToSet = false;
						}

						if ((FractalValue[Index] < MinPrice) && AllowToSet)
						{
							SellerValidSwingTime = FractalDateTime[Index];
							SellerValidSwingValue = FractalValue[Index];

							OnMqlDateTime.hour = FractalDateTime[Index] / 60;
							OnMqlDateTime.min = FractalDateTime[Index] % 60;
							OnDateTime = StructToTime(OnMqlDateTime);

							string ObjectName = "Seller Valid Swing up " + (string) OnDateTime;

							ObjectCreate(0, ObjectName, OBJ_ARROW_CHECK, 0, OnDateTime, (FractalValue[Index] - (24 * Pip)));
							ObjectSetInteger(0, ObjectName, OBJPROP_COLOR, ValidSwingDownClr);
							ObjectSetInteger(0, ObjectName, OBJPROP_WIDTH, 3);
							ObjectSetInteger(0, ObjectName, OBJPROP_STYLE, STYLE_SOLID);
							ObjectSetInteger(0, ObjectName, OBJPROP_ANCHOR, ANCHOR_TOP);
							ObjectSetInteger(0, ObjectName, OBJPROP_SELECTABLE, false);

							Index = -1;
						}
					}
				}

				if (SellerValidSwingValue == 0.0)
				{
					int Shift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[FractalCount - 1] - 2;
					int Bar = iLowest(_Symbol, _Period, MODE_LOW, Shift, 2);
					double LowestHigh = iLow(_Symbol, _Period, Bar);

					if (LowestHigh < iClose(_Symbol, _Period, 1))
					{
						OnDateTime = iTime(_Symbol, _Period, Bar);
						TimeToStruct(OnDateTime, OnMqlDateTime);
						SellerValidSwingTime = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min;
						SellerValidSwingValue = LowestHigh;

						string ObjectName = "Seller Valid Swing up " + (string) OnDateTime;

						ObjectCreate(0, ObjectName, OBJ_ARROW_CHECK, 0, OnDateTime, (SellerValidSwingValue - (24 * Pip)));
						ObjectSetInteger(0, ObjectName, OBJPROP_COLOR, ValidSwingDownClr);
						ObjectSetInteger(0, ObjectName, OBJPROP_WIDTH, 3);
						ObjectSetInteger(0, ObjectName, OBJPROP_STYLE, STYLE_SOLID);
						ObjectSetInteger(0, ObjectName, OBJPROP_ANCHOR, ANCHOR_BOTTOM);
						ObjectSetInteger(0, ObjectName, OBJPROP_SELECTABLE, false);
					}
				}
			}

			else
			{
				OnDateTime = iTime(_Symbol, _Period, 1);
				TimeToStruct(OnDateTime, OnMqlDateTime);

				if ((FractalDirection[FractalCount - 1] == false) && 
					 ((SellerValidSwingTime != FractalDateTime[FractalCount - 1]) ||
					  (FractalDateTime[FractalCount - 1] == (StartHour * 60) + StartMinute)))
				{
					int AfterShift = (OnMqlDateTime.hour * 60) + OnMqlDateTime.min - FractalDateTime[FractalCount - 1];

               double AfterLowestClose = iClose(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_CLOSE, (AfterShift - 1), 1));
               double AfterLowestOpen = iOpen(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_OPEN, (AfterShift - 1), 1));
               double MinLowest = AfterLowestClose;

               if (AfterLowestOpen > AfterLowestClose)
                  MinLowest = AfterLowestOpen;

               if (FractalValue[FractalCount - 1] < MinLowest)
               {    
						int BeforeShift = FractalDateTime[FractalCount - 1] - SellerValidSwingTime;
						double BeforeHighest = iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, BeforeShift, (AfterShift + 1)));

                  if ((FractalValue[FractalCount] >= BeforeHighest) || (FractalDateTime[FractalCount - 1] == (StartHour * 60) + StartMinute))
                  {
                     SellerValidSwingTime = FractalDateTime[FractalCount - 1];
                     SellerValidSwingValue = FractalValue[FractalCount - 1];

                     OnMqlDateTime.hour = FractalDateTime[FractalCount - 1] / 60;
                     OnMqlDateTime.min = FractalDateTime[FractalCount - 1] % 60;
                     OnDateTime = StructToTime(OnMqlDateTime);

							string ObjectName = "Seller Valid Swing up " + (string) OnDateTime;

                     ObjectCreate(0, ObjectName, OBJ_ARROW_CHECK, 0, OnDateTime, (FractalValue[FractalCount - 1] - (24 * Pip)));
                     ObjectSetInteger(0, ObjectName, OBJPROP_COLOR, ValidSwingDownClr);
                     ObjectSetInteger(0, ObjectName, OBJPROP_WIDTH, 3);
                     ObjectSetInteger(0, ObjectName, OBJPROP_STYLE, STYLE_SOLID);
                     ObjectSetInteger(0, ObjectName, OBJPROP_ANCHOR, ANCHOR_TOP);
                     ObjectSetInteger(0, ObjectName, OBJPROP_SELECTABLE, false);
                  }
               }
				}
			}
		}
	}
}

void CheckToSetOrder(void)
{
	if (SetOrder && !OrderIsOpen)
	{
		int ATR_Handle = iATR(_Symbol, PERIOD_H1, 50);
		double ATR_Buffer[];
		CopyBuffer(ATR_Handle, 0, 0, 1, ATR_Buffer);
		PipAlert = PipAlertX * ATR_Buffer[0];

		if (Target == Seller)
		{
			datetime DateTime = iTime(_Symbol, _Period, 0);
			MqlDateTime MqlTime;
			TimeToStruct(DateTime, MqlTime);

			MqlTime.hour = SellerValidSwingTime / 60;
			MqlTime.min = SellerValidSwingTime % 60;
			DateTime = StructToTime(MqlTime);

			int SellShift = iBarShift(_Symbol, _Period, DateTime) - 1;

			if (SellerTargetTime > DateTime)
				SellShift = iBarShift(_Symbol, _Period, SellerTargetTime) - 1;

			double LowestOpen = iOpen(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_OPEN, SellShift, 1));
			double LowestClose = iClose(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_CLOSE, SellShift, 1));
			double MinPrice = LowestClose;

			if (LowestOpen < LowestClose)
				MinPrice = LowestOpen;

			if (SellShift == 0)
				MinPrice = DBL_MAX;

			if ((SellerValidSwingValue > 0) && (SellerValidSwingValue >= MinPrice))
			{
				SetOrder = false;
				double Price = NormalizeDouble(iLow(_Symbol, _Period, 1) , _Digits);

				ObjectCreate(0, "Sell First Line", OBJ_HLINE, 0, 0, Price);
				ObjectSetInteger(0, "Sell First Line", OBJPROP_COLOR, clrYellow);
				ObjectSetInteger(0, "Sell First Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Sell First Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Sell First Line", OBJPROP_SELECTABLE, false);

				int SellShift = iBarShift(_Symbol, _Period, DateTime);
				double StopLoss = NormalizeDouble((iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, SellShift, 1)) + (StopLossOffset * Pip)), _Digits);

				if ((SellerValidSwingTime) < ((StartHour * 60) + StartMinute))
				{
					MqlTime.hour = StartHour;
					MqlTime.min = StartMinute;
					DateTime = StructToTime(MqlTime);
					SellShift = iBarShift(_Symbol, _Period, DateTime);
					StopLoss = NormalizeDouble((iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, SellShift, 1)) + (StopLossOffset * Pip)), _Digits);
				}

				ObjectCreate(0, "Sell Stop Loss Line", OBJ_HLINE, 0, 0, StopLoss);
				ObjectSetInteger(0, "Sell Stop Loss Line", OBJPROP_COLOR, clrOrangeRed);
				ObjectSetInteger(0, "Sell Stop Loss Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Sell Stop Loss Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Sell Stop Loss Line", OBJPROP_SELECTABLE, false);

				double PriceDiff = StopLoss - Price;
				PriceDiff = PriceDiff * Retracement / 100;
				double OpenPrice = NormalizeDouble((StopLoss - PriceDiff), _Digits);
				
				ObjectCreate(0, "Sell Open Order Line", OBJ_HLINE, 0, 0, OpenPrice);
				ObjectSetInteger(0, "Sell Open Order Line", OBJPROP_COLOR, clrGreen);
				ObjectSetInteger(0, "Sell Open Order Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Sell Open Order Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Sell Open Order Line", OBJPROP_SELECTABLE, false);

				PriceDiff = PriceDiff * RiskOnReward;
            double TakeProfit = NormalizeDouble((OpenPrice - PriceDiff), _Digits);

				ObjectCreate(0, "Sell Take Profit Line", OBJ_HLINE, 0, 0, TakeProfit);
				ObjectSetInteger(0, "Sell Take Profit Line", OBJPROP_COLOR, clrAqua);
				ObjectSetInteger(0, "Sell Take Profit Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Sell Take Profit Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Sell Take Profit Line", OBJPROP_SELECTABLE, false);
				
				double PriceSlDiff = StopLoss - OpenPrice;

				if (PriceSlDiff < (PipAlert * Pip))
				{
					double LotSize = NormalizeDouble(CalculateLotSize(PriceSlDiff), 2);

					if (Trade.SellLimit(LotSize, OpenPrice, _Symbol, StopLoss, TakeProfit, ORDER_TIME_GTC, 0, SellPosition))
					{
						OrderTicket = Trade.ResultOrder();
						ReversePosition(ReversePositionEN, LotSize, OpenPrice, StopLoss, false);
					}

					else
					{
						if (GetLastError() == 4756)
						{
							LotSize = NormalizeDouble(CalculateLotSize(StopLoss - SymbolInfoDouble(_Symbol, SYMBOL_BID)), 2);
							TakeProfit = SymbolInfoDouble(_Symbol, SYMBOL_BID) - ((StopLoss - SymbolInfoDouble(_Symbol, SYMBOL_BID)) * RiskOnReward);

							if (Trade.Sell(LotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), StopLoss, TakeProfit, SellPosition))
							{
								OrderTicket = Trade.ResultOrder();
								ReversePosition(ReversePositionEN, LotSize, OpenPrice, StopLoss, false);
							}
						}
					}
				}
			}
		}

		else if (Target == Buyer)
		{
			datetime DateTime = iTime(_Symbol, _Period, 0);
			MqlDateTime MqlTime;
			TimeToStruct(DateTime, MqlTime);
			
			MqlTime.hour = BuyerValidSwingTime / 60;
			MqlTime.min = BuyerValidSwingTime % 60;
			DateTime = StructToTime(MqlTime);

			int BuyShift = iBarShift(_Symbol, _Period, DateTime) - 1;

			if (BuyerTargetTime > DateTime)
				BuyShift = iBarShift(_Symbol, _Period, BuyerTargetTime) - 1;
			
			double HighestOpen = iOpen(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_OPEN, BuyShift, 1));
			double HighestClose = iClose(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_CLOSE, BuyShift, 1));
			double MaxPrice = HighestClose;

			if (HighestOpen > HighestClose)
				MaxPrice = HighestOpen;

			if (BuyShift == 0)
				MaxPrice = 0;

			if ((BuyerValidSwingValue > 0) && (BuyerValidSwingValue <= MaxPrice))
			{
				SetOrder = false;
				double Price = NormalizeDouble(iHigh(_Symbol, _Period, 1), _Digits);
				
				ObjectCreate(0, "Buy First Line", OBJ_HLINE, 0, 0, Price);
				ObjectSetInteger(0, "Buy First Line", OBJPROP_COLOR, clrYellow);
				ObjectSetInteger(0, "Buy First Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Buy First Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Buy First Line", OBJPROP_SELECTABLE, false);

				int BuyShift = iBarShift(_Symbol, _Period, DateTime);
				double StopLoss = NormalizeDouble((iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, BuyShift, 1)) - (StopLossOffset * Pip)), _Digits);

				if ((BuyerValidSwingTime) < ((StartHour * 60) + StartMinute))
				{
					MqlTime.hour = StartHour;
					MqlTime.min = StartMinute;
					DateTime = StructToTime(MqlTime);
					BuyShift = iBarShift(_Symbol, _Period, DateTime);
					StopLoss = NormalizeDouble((iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, BuyShift, 1)) - (StopLossOffset * Pip)), _Digits);
				}

				ObjectCreate(0, "Buy Stop Loss Line", OBJ_HLINE, 0, 0, StopLoss);
				ObjectSetInteger(0, "Buy Stop Loss Line", OBJPROP_COLOR, clrOrangeRed);
				ObjectSetInteger(0, "Buy Stop Loss Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Buy Stop Loss Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Buy Stop Loss Line", OBJPROP_SELECTABLE, false);

				double PriceDiff = Price - StopLoss;
				PriceDiff = PriceDiff * Retracement / 100;
				double OpenPrice = NormalizeDouble((StopLoss + PriceDiff), _Digits);

				ObjectCreate(0, "Buy Open Order Line", OBJ_HLINE, 0, 0, OpenPrice);
				ObjectSetInteger(0, "Buy Open Order Line", OBJPROP_COLOR, clrGreen);
				ObjectSetInteger(0, "Buy Open Order Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Buy Open Order Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Buy Open Order Line", OBJPROP_SELECTABLE, false);

				PriceDiff = PriceDiff * RiskOnReward;
				double TakeProfit = NormalizeDouble((OpenPrice + PriceDiff), _Digits);

				ObjectCreate(0, "Buy Take Profit Line", OBJ_HLINE, 0, 0, TakeProfit);
				ObjectSetInteger(0, "Buy Take Profit Line", OBJPROP_COLOR, clrAqua);
				ObjectSetInteger(0, "Buy Take Profit Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Buy Take Profit Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Buy Take Profit Line", OBJPROP_SELECTABLE, false);

				double PriceSlDiff = OpenPrice - StopLoss;

				if (PriceSlDiff < (PipAlert * Pip))
				{
					double LotSize = NormalizeDouble(CalculateLotSize(PriceSlDiff), 2);

					if (Trade.BuyLimit(LotSize, OpenPrice, _Symbol, StopLoss, TakeProfit, ORDER_TIME_GTC, 0, BuyPosition))
					{
						OrderTicket = Trade.ResultOrder();
						ReversePosition(ReversePositionEN, LotSize, OpenPrice, StopLoss, true);
					}

					else
					{
						if (GetLastError() == 4756)
						{
							LotSize = NormalizeDouble(CalculateLotSize(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - StopLoss), 2);
							TakeProfit = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + ((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - StopLoss) * RiskOnReward);

							if (Trade.Buy(LotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), StopLoss, TakeProfit, BuyPosition))
							{
								OrderTicket = Trade.ResultOrder();
								ReversePosition(ReversePositionEN, LotSize, OpenPrice, StopLoss, true);
							}
						}
					}
				}
			}
		}
	
		else if (Target == Both)
		{
			datetime BuyerDateTime = iTime(_Symbol, _Period, 0);
			MqlDateTime MqlTime;
			TimeToStruct(BuyerDateTime, MqlTime);

			MqlTime.hour = BuyerValidSwingTime / 60;
			MqlTime.min = BuyerValidSwingTime % 60;
			BuyerDateTime = StructToTime(MqlTime);

			MqlTime.hour = SellerValidSwingTime / 60;
			MqlTime.min = SellerValidSwingTime % 60;
			datetime SellerDateTime = StructToTime(MqlTime);

			int SellShift = iBarShift(_Symbol, _Period, SellerDateTime) - 1;
			int BuyShift = iBarShift(_Symbol, _Period, BuyerDateTime) - 1;

			if (SellerTargetTime > SellerDateTime)
				SellShift = iBarShift(_Symbol, _Period, SellerTargetTime) - 1;

			if (BuyerTargetTime > BuyerDateTime)
				BuyShift = iBarShift(_Symbol, _Period, BuyerTargetTime) - 1;
			
			double LowestOpen = iOpen(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_OPEN, SellShift, 1));
			double LowestClose = iClose(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_CLOSE, SellShift, 1));
			double HighestOpen = iOpen(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_OPEN, BuyShift, 1));
			double HighestClose = iClose(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_CLOSE, BuyShift, 1));
			double MinPrice = LowestClose, MaxPrice = HighestClose;

			if (HighestOpen > HighestClose)
				MaxPrice = HighestOpen;

			if (LowestOpen < LowestClose)
				MinPrice = LowestOpen;

			if (SellShift == 0)
				MinPrice = DBL_MAX;

			if (BuyShift == 0)
				MaxPrice = 0;

			if ((SellerValidSwingValue > 0) && (SellerValidSwingValue >= MinPrice))
			{
				SetOrder = false;
				double Price = NormalizeDouble(iLow(_Symbol, _Period, 1) , _Digits);

				ObjectCreate(0, "Sell First Line", OBJ_HLINE, 0, 0, Price);
				ObjectSetInteger(0, "Sell First Line", OBJPROP_COLOR, clrYellow);
				ObjectSetInteger(0, "Sell First Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Sell First Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Sell First Line", OBJPROP_SELECTABLE, false);

				int SellShift = iBarShift(_Symbol, _Period, SellerDateTime);
				double StopLoss = NormalizeDouble((iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, SellShift, 1)) + (StopLossOffset * Pip)), _Digits);

				if ((SellerValidSwingTime) < ((StartHour * 60) + StartMinute))
				{
					MqlTime.hour = StartHour;
					MqlTime.min = StartMinute;
					SellerDateTime = StructToTime(MqlTime);
					SellShift = iBarShift(_Symbol, _Period, SellerDateTime);
					StopLoss = NormalizeDouble((iHigh(_Symbol, _Period, iHighest(_Symbol, _Period, MODE_HIGH, SellShift, 1)) + (StopLossOffset * Pip)), _Digits);
				}

				ObjectCreate(0, "Sell Stop Loss Line", OBJ_HLINE, 0, 0, StopLoss);
				ObjectSetInteger(0, "Sell Stop Loss Line", OBJPROP_COLOR, clrOrangeRed);
				ObjectSetInteger(0, "Sell Stop Loss Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Sell Stop Loss Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Sell Stop Loss Line", OBJPROP_SELECTABLE, false);

				double PriceDiff = StopLoss - Price;
				PriceDiff = PriceDiff * Retracement / 100;
				double OpenPrice = NormalizeDouble((StopLoss - PriceDiff), _Digits);
				
				ObjectCreate(0, "Sell Open Order Line", OBJ_HLINE, 0, 0, OpenPrice);
				ObjectSetInteger(0, "Sell Open Order Line", OBJPROP_COLOR, clrAquamarine/* clrGreen */);
				ObjectSetInteger(0, "Sell Open Order Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Sell Open Order Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Sell Open Order Line", OBJPROP_SELECTABLE, false);

				PriceDiff = PriceDiff * RiskOnReward;
            double TakeProfit = NormalizeDouble((OpenPrice - PriceDiff), _Digits);

				ObjectCreate(0, "Sell Take Profit Line", OBJ_HLINE, 0, 0, TakeProfit);
				ObjectSetInteger(0, "Sell Take Profit Line", OBJPROP_COLOR, clrAqua);
				ObjectSetInteger(0, "Sell Take Profit Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Sell Take Profit Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Sell Take Profit Line", OBJPROP_SELECTABLE, false);

				double PriceSlDiff = StopLoss - OpenPrice;

				if (PriceSlDiff < (PipAlert * Pip))
				{
					double LotSize = NormalizeDouble(CalculateLotSize(PriceSlDiff), 2);

					if (Trade.SellLimit(LotSize, OpenPrice, _Symbol, StopLoss, TakeProfit, ORDER_TIME_GTC, 0, SellPosition))
					{
						OrderTicket = Trade.ResultOrder();
						ReversePosition(ReversePositionEN, LotSize, OpenPrice, StopLoss, false);
					}

					else
					{
						if (GetLastError() == 4756)
						{
							LotSize = NormalizeDouble(CalculateLotSize(StopLoss - SymbolInfoDouble(_Symbol, SYMBOL_BID)), 2);
							TakeProfit = SymbolInfoDouble(_Symbol, SYMBOL_BID) - ((StopLoss - SymbolInfoDouble(_Symbol, SYMBOL_BID)) * RiskOnReward);

							if (Trade.Sell(LotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), StopLoss, TakeProfit, SellPosition))
							{
								OrderTicket = Trade.ResultOrder();
								ReversePosition(ReversePositionEN, LotSize, OpenPrice, StopLoss, false);
							}
						}
					}
				}
			}

			else if ((BuyerValidSwingValue > 0) && (BuyerValidSwingValue <= MaxPrice))
			{
				SetOrder = false;
				double Price = NormalizeDouble(iHigh(_Symbol, _Period, 1), _Digits);

				ObjectCreate(0, "Buy First Line", OBJ_HLINE, 0, 0, Price);
				ObjectSetInteger(0, "Buy First Line", OBJPROP_COLOR, clrYellow);
				ObjectSetInteger(0, "Buy First Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Buy First Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Buy First Line", OBJPROP_SELECTABLE, false);

				int BuyShift = iBarShift(_Symbol, _Period, BuyerDateTime);
				double StopLoss = NormalizeDouble((iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, BuyShift, 1)) - (StopLossOffset * Pip)), _Digits);

				if ((BuyerValidSwingTime) < ((StartHour * 60) + StartMinute))
				{
					MqlTime.hour = StartHour;
					MqlTime.min = StartMinute;
					BuyerDateTime = StructToTime(MqlTime);
					BuyShift = iBarShift(_Symbol, _Period, BuyerDateTime);
					StopLoss = NormalizeDouble((iLow(_Symbol, _Period, iLowest(_Symbol, _Period, MODE_LOW, BuyShift, 1)) - (StopLossOffset * Pip)), _Digits);
				}

				ObjectCreate(0, "Buy Stop Loss Line", OBJ_HLINE, 0, 0, StopLoss);
				ObjectSetInteger(0, "Buy Stop Loss Line", OBJPROP_COLOR, clrOrangeRed);
				ObjectSetInteger(0, "Buy Stop Loss Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Buy Stop Loss Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Buy Stop Loss Line", OBJPROP_SELECTABLE, false);

				double PriceDiff = Price - StopLoss;
				PriceDiff = PriceDiff * Retracement / 100;
				double OpenPrice = NormalizeDouble((StopLoss + PriceDiff), _Digits);

				ObjectCreate(0, "Buy Open Order Line", OBJ_HLINE, 0, 0, OpenPrice);
				ObjectSetInteger(0, "Buy Open Order Line", OBJPROP_COLOR, clrGreen);
				ObjectSetInteger(0, "Buy Open Order Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Buy Open Order Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Buy Open Order Line", OBJPROP_SELECTABLE, false);

				PriceDiff = PriceDiff * RiskOnReward;
				double TakeProfit = NormalizeDouble((OpenPrice + PriceDiff), _Digits);

				ObjectCreate(0, "Buy Take Profit Line", OBJ_HLINE, 0, 0, TakeProfit);
				ObjectSetInteger(0, "Buy Take Profit Line", OBJPROP_COLOR, clrAqua);
				ObjectSetInteger(0, "Buy Take Profit Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Buy Take Profit Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Buy Take Profit Line", OBJPROP_SELECTABLE, false);

				double PriceSlDiff = OpenPrice - StopLoss;

				if (PriceSlDiff < (PipAlert * Pip))
				{
					double LotSize = NormalizeDouble(CalculateLotSize(PriceSlDiff), 2);

					if (Trade.BuyLimit(LotSize, OpenPrice, _Symbol, StopLoss, TakeProfit, ORDER_TIME_GTC, 0, BuyPosition))
					{
						OrderTicket = Trade.ResultOrder();
						ReversePosition(ReversePositionEN, LotSize, OpenPrice, StopLoss, true);
					}

					else
					{
						if (GetLastError() == 4756)
						{
							LotSize = NormalizeDouble(CalculateLotSize(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - StopLoss), 2);
							TakeProfit = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + ((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - StopLoss) * RiskOnReward);

							if (Trade.Buy(LotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), StopLoss, TakeProfit, BuyPosition))
							{
								OrderTicket = Trade.ResultOrder();
								ReversePosition(ReversePositionEN, LotSize, OpenPrice, StopLoss, true);
							}
						}
					}
				}
			}
		}
	}
}

void UpdateOrder(void)
{
	if (!OrderIsOpen)
	{
		int ATR_Handle = iATR(_Symbol, PERIOD_H1, 50);
		double ATR_Buffer[];
		CopyBuffer(ATR_Handle, 0, 0, 1, ATR_Buffer);
		PipAlert = PipAlertX * ATR_Buffer[0];

		if (ObjectFind(0, "Buy First Line") >= 0)
		{
			double PreBuyFirstLine = ObjectGetDouble(0, "Buy First Line", OBJPROP_PRICE);
			double NewPrice = iHigh(_Symbol, _Period, 1);

			if (NewPrice > PreBuyFirstLine)
			{
				double StopLoss = ObjectGetDouble(0, "Buy Stop Loss Line", OBJPROP_PRICE);

				ObjectDelete(0 , "Buy First Line");
				ObjectDelete(0 , "Buy Open Order Line");
				ObjectDelete(0 , "Buy Take Profit Line");

				ObjectCreate(0, "Buy First Line", OBJ_HLINE, 0, 0, NewPrice);
				ObjectSetInteger(0, "Buy First Line", OBJPROP_COLOR, clrYellow);
				ObjectSetInteger(0, "Buy First Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Buy First Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Buy First Line", OBJPROP_SELECTABLE, false);
				
				double PriceDiff = NewPrice - StopLoss;
				PriceDiff = PriceDiff * Retracement / 100;
				double OpenPrice = NormalizeDouble((StopLoss + PriceDiff), _Digits);

				ObjectCreate(0, "Buy Open Order Line", OBJ_HLINE, 0, 0, OpenPrice);
				ObjectSetInteger(0, "Buy Open Order Line", OBJPROP_COLOR, clrGreen);
				ObjectSetInteger(0, "Buy Open Order Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Buy Open Order Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Buy Open Order Line", OBJPROP_SELECTABLE, false);

				PriceDiff = PriceDiff * RiskOnReward;
				double TakeProfit = NormalizeDouble((OpenPrice + PriceDiff), _Digits);

				ObjectCreate(0, "Buy Take Profit Line", OBJ_HLINE, 0, 0, TakeProfit);
				ObjectSetInteger(0, "Buy Take Profit Line", OBJPROP_COLOR, clrAqua);
				ObjectSetInteger(0, "Buy Take Profit Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Buy Take Profit Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Buy Take Profit Line", OBJPROP_SELECTABLE, false);

				CancelOrder(OrderTicket);
				CancelOrder(ReverseOrderTicket);

				double PriceSlDiff = OpenPrice - StopLoss;
				
				if (PriceSlDiff < (PipAlert * Pip))
				{
					double LotSize = NormalizeDouble(CalculateLotSize(OpenPrice - StopLoss), 2);

					if (Trade.BuyLimit(LotSize, OpenPrice, _Symbol, StopLoss, TakeProfit, ORDER_TIME_GTC, 0, BuyPosition))
					{
						OrderTicket = Trade.ResultOrder();
						ReversePosition(ReversePositionEN, LotSize, OpenPrice, StopLoss, true);
					}

					else
					{
						if (GetLastError() == 4756)
						{
							LotSize = NormalizeDouble(CalculateLotSize(SymbolInfoDouble(_Symbol, SYMBOL_ASK) - StopLoss), 2);
							TakeProfit = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + ((SymbolInfoDouble(_Symbol, SYMBOL_ASK) - StopLoss) * RiskOnReward);

							if (Trade.Buy(LotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_ASK), StopLoss, TakeProfit, BuyPosition))
							{
								OrderTicket = Trade.ResultOrder();
								ReversePosition(ReversePositionEN, LotSize, OpenPrice, StopLoss, true);
							}
						}
					}
				}
			}
		}

		else if (ObjectFind(0, "Sell First Line") >= 0)
		{
			double PreSellFirstLine = ObjectGetDouble(0, "Sell First Line", OBJPROP_PRICE);
			double NewPrice = iLow(_Symbol, _Period, 1);

			if (NewPrice < PreSellFirstLine)
			{
				double StopLoss = ObjectGetDouble(0, "Sell Stop Loss Line", OBJPROP_PRICE);

				ObjectDelete(0 , "Sell First Line");
				ObjectDelete(0 , "Sell Open Order Line");
				ObjectDelete(0 , "Sell Take Profit Line");

				ObjectCreate(0, "Sell First Line", OBJ_HLINE, 0, 0, NewPrice);
				ObjectSetInteger(0, "Sell First Line", OBJPROP_COLOR, clrYellow);
				ObjectSetInteger(0, "Sell First Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Sell First Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Sell First Line", OBJPROP_SELECTABLE, false);

				double PriceDiff = StopLoss - NewPrice;
				PriceDiff = PriceDiff * Retracement / 100;
				double OpenPrice = NormalizeDouble((StopLoss - PriceDiff), _Digits);
				
				ObjectCreate(0, "Sell Open Order Line", OBJ_HLINE, 0, 0, OpenPrice);
				ObjectSetInteger(0, "Sell Open Order Line", OBJPROP_COLOR, clrGreen);
				ObjectSetInteger(0, "Sell Open Order Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Sell Open Order Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Sell Open Order Line", OBJPROP_SELECTABLE, false);

				PriceDiff = PriceDiff * RiskOnReward;
            double TakeProfit = NormalizeDouble((OpenPrice - PriceDiff), _Digits);

				ObjectCreate(0, "Sell Take Profit Line", OBJ_HLINE, 0, 0, TakeProfit);
				ObjectSetInteger(0, "Sell Take Profit Line", OBJPROP_COLOR, clrAqua);
				ObjectSetInteger(0, "Sell Take Profit Line", OBJPROP_WIDTH, 2);
				ObjectSetInteger(0, "Sell Take Profit Line", OBJPROP_STYLE, STYLE_DASHDOT);
				ObjectSetInteger(0, "Sell Take Profit Line", OBJPROP_SELECTABLE, false);
				
				CancelOrder(OrderTicket);
				CancelOrder(ReverseOrderTicket);

				double PriceSlDiff = StopLoss - OpenPrice;
				
				if (PriceSlDiff < (PipAlert * Pip))
				{
					double LotSize = NormalizeDouble(CalculateLotSize(StopLoss - OpenPrice), 2);

					if (Trade.SellLimit(LotSize, OpenPrice, _Symbol, StopLoss, TakeProfit, ORDER_TIME_GTC, 0, SellPosition))
					{
						OrderTicket = Trade.ResultOrder();
						ReversePosition(ReversePositionEN, LotSize, OpenPrice, StopLoss, false);
					}

					else
					{
						if (GetLastError() == 4756)
						{
							LotSize = NormalizeDouble(CalculateLotSize(StopLoss - SymbolInfoDouble(_Symbol, SYMBOL_BID)), 2);
							TakeProfit = SymbolInfoDouble(_Symbol, SYMBOL_BID) - ((StopLoss - SymbolInfoDouble(_Symbol, SYMBOL_BID)) * RiskOnReward);

							if (Trade.Sell(LotSize, _Symbol, SymbolInfoDouble(_Symbol, SYMBOL_BID), StopLoss, TakeProfit, SellPosition))
							{
								OrderTicket = Trade.ResultOrder();
								ReversePosition(ReversePositionEN, LotSize, OpenPrice, StopLoss, false);
							}
						}
					}
				}
			}
		}
	}
}

double CalculateLotSize(double EntryStoplossDiff)
{
   double RiskAmount = AccountInfoDouble(ACCOUNT_BALANCE) * RiskPercent / 100;
	double VolumeStep = SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
	int VolumeFactor = (int) (MathAbs(log10(VolumeStep)));

	double Points = EntryStoplossDiff / _Point;
   double PointValue = SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_SIZE) * SymbolInfoDouble(_Symbol,SYMBOL_TRADE_CONTRACT_SIZE);
	double Lots = RiskAmount / (Points * PointValue);

   double MinLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double MaxLots = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if (MinLots != 0)
      Lots = MathMax(Lots, MinLots);

   if (MaxLots != 0)
      Lots = MathMin(Lots, MaxLots);

   Lots = NormalizeDouble(Lots, VolumeFactor);

   return Lots;
}

void CancelOrder(ulong Ticket)
{
    if (OrderSelect(Ticket))
    {
		if ((OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_LIMIT) || (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_LIMIT) ||
			 (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_BUY_STOP) || (OrderGetInteger(ORDER_TYPE) == ORDER_TYPE_SELL_STOP))
			Trade.OrderDelete(Ticket);
	 }
}

void ReversePosition(bool StateEnableDisable, double LotSize, double PriceToStopLoss, double StopLossToPrice, bool Direction)
{
	if (StateEnableDisable)
	{
		if (Direction)
		{
			double PriceDiff = NormalizeDouble(PriceToStopLoss - StopLossToPrice, _Digits);

			if (PriceDiff < (DownLimit * Pip))
			{
				PriceDiff = (DownLimit * Pip);
				PriceToStopLoss = NormalizeDouble(StopLossToPrice + PriceDiff, _Digits);
				LotSize = NormalizeDouble(CalculateLotSize(PriceDiff), 2);
			}

			else if (PriceDiff > (UpLimit * Pip))
			{
				PriceDiff = (UpLimitForSet * Pip);
				PriceToStopLoss = NormalizeDouble(StopLossToPrice + PriceDiff, _Digits);
				LotSize = NormalizeDouble(CalculateLotSize(PriceDiff), 2);
			}

			double TakProfit = NormalizeDouble(StopLossToPrice - PriceDiff, _Digits);

			if (Trade.SellStop(LotSize, StopLossToPrice, _Symbol, PriceToStopLoss, TakProfit, ORDER_TIME_GTC, 0, ReverseBuyPosition))
				ReverseOrderTicket = Trade.ResultOrder(); 
		}

		else
		{
			double PriceDiff = NormalizeDouble(StopLossToPrice - PriceToStopLoss, _Digits);

			if (PriceDiff < (DownLimit * Pip))
			{
				PriceDiff = (DownLimit * Pip);
				PriceToStopLoss = NormalizeDouble(StopLossToPrice - PriceDiff, _Digits);
				LotSize = NormalizeDouble(CalculateLotSize(PriceDiff), 2);
			}

			else if (PriceDiff > (UpLimit * Pip))
			{
				PriceDiff = (UpLimitForSet * Pip);
				PriceToStopLoss = NormalizeDouble(StopLossToPrice - PriceDiff, _Digits);
				LotSize = NormalizeDouble(CalculateLotSize(PriceDiff), 2);
			}

			double TakProfit = NormalizeDouble(StopLossToPrice + PriceDiff, _Digits);
			if (Trade.BuyStop(LotSize, StopLossToPrice, _Symbol, PriceToStopLoss, TakProfit, ORDER_TIME_GTC, 0, ReverseSellPosition))
				ReverseOrderTicket = Trade.ResultOrder();
		}
	}
}

