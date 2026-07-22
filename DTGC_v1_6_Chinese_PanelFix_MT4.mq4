//+------------------------------------------------------------------+
//|                    DTGC_v1_6_Chinese_PanelFix_MT4.mq4             |
//| 匯鹰量化：DTGC v1.6 面板修复、最小化及持仓管理缺陷修正版          |
//|                                                                  |
//| 公共说明页：                                                      |
//| https://chatfxeatm.github.io/huiying-gold-ai-intro/dtgc-v1-6.html |
//| GitHub备用页：                                                    |
//| https://github.com/ChatFxeaTm/huiying-gold-ai-intro/blob/main/    |
//| dtgc-v1-6.html                                                    |
//|                                                                  |
//| 使用方法：                                                        |
//| 1. 本文件与 DTGC_v1_5_1_Chinese_MT4_NoWarnings.mq4 放在同一目录。 |
//| 2. 只编译并加载本文件，不要同时加载基础EA。                        |
//| 3. 本文件复用v1.5.1交易核心，只替换面板、事件入口和已确认缺陷。    |
//+------------------------------------------------------------------+
#property strict

// 把基础文件中的面板、持仓管理和事件函数改名，避免重名；交易核心保持原样。
#define CreatePanel          DTGC_Base_CreatePanel
#define DeletePanel          DTGC_Base_DeletePanel
#define UpdatePanel          DTGC_Base_UpdatePanel
#define ManageOpenPositions  DTGC_Base_ManageOpenPositions
#define OnInit               DTGC_Base_OnInit
#define OnDeinit             DTGC_Base_OnDeinit
#define OnTick               DTGC_Base_OnTick
#include "DTGC_v1_5_1_Chinese_MT4_NoWarnings.mq4"
#undef CreatePanel
#undef DeletePanel
#undef UpdatePanel
#undef ManageOpenPositions
#undef OnInit
#undef OnDeinit
#undef OnTick

#property version   "1.60"
#property link      "https://chatfxeatm.github.io/huiying-gold-ai-intro/dtgc-v1-6.html"
#property description "匯鹰量化 DTGC v1.6：修复黑色空白面板，支持最小化/最大化。"
#property description "复用v1.5.1交易核心，并修复初始R恢复与加仓锁盈基准问题。"

const string HYQ_DOC_URL = "https://chatfxeatm.github.io/huiying-gold-ai-intro/dtgc-v1-6.html";
const int    HYQ_PANEL_LINES = 16;

string g_hyPrefix       = "";
string g_hyBg           = "";
string g_hyHeader       = "";
string g_hyToggle       = "";
string g_hyLinePrefix   = "";
bool   g_hyMinimized    = false;
string g_hyLastText[HYQ_PANEL_LINES];
color  g_hyLastColor[HYQ_PANEL_LINES];

string HYQ_MinStateKey()
{
   return AccountStateKey("PANEL_MIN");
}

string HYQ_LineName(int index)
{
   return g_hyLinePrefix+IntegerToString(index);
}

string HYQ_Trim(string value,int maxLength)
{
   if(maxLength<4 || StringLen(value)<=maxLength) return value;
   return StringSubstr(value,0,maxLength-3)+"...";
}

void HYQ_InitObjectNames()
{
   g_hyPrefix=StringFormat("HYQ_DTGC_%d_%s_%d_",AccountNumber(),Symbol(),InpMagicNumber);
   g_hyBg=g_hyPrefix+"BG";
   g_hyHeader=g_hyPrefix+"HEADER";
   g_hyToggle=g_hyPrefix+"TOGGLE";
   g_hyLinePrefix=g_hyPrefix+"LINE_";
}

void HYQ_DeleteObject(string name)
{
   if(ObjectFind(0,name)>=0) ObjectDelete(0,name);
}

void HYQ_DeletePanel()
{
   HYQ_DeleteObject(g_hyToggle);
   HYQ_DeleteObject(g_hyHeader);
   for(int i=0;i<HYQ_PANEL_LINES;i++) HYQ_DeleteObject(HYQ_LineName(i));
   HYQ_DeleteObject(g_hyBg);
}

void HYQ_DeleteLegacyPanel()
{
   // 清理旧版固定对象名，防止旧对象残留覆盖新版文字。
   HYQ_DeleteObject("DTGC_PANEL_TEXT");
   HYQ_DeleteObject("DTGC_PANEL_BG");
}

bool HYQ_CreateRect(string name,int x,int y,int width,int height,color bg,color border,int zorder)
{
   if(ObjectFind(0,name)<0)
   {
      ResetLastError();
      if(!ObjectCreate(0,name,OBJ_RECTANGLE_LABEL,0,0,0))
      {
         Print("创建面板矩形失败：",name,"，错误码=",GetLastError());
         return false;
      }
   }
   ObjectSetInteger(0,name,OBJPROP_CORNER,InpPanelCorner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,bg);
   ObjectSetInteger(0,name,OBJPROP_COLOR,border);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,zorder);
   return true;
}

bool HYQ_CreateLabel(string name,int x,int y,int fontSize,color textColor,string text,int zorder)
{
   if(ObjectFind(0,name)<0)
   {
      ResetLastError();
      if(!ObjectCreate(0,name,OBJ_LABEL,0,0,0))
      {
         Print("创建面板文字失败：",name,"，错误码=",GetLastError());
         return false;
      }
   }
   ObjectSetInteger(0,name,OBJPROP_CORNER,InpPanelCorner);
   ObjectSetInteger(0,name,OBJPROP_ANCHOR,ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_COLOR,textColor);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,fontSize);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,zorder);
   return true;
}

bool HYQ_CreateButton(string name,int x,int y,int width,int height,string text)
{
   if(ObjectFind(0,name)<0)
   {
      ResetLastError();
      if(!ObjectCreate(0,name,OBJ_BUTTON,0,0,0))
      {
         Print("创建面板按钮失败：",name,"，错误码=",GetLastError());
         return false;
      }
   }
   ObjectSetInteger(0,name,OBJPROP_CORNER,InpPanelCorner);
   ObjectSetInteger(0,name,OBJPROP_XDISTANCE,x);
   ObjectSetInteger(0,name,OBJPROP_YDISTANCE,y);
   ObjectSetInteger(0,name,OBJPROP_XSIZE,width);
   ObjectSetInteger(0,name,OBJPROP_YSIZE,height);
   ObjectSetInteger(0,name,OBJPROP_BGCOLOR,clrBlack);
   ObjectSetInteger(0,name,OBJPROP_COLOR,clrGold);
   ObjectSetInteger(0,name,OBJPROP_BORDER_COLOR,clrDimGray);
   ObjectSetInteger(0,name,OBJPROP_FONTSIZE,9);
   ObjectSetString(0,name,OBJPROP_FONT,"Arial");
   ObjectSetString(0,name,OBJPROP_TEXT,text);
   ObjectSetInteger(0,name,OBJPROP_STATE,false);
   ObjectSetInteger(0,name,OBJPROP_BACK,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTABLE,false);
   ObjectSetInteger(0,name,OBJPROP_SELECTED,false);
   ObjectSetInteger(0,name,OBJPROP_HIDDEN,true);
   ObjectSetInteger(0,name,OBJPROP_ZORDER,100);
   return true;
}

bool HYQ_CreatePanel()
{
   if(!InpShowPanel) return true;

   HYQ_DeleteLegacyPanel();

   if(g_hyMinimized)
   {
      if(!HYQ_CreateRect(g_hyBg,InpPanelX,InpPanelY,150,30,clrBlack,clrDimGray,80)) return false;
      if(!HYQ_CreateButton(g_hyToggle,InpPanelX+2,InpPanelY+2,146,26,"匯鹰.量化 +")) return false;
      return true;
   }

   if(!HYQ_CreateRect(g_hyBg,InpPanelX,InpPanelY,620,350,C'15,19,25',C'72,79,88',80)) return false;
   if(!HYQ_CreateLabel(g_hyHeader,InpPanelX+12,InpPanelY+8,11,clrGold,
                       "匯鹰.量化 | DTGC v1.6 | "+Symbol()+" M15",90)) return false;
   if(!HYQ_CreateButton(g_hyToggle,InpPanelX+584,InpPanelY+5,28,23,"－")) return false;

   for(int i=0;i<HYQ_PANEL_LINES;i++)
   {
      if(!HYQ_CreateLabel(HYQ_LineName(i),InpPanelX+12,InpPanelY+38+i*18,
                          9,clrWhite,"",90)) return false;
      g_hyLastText[i]="";
      g_hyLastColor[i]=clrNONE;
   }
   return true;
}

void HYQ_SetLine(int index,string text,color textColor)
{
   if(index<0 || index>=HYQ_PANEL_LINES) return;
   string name=HYQ_LineName(index);
   if(ObjectFind(0,name)<0)
   {
      if(!HYQ_CreateLabel(name,InpPanelX+12,InpPanelY+38+index*18,
                          9,textColor,text,90)) return;
   }
   if(g_hyLastText[index]!=text)
   {
      ObjectSetString(0,name,OBJPROP_TEXT,text);
      g_hyLastText[index]=text;
   }
   if(g_hyLastColor[index]!=textColor)
   {
      ObjectSetInteger(0,name,OBJPROP_COLOR,textColor);
      g_hyLastColor[index]=textColor;
   }
}

void HYQ_UpdatePanel(bool force=false)
{
   if(!InpShowPanel) return;
   if(ObjectFind(0,g_hyBg)<0 || ObjectFind(0,g_hyToggle)<0)
   {
      HYQ_DeletePanel();
      if(!HYQ_CreatePanel()) return;
      force=true;
   }

   if(g_hyMinimized)
   {
      ObjectSetString(0,g_hyToggle,OBJPROP_TEXT,"匯鹰.量化 +");
      if(force) ChartRedraw();
      return;
   }

   double closedPnl=0.0;
   int dailyLosses=0;
   datetime lastLoss=0;
   TodayStats(closedPnl,dailyLosses,lastLoss);

   double spread=CurrentSpreadPrice();
   double dd=CurrentDrawdownPct();
   int initialTicket=FindInitialTicket();
   int addTicket=FindAddTicket();
   int pendingTicket=FindInitialPendingTicket();

   string riskText=(g_h1Score>=4 ? DoubleToString(EffectiveRiskPct(g_h1Score),2)+"%" : "待评分");
   string positionLine="无持仓";
   string groupLine="-";

   if(initialTicket>0)
   {
      double r=CurrentRForInitial(initialTicket);
      double mfe=MaxFavourableR(initialTicket);
      positionLine=StringFormat("初始#%d | %.2fR | MFE %.2fR",initialTicket,r,mfe);
      if(addTicket>0) positionLine+=" | 加仓#"+IntegerToString(addTicket);
      groupLine=StringFormat("时间减仓:%s | 盈利减仓:%s | 加仓:%s",
                  (TimePartialDone(initialTicket)?"已处理":"未处理"),
                  (ProfitPartialDone(initialTicket)?"已处理":"未处理"),
                  (AddDone(initialTicket)?"已处理":"未处理"));
   }
   else if(pendingTicket>0 && OrderSelect(pendingTicket,SELECT_BY_TICKET))
   {
      positionLine=StringFormat("服务器挂单#%d | %s @ %s",pendingTicket,
                   (OrderType()==OP_BUYSTOP?"BuyStop":"SellStop"),
                   DoubleToString(OrderOpenPrice(),Digits));
      groupLine="挂单由H4/H1、时段、新闻和账户保护共同管理";
   }

   g_lastForeignMarketCount=CountForeignOrders(false);
   g_lastForeignPendingCount=(InpBlockForeignPendings
                              ? CountForeignOrders(true)-g_lastForeignMarketCount : 0);

   string entryMode=(InpEntryMode==ENTRY_SERVER_STOP?"服务器Stop":"Tick市价");
   string scope=(InpForeignScope==FOREIGN_WHOLE_ACCOUNT?"全账户":"同品种");

   color stateColor=clrWhite;
   if(g_state==ST_COOLDOWN || dd>=InpHardStopDrawdownPct) stateColor=clrTomato;
   else if(g_state==ST_ENTRY_ARMED || g_state==ST_ADD_READY) stateColor=clrGold;
   else if(StrategyOrderCount()>0) stateColor=clrLime;

   HYQ_SetLine(0,"状态："+StateName(g_state)+" | 执行："+entryMode,stateColor);
   HYQ_SetLine(1,"原因："+HYQ_Trim(g_reason,80),clrWhite);
   HYQ_SetLine(2,"H4："+DirectionName(g_h4Direction)+" | "+HYQ_Trim(g_h4Text,68),clrSilver);
   HYQ_SetLine(3,StringFormat("H1入场：%d/5 | 多%d 空%d",g_h1Score,g_h1ScoreLong,g_h1ScoreShort),clrSilver);
   HYQ_SetLine(4,"信号："+HYQ_Trim(g_signalText,78),clrSilver);
   HYQ_SetLine(5,"M15稳健ATR："+DoubleToString(g_atrRefM15,Digits)+" | 点差："+DoubleToString(spread,Digits),clrSilver);
   HYQ_SetLine(6,"风险："+riskText+" | 复利基数："+DoubleToString(g_compoundingBase,2),clrSilver);
   HYQ_SetLine(7,"净值回撤："+DoubleToString(dd,2)+"% | 今日已平："+DoubleToString(closedPnl,2),clrSilver);
   HYQ_SetLine(8,"今日初始亏损："+IntegerToString(dailyLosses)+"/"+IntegerToString(InpMaxDailyInitialLosses),clrSilver);
   HYQ_SetLine(9,"持仓/挂单："+HYQ_Trim(positionLine,76),clrWhite);
   HYQ_SetLine(10,"组状态："+HYQ_Trim(groupLine,78),clrSilver);
   HYQ_SetLine(11,"外部暴露("+scope+")：持仓"+IntegerToString(g_lastForeignMarketCount)+" 挂单"+IntegerToString(g_lastForeignPendingCount),clrSilver);
   HYQ_SetLine(12,"保护成本估算："+DoubleToString(EstimatedProtectionCostPrice(),Digits)+" | 往返佣金/手："+DoubleToString(InpCommissionPerLotRoundTurn,2),clrSilver);
   HYQ_SetLine(13,"存储：Magic+GV+Comment | 历史缓存："+IntegerToString((int)MathMax(0,TimeCurrent()-g_historyCacheTime))+"秒",clrSilver);
   HYQ_SetLine(14,"新闻："+(InpManualNewsBlock?"手动冻结":"核心版未接API")+" | 时段："+(SessionOK()?"允许":"禁止"),clrSilver);
   HYQ_SetLine(15,"公开说明："+HYQ_DOC_URL,clrGold);

   ChartRedraw();
}

bool HYQ_H1HardExitSafe(int direction)
{
   int required=MathMax(InpH1TrendDonchianPeriod,InpH1ExitDonchianPeriod)+InpATRSample+10;
   if(iBars(Symbol(),PERIOD_H1)<required)
   {
      g_reason="H1历史数据不足，暂停结构硬退出，保留已有止损保护";
      return false;
   }

   double close1=iClose(Symbol(),PERIOD_H1,1);
   double mid20=g_h1ExitMid20;
   if(close1<=0.0 || mid20<=0.0) return false;

   if(DirectionalH1Score(direction)<=2) return true;
   if(direction>0 && close1<mid20) return true;
   if(direction<0 && close1>mid20) return true;
   return false;
}

// 修正版持仓管理：
// 1. 初始R丢失时，不再把已推到保本/盈利侧的SL误当成初始风险。
// 2. 加仓仓锁盈价格始终以初始仓开仓价为基准，避免FindAddTicket改变当前选单。
// 3. H1历史数据不足时不触发结构硬平仓，仍由服务器止损保护。
void ManageOpenPositions()
{
   int initialTicket=FindInitialTicket();
   if(initialTicket<0)
   {
      if(FindAddTicket()>0) CloseAllStrategyOrders("孤立加仓单");
      return;
   }

   if(!OrderSelect(initialTicket,SELECT_BY_TICKET)) return;
   int direction=(OrderType()==OP_BUY?1:-1);
   double initialOpen=OrderOpenPrice();
   double initialLots=OrderLots();
   double initialSL=OrderStopLoss();
   double risk=LoadInitialRisk(initialTicket);

   if(risk<=0.0)
   {
      bool slOnOriginalRiskSide=(initialSL>0.0 &&
                               ((direction>0 && initialSL<initialOpen) ||
                                (direction<0 && initialSL>initialOpen)));
      if(slOnOriginalRiskSide)
      {
         risk=MathAbs(initialOpen-initialSL);
         if(risk>0.0) SaveInitialRisk(initialTicket,risk,initialLots);
      }
   }
   if(risk<=0.0)
   {
      g_reason="初始R无法可靠恢复；不执行R倍数管理，保留现有服务器止损";
      return;
   }

   double r=CurrentRForInitial(initialTicket);
   double mfe=MaxFavourableR(initialTicket);
   int bars=BarsSinceOrderOpen(initialTicket);
   g_state=(r>=InpProtectAtR?ST_PROTECTED:ST_INITIAL_POSITION);
   g_reason=StringFormat("持仓%.2fR | MFE %.2fR | %d根M15",r,mfe,bars);

   if(InpCloseBeforeWeekend && TimeDayOfWeek(TimeCurrent())==5 &&
      TimeHour(TimeCurrent())>=InpFridayCloseHour)
   {
      CloseAllStrategyOrders("周末前强制退出");
      ResetSignal("周末平仓");
      return;
   }

   if(HYQ_H1HardExitSafe(direction))
   {
      CloseAllStrategyOrders("H1趋势失效");
      ResetSignal("H1趋势退出");
      return;
   }

   double c1=iClose(Symbol(),PERIOD_M15,1);
   double c2=iClose(Symbol(),PERIOD_M15,2);
   double channelHi=DonchianHigh(PERIOD_M15,InpM15BreakoutPeriod,2);
   double channelLo=DonchianLow(PERIOD_M15,InpM15BreakoutPeriod,2);
   bool twoClosesInside=(direction>0?(c1<channelHi && c2<channelHi):(c1>channelLo && c2>channelLo));

   if(bars>=InpTimeCheckBars2 && mfe<InpTimeCheckMFE2R &&
      (twoClosesInside || ReverseLargeBodyAgainst(direction)))
   {
      CloseAllStrategyOrders("12根K时间+价格失败");
      ResetSignal("时间失败退出");
      return;
   }

   if(bars>=InpTimeCheckBars1 && mfe<InpTimeCheckMFE1R &&
      twoClosesInside && !TimePartialDone(initialTicket))
   {
      if(OrderSelect(initialTicket,SELECT_BY_TICKET))
      {
         double minLot=MarketInfo(Symbol(),MODE_MINLOT);
         double closeLots=NormalizeLots(OrderLots()*0.50);
         double remain=OrderLots()-closeLots;
         if(closeLots>=minLot && remain>=minLot)
         {
            if(CloseTicketLots(initialTicket,closeLots,"8根K弱势减仓"))
               MarkTimePartialDone(initialTicket);
         }
         else
         {
            MarkTimePartialDone(initialTicket);
            g_reason="8根K减仓量低于平台最小手数，已跳过";
         }
      }
   }

   if(r>=InpProtectAtR)
   {
      if(OrderSelect(initialTicket,SELECT_BY_TICKET))
      {
         double cost=EstimatedProtectionCostPrice();
         double be=(direction>0?initialOpen+cost:initialOpen-cost);
         ModifySL(initialTicket,be);
      }
      g_state=ST_PROTECTED;
   }

   if(InpEnableProfitAdd && r>=InpProtectAtR && !AddDone(initialTicket) &&
      FindAddTicket()<0 && g_h4Direction==direction &&
      DirectionalH1Score(direction)>=4 && ForeignExposureOK() && SpreadOK())
   {
      double buffer=MathMax(InpEntryBufferATR*g_atrRefM15,CurrentSpreadPrice());
      bool trigger=false;
      if(direction>0)
         trigger=(Ask>DonchianHigh(PERIOD_M15,InpM15AddPeriod,1)+buffer);
      else
         trigger=(Bid<DonchianLow(PERIOD_M15,InpM15AddPeriod,1)-buffer);
      if(trigger)
      {
         g_state=ST_ADD_READY;
         OpenAdd(initialTicket);
      }
   }

   if(mfe>=InpLockAtR)
   {
      if(InpExitMode==1 && !ProfitPartialDone(initialTicket))
      {
         if(OrderSelect(initialTicket,SELECT_BY_TICKET))
         {
            double minLot=MarketInfo(Symbol(),MODE_MINLOT);
            double closeLots=NormalizeLots(OrderLots()*InpPartialClosePercent/100.0);
            double remain=OrderLots()-closeLots;
            if(closeLots>=minLot && remain>=minLot)
            {
               if(CloseTicketLots(initialTicket,closeLots,"2R部分止盈"))
                  MarkProfitPartialDone(initialTicket);
            }
            else
            {
               MarkProfitPartialDone(initialTicket);
               g_reason="2R减仓量低于平台最小手数，继续全仓跟踪";
            }
         }
      }

      double lockSL=(direction>0?initialOpen+InpLockProfitR*risk
                                 :initialOpen-InpLockProfitR*risk);
      ModifySL(initialTicket,lockSL);
      int addTicket=FindAddTicket();
      if(addTicket>0) ModifySL(addTicket,lockSL);
   }

   ApplyTrendStops(initialTicket);
   g_state=ST_TREND_HOLD;
}

int OnInit()
{
   int result=DTGC_Base_OnInit();
   if(result!=INIT_SUCCEEDED) return result;

   DTGC_Base_DeletePanel();
   HYQ_DeleteLegacyPanel();
   HYQ_InitObjectNames();

   if(GlobalVariableCheck(HYQ_MinStateKey()))
      g_hyMinimized=(GlobalVariableGet(HYQ_MinStateKey())>0.5);
   else
      g_hyMinimized=false;

   HYQ_DeletePanel();
   if(!HYQ_CreatePanel())
   {
      Print("匯鹰量化面板创建失败；EA交易核心继续运行，请检查专家日志。通用错误码=",GetLastError());
   }
   HYQ_UpdatePanel(true);
   g_lastPanelRefresh=TimeCurrent();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   GlobalVariableSet(HYQ_MinStateKey(),(g_hyMinimized?1.0:0.0));
   HYQ_DeletePanel();
   DTGC_Base_OnDeinit(reason);
}

void OnTick()
{
   UpdateCompoundingBase();

   datetime barTime=iTime(Symbol(),PERIOD_M15,0);
   if(barTime!=g_lastM15BarTime)
   {
      g_lastM15BarTime=barTime;
      RefreshHistoryCache(true);
      ProcessNewM15Bar();
   }

   ManagePendingEntry();
   ManageOpenPositions();
   TryEntryOnTick();

   datetime now=TimeCurrent();
   if(g_lastPanelRefresh==0 ||
      now-g_lastPanelRefresh>=MathMax(1,InpPanelRefreshSeconds))
   {
      HYQ_UpdatePanel(false);
      g_lastPanelRefresh=now;
   }
}

void OnChartEvent(const int id,const long &lparam,const double &dparam,const string &sparam)
{
   if(id!=CHARTEVENT_OBJECT_CLICK || sparam!=g_hyToggle) return;

   ObjectSetInteger(0,g_hyToggle,OBJPROP_STATE,false);
   g_hyMinimized=!g_hyMinimized;
   GlobalVariableSet(HYQ_MinStateKey(),(g_hyMinimized?1.0:0.0));

   HYQ_DeletePanel();
   HYQ_CreatePanel();
   HYQ_UpdatePanel(true);
}
//+------------------------------------------------------------------+
