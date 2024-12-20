﻿////////////////////////////////////////////////////////////////////////////////
//
//  ****************************************************************************
//  * Project   : CPU-View
//  * Unit Name : dlgCpuView.pas
//  * Purpose   : Basic GUI debugger class without CPU-specific implementation code
//  * Author    : Alexander (Rouse_) Bagel
//  * Copyright : © Fangorn Wizards Lab 1998 - 2024.
//  * Version   : 1.0
//  * Home Page : http://rouse.drkb.ru
//  * Home Blog : http://alexander-bagel.blogspot.ru
//  ****************************************************************************
//  * Latest Release : https://github.com/AlexanderBagel/CPUView/releases
//  * Latest Source  : https://github.com/AlexanderBagel/CPUView
//  ****************************************************************************
//

unit dlgCpuView;

{$mode Delphi}
{$WARN 5024 off : Parameter "$1" not used}

interface

uses
  LCLIntf, LCLType, Classes, SysUtils, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls, Menus, ComCtrls, ActnList,

  FWHexView,
  FWHexView.Actions,
  FWHexView.MappedView,

  CpuView.Core,
  CpuView.Common,
  CpuView.CPUContext,
  CpuView.Viewers,
  CpuView.DebugerGate,
  CpuView.FpDebug,
  CpuView.Actions,
  CpuView.Settings,
  CpuView.Design.CrashDump,
  CpuView.Design.DbgLog;

type

  { TfrmCpuView }

  TfrmCpuView = class(TForm)
    acShowInDump: TAction;
    acShowInStack: TAction;
    acShowInAsm: TAction;
    acHighlightReg: TAction;
    acStackFollowRSP: TAction;
    acTEAnsi: TAction;
    acTEAscii: TAction;
    acTEUnicode: TAction;
    acTEUnicodeBE: TAction;
    acTEUtf7: TAction;
    acTEUtf8: TAction;
    acDbgStepIn: TAction;
    acDbgStepOut: TAction;
    acDbgRunTilReturn: TAction;
    acDbgRunTo: TAction;
    acDbgToggleBp: TAction;
    acRegModifyInc: TAction;
    acRegModifyDec: TAction;
    acRegModifyToggle: TAction;
    acRegModifyZero: TAction;
    acRegModifyNewValue: TAction;
    acAsmReturnToIP: TAction;
    acAsmSetNewIP: TAction;
    acAsmShowSource: TAction;
    acShowInNewDump: TAction;
    acDumpsClosePage: TAction;
    acDumpsCloseAllToTheRight: TAction;
    acViewGoto: TAction;
    acViewFitColumnToBestSize: TAction;
    ActionList: TActionList;
    AsmView: TAsmView;
    acVmHex: TCpuContextRegViewModeAction;
    acVmHexW: TCpuContextRegViewModeAction;
    acVmHexD: TCpuContextRegViewModeAction;
    acVmHexQ: TCpuContextRegViewModeAction;
    acVmOct: TCpuContextRegViewModeAction;
    acVmBin: TCpuContextRegViewModeAction;
    acVmIntB: TCpuContextRegViewModeAction;
    acVmUIntB: TCpuContextRegViewModeAction;
    acVmIntW: TCpuContextRegViewModeAction;
    acVmIntD: TCpuContextRegViewModeAction;
    acVmIntQ: TCpuContextRegViewModeAction;
    acVmUIntW: TCpuContextRegViewModeAction;
    acVmUIntD: TCpuContextRegViewModeAction;
    acVmUIntQ: TCpuContextRegViewModeAction;
    acVmFloat32: TCpuContextRegViewModeAction;
    acVmFloat64: TCpuContextRegViewModeAction;
    acVmFloat80: TCpuContextRegViewModeAction;
    DumpView: TDumpView;
    edCommands: TEdit;
    acCopy: THexViewCopyAction;
    acCopyBytes: THexViewCopyAction;
    acCopyAddress: THexViewCopyAction;
    acCopyPas: THexViewCopyAction;
    acCopyAsm: THexViewCopyAction;
    acDMHex8: THexViewByteViewModeAction;
    acDMHex16: THexViewByteViewModeAction;
    acDMHex32: THexViewByteViewModeAction;
    acDMHex64: THexViewByteViewModeAction;
    acDMInt8: THexViewByteViewModeAction;
    acDMInt16: THexViewByteViewModeAction;
    acDMInt32: THexViewByteViewModeAction;
    acDMInt64: THexViewByteViewModeAction;
    acDMUInt8: THexViewByteViewModeAction;
    acDMUInt16: THexViewByteViewModeAction;
    acDMUInt32: THexViewByteViewModeAction;
    acDMUInt64: THexViewByteViewModeAction;
    acDMFloat32: THexViewByteViewModeAction;
    acDMFloat64: THexViewByteViewModeAction;
    acDMFloat80: THexViewByteViewModeAction;
    acDMAddress: THexViewByteViewModeAction;
    acDMText: THexViewByteViewModeAction;
    memHints: TMemo;
    miProfilerSaveDump: TMenuItem;
    miResetProfiler: TMenuItem;
    miDebugGenException: TMenuItem;
    miDumpsCloseRight: TMenuItem;
    miAsmRunTo: TMenuItem;
    miStackShowInNewDump: TMenuItem;
    miDumpShowInNewDump: TMenuItem;
    miAsmShowInNewDump: TMenuItem;
    miRegShowInNewDump: TMenuItem;
    miDumpsClosePage: TMenuItem;
    miStackShowInStack: TMenuItem;
    miDumpShowInDump: TMenuItem;
    miAsmSource: TMenuItem;
    miAsmCurrentIP: TMenuItem;
    miAsmSetNewIP: TMenuItem;
    miStackFollowRsp: TMenuItem;
    miStackGoto: TMenuItem;
    miDumpGoto: TMenuItem;
    miAsmGoto: TMenuItem;
    miRegFit: TMenuItem;
    miRegSep5: TMenuItem;
    miStackSep2: TMenuItem;
    miStackFit: TMenuItem;
    miDumpFit: TMenuItem;
    miDumpSep4: TMenuItem;
    miAsmFit: TMenuItem;
    miRegChangeValue: TMenuItem;
    miRegZeroValue: TMenuItem;
    miRegToggleFlag: TMenuItem;
    miRegDecValue: TMenuItem;
    miRegIncValue: TMenuItem;
    miTEAnsi: TMenuItem;
    miTEAscii: TMenuItem;
    miTEUnicode: TMenuItem;
    miTEUnicodeBE: TMenuItem;
    miTEUtf7: TMenuItem;
    miTEUtf8: TMenuItem;
    miDumpTextEncoding: TMenuItem;
    miRegDMHex: TMenuItem;
    miRegDMIntQ: TMenuItem;
    miRegDMUIntB: TMenuItem;
    miRegDMUIntW: TMenuItem;
    miRegDMUIntD: TMenuItem;
    miRegDMUIntQ: TMenuItem;
    miRegDMFloat32: TMenuItem;
    miRegDMFloat64: TMenuItem;
    miRegDMFloat80: TMenuItem;
    miRegCopy: TMenuItem;
    miRegCopyValue: TMenuItem;
    miDumpDMFloat80: TMenuItem;
    miDumpDMAddress: TMenuItem;
    miStackShowInAsm: TMenuItem;
    miStackShowInDump: TMenuItem;
    miStackCopyAddr: TMenuItem;
    miStackCopy: TMenuItem;
    miStackCopyValue: TMenuItem;
    miAsmShowInDump: TMenuItem;
    miAsmShowInStack: TMenuItem;
    miAsmCopyAddr: TMenuItem;
    miAsmCopy: TMenuItem;
    miDumpShowInAsm: TMenuItem;
    miDumpShowInStack: TMenuItem;
    miDumpDisplayMode: TMenuItem;
    miDumpDMHex: TMenuItem;
    miDumpDMHexW: TMenuItem;
    miDumpDMHexD: TMenuItem;
    miDumpDMHexQ: TMenuItem;
    miDumpDMIntB: TMenuItem;
    miDumpDMIntW: TMenuItem;
    miDumpDMIntD: TMenuItem;
    miDumpDMIntQ: TMenuItem;
    miDumpDMUIntB: TMenuItem;
    miDumpDMUIntW: TMenuItem;
    miDumpDMUIntD: TMenuItem;
    miDumpDMUIntQ: TMenuItem;
    miDumpDMFloat32: TMenuItem;
    miDumpDMFloat64: TMenuItem;
    miDumpDMText: TMenuItem;
    miDumpCopyAddr: TMenuItem;
    miDumpCopy: TMenuItem;
    miDumpCopyBytes: TMenuItem;
    miDumpCopyPas: TMenuItem;
    miDumpCopyAsm: TMenuItem;
    miDumpSep3: TMenuItem;
    miDumpSep2: TMenuItem;
    miDumpDMSep4: TMenuItem;
    miDumpDMSep3: TMenuItem;
    miDumpDMSep2: TMenuItem;
    miDumpDMSep1: TMenuItem;
    miDumpSep1: TMenuItem;
    miAsmSep2: TMenuItem;
    pnDumpStack: TPanel;
    pmDump: TPopupMenu;
    pmAsm: TPopupMenu;
    miStackSep1: TMenuItem;
    pmStack: TPopupMenu;
    miRegSep3: TMenuItem;
    miRegHighlight: TMenuItem;
    miRegSep2: TMenuItem;
    miRegShowInDump: TMenuItem;
    miRegShowInStack: TMenuItem;
    miRegShowInAsm: TMenuItem;
    miRegSep4: TMenuItem;
    miRegDMSep4: TMenuItem;
    miRegDMSep3: TMenuItem;
    miRegDMHexW: TMenuItem;
    miRegDMHexD: TMenuItem;
    miRegDMHexQ: TMenuItem;
    miRegDMOctal: TMenuItem;
    miRegDMBin: TMenuItem;
    miRegDMIntB: TMenuItem;
    miRegDMIntW: TMenuItem;
    miRegDMIntD: TMenuItem;
    miRegDMSep2: TMenuItem;
    miRegDMSep1: TMenuItem;
    miRegDisplayMode: TMenuItem;
    pcDumps: TPageControl;
    pnDumps: TPanel;
    pnAsmReg: TPanel;
    pnDebug: TPanel;
    pmRegSelected: TPopupMenu;
    pmHint: TPopupMenu;
    pmDumps: TPopupMenu;
    pmDebug: TPopupMenu;
    RegView: TRegView;
    miRegSep1: TMenuItem;
    miAsmSep3: TMenuItem;
    miAsmSep1: TMenuItem;
    miAsmSep0: TMenuItem;
    miDumpSep0: TMenuItem;
    miStackSep0: TMenuItem;
    splitAsmDumps: TSplitter;
    splitDumpStack: TSplitter;
    splitAsmReg: TSplitter;
    StackView: TStackView;
    StatusBar: TStatusBar;
    tabDump0: TTabSheet;
    tmpZOrderLock: TTimer;
    ToolBar: TToolBar;
    tbStepIn: TToolButton;
    tbStepOut: TToolButton;
    tbSep1: TToolButton;
    tbBreakPoint: TToolButton;
    tbSep2: TToolButton;
    tbRunTillRet: TToolButton;
    tbRunTo: TToolButton;
    procedure acAsmReturnToIPExecute(Sender: TObject);
    procedure acAsmReturnToIPUpdate(Sender: TObject);
    procedure acAsmSetNewIPExecute(Sender: TObject);
    procedure acAsmShowSourceExecute(Sender: TObject);
    procedure acAsmShowSourceUpdate(Sender: TObject);
    procedure acDbgRunTilReturnExecute(Sender: TObject);
    procedure acDbgRunToExecute(Sender: TObject);
    procedure acDbgRunToUpdate(Sender: TObject);
    procedure acDbgStepInExecute(Sender: TObject);
    procedure acDbgStepOutExecute(Sender: TObject);
    procedure acDbgToggleBpExecute(Sender: TObject);
    procedure acDumpsCloseAllToTheRightExecute(Sender: TObject);
    procedure acDumpsCloseAllToTheRightUpdate(Sender: TObject);
    procedure acDumpsClosePageExecute(Sender: TObject);
    procedure acDumpsClosePageUpdate(Sender: TObject);
    procedure acHighlightRegExecute(Sender: TObject);
    procedure acHighlightRegUpdate(Sender: TObject);
    procedure acRegModifyDecExecute(Sender: TObject);
    procedure acRegModifyIncExecute(Sender: TObject);
    procedure acRegModifyNewValueExecute(Sender: TObject);
    procedure acRegModifyToggleExecute(Sender: TObject);
    procedure acRegModifyZeroExecute(Sender: TObject);
    procedure acShowInAsmExecute(Sender: TObject);
    procedure acShowInAsmUpdate(Sender: TObject);
    procedure acShowInDumpExecute(Sender: TObject);
    procedure acShowInDumpUpdate(Sender: TObject);
    procedure acShowInNewDumpExecute(Sender: TObject);
    procedure acShowInStackExecute(Sender: TObject);
    procedure acShowInStackUpdate(Sender: TObject);
    procedure acStackFollowRSPExecute(Sender: TObject);
    procedure acTEAnsiExecute(Sender: TObject);
    procedure acTEAnsiUpdate(Sender: TObject);
    procedure ActionRegModifyUpdate(Sender: TObject);
    procedure acViewFitColumnToBestSizeExecute(Sender: TObject);
    procedure acViewGotoExecute(Sender: TObject);
    procedure AsmViewSelectionChange(Sender: TObject);
    procedure DumpViewSelectionChange(Sender: TObject);
    procedure FormChangeBounds(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormDeactivate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure miDebugGenExceptionClick(Sender: TObject);
    procedure miProfilerSaveDumpClick(Sender: TObject);
    procedure miResetProfilerClick(Sender: TObject);
    procedure pcDumpsChange(Sender: TObject);
    procedure RegViewSelectedContextPopup(Sender: TObject; MousePos: TPoint;
      RowIndex: Int64; ColIndex: Integer; var Handled: Boolean);
    procedure RegViewSelectionChange(Sender: TObject);
    procedure StackViewSelectionChange(Sender: TObject);
    procedure tmpZOrderLockTimer(Sender: TObject);
    procedure DefaultActionUpdate(Sender: TObject);
  private
    FCore: TCpuViewCore;
    FContext: TCommonCpuContext;
    FDbgGate: TCpuViewDebugGate;
    FSettings: TCpuViewSettins;
    FAsmViewSelectedAddr,
    FContextRegValue,
    FDumpSelectedValue,
    FStackSelectedValue: UInt64;
    FDumpNameIdx: Integer;
    FContextRegName, FSourcePath: string;
    FContextRegister: TRegister;
    FContextRegisterParam: TRegParam;
    FQweryAddrViewerIndex: Integer;
    FSourceLine: Integer;
    FLastBounds: TRect;
    FCrashDump: TExceptionLogger;
    function ActiveViewerSelectedValue: UInt64;
    function CheckAddressCallback(ANewAddrVA: UInt64): Boolean;
    function CheckRegCallback(ANewAddrVA: UInt64): Boolean;
    procedure InternalShowInDump(AddrVA: Int64);
  protected
    function ActiveDumpView: TDumpView;
    function ActiveViewIndex: Integer;
    procedure AfterDbgGateCreate; virtual; abstract;
    procedure BeforeDbgGateDestroy; virtual; abstract;
    function GetContext: TCommonCpuContext; virtual; abstract;
    function ToDpi(Value: Integer): Integer;
    function ToDefaultDpi(Value: Integer): Integer;
    procedure LockZOrder;
    function MeasureCanvas: TBitmap;
    function QweryAccessStr(AddrVA: UInt64): string;
    procedure UnlockZOrder;
    procedure UpdateStatusBar;
  public
    procedure LoadSettings;
    procedure SaveSettings;
    property Core: TCpuViewCore read FCore;
    property DbgGate: TCpuViewDebugGate read FDbgGate;
    property Settings: TCpuViewSettins read FSettings;
  end;

var
  frmCpuView: TfrmCpuView;

implementation

uses
  CpuView.Design.Common,
  dlgCpuView.TemporaryLocker,
  dlgInputBox,
  IDEImagesIntf,
  BaseDebugManager,
  uni_profiler;

{$R *.lfm}

{ TfrmCpuView }

procedure TfrmCpuView.FormCreate(Sender: TObject);
begin
  FCrashDump := TExceptionLogger.Create;
  FSettings := TCpuViewSettins.Create;
  FCore := TCpuViewCore.Create(TCpuViewDebugGate);
  FContext := GetContext;
  FDbgGate := FCore.Debugger as TCpuViewDebugGate;
  FDbgGate.Context := FContext;
  AfterDbgGateCreate;
  FCore.AsmView := AsmView;
  FCore.RegView := RegView;
  FCore.DumpViewList.Add(DumpView);
  FCore.StackView := StackView;
  ToolBar.Images := IDEImages.Images_16;
  tbBreakPoint.ImageIndex := IDEImages.LoadImage('ActiveBreakPoint');
  tbRunTo.ImageIndex := IDEImages.LoadImage('menu_run_cursor');
  tbRunTillRet.ImageIndex := IDEImages.LoadImage('menu_stepout');
  tbStepIn.ImageIndex := IDEImages.LoadImage('menu_stepinto');
  tbStepOut.ImageIndex := IDEImages.LoadImage('menu_stepover');
  pmAsm.Images := IDEImages.Images_16;
  miAsmRunTo.ImageIndex := tbRunTo.ImageIndex;
  miAsmCurrentIP.ImageIndex := IDEImages.LoadImage('debugger_show_execution_point');
  SetHooks;
  LoadSettings;
  CpuViewDebugLog.Reset;
  CpuViewDebugLog.Log('TfrmCpuView: start', True, False);
end;

procedure TfrmCpuView.FormDeactivate(Sender: TObject);
begin
  if tmpZOrderLock.Enabled then
  begin
    SetWindowPos(Handle, HWND_TOP, 0, 0, 0, 0, SWP_NOMOVE or SWP_NOSIZE);
    BringToFront;
  end;
end;

procedure TfrmCpuView.FormDestroy(Sender: TObject);
begin
  ResetHooks;
  SaveSettings;
  BeforeDbgGateDestroy;
  FDbgGate.Context := nil;
  FContext.Free;
  FCore.Free;
  FSettings.Free;
  FCrashDump.Free;
  CpuViewDebugLog.Log('TfrmCpuView: end', False);
  CpuViewDebugLog.Enabled := False;
end;

procedure TfrmCpuView.FormKeyPress(Sender: TObject; var Key: char);
begin
  if Ord(Key) = VK_ESCAPE then
    Close;
end;

procedure TfrmCpuView.miDebugGenExceptionClick(Sender: TObject);
begin
  raise Exception.Create('Test exception');
end;

procedure TfrmCpuView.miProfilerSaveDumpClick(Sender: TObject);
begin
  uprof.SaveToFile(DebugFolder + 'profile.txt');
end;

procedure TfrmCpuView.miResetProfilerClick(Sender: TObject);
begin
  uprof.Reset;
end;

procedure TfrmCpuView.pcDumpsChange(Sender: TObject);
begin
  Core.DumpViewList.ItemIndex := pcDumps.PageIndex;
end;

procedure TfrmCpuView.RegViewSelectedContextPopup(Sender: TObject;
  MousePos: TPoint; RowIndex: Int64; ColIndex: Integer; var Handled: Boolean);
begin
  if ColIndex >= 0 then
  begin
    FContextRegValue := 0;
    FContextRegName := RegView.SelectedRegName;
    FContextRegister := RegView.SelectedRegister;
    Handled := RegView.Context.RegParam(FContextRegister.RegID, FContextRegisterParam) and
      (RegView.ReadDataAtSelStart(FContextRegValue, SizeOf(FContextRegValue)) > 0);
    if Handled then
    begin
      MousePos := TWinControl(Sender).ClientToScreen(MousePos);
      pmRegSelected.Popup(MousePos.X, MousePos.Y);
    end;
  end;
end;

procedure TfrmCpuView.RegViewSelectionChange(Sender: TObject);
begin
  FContextRegName := RegView.SelectedRegName;
  FContextRegValue := 0;
  RegView.ReadDataAtSelStart(FContextRegValue, FDbgGate.PointerSize);
  UpdateStatusBar;
end;

procedure TfrmCpuView.StackViewSelectionChange(Sender: TObject);
begin
  FStackSelectedValue := 0;
  StackView.ReadDataAtSelStart(FStackSelectedValue, FDbgGate.PointerSize);
  UpdateStatusBar;
end;

procedure TfrmCpuView.tmpZOrderLockTimer(Sender: TObject);
begin
  UnlockZOrder;
end;

procedure TfrmCpuView.DefaultActionUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := DbgGate.DebugState = adsPaused;
end;

function TfrmCpuView.ActiveViewerSelectedValue: UInt64;
begin
  Result := 0;
  if AsmView.Focused then
    Exit(FAsmViewSelectedAddr);
  if ActiveDumpView.Focused then
    Exit(FDumpSelectedValue);
  if RegView.Focused then
    Exit(FContextRegValue);
  if StackView.Focused then
    Result := FStackSelectedValue;
end;

function TfrmCpuView.CheckAddressCallback(ANewAddrVA: UInt64): Boolean;
begin
  case FQweryAddrViewerIndex of
    0: Result := FCore.AddrInAsm(ANewAddrVA);
    2: Result := FCore.AddrInStack(ANewAddrVA);
    3: Result := FCore.AddrInDump(ANewAddrVA);
  else
    Result := False;
  end
end;

function TfrmCpuView.CheckRegCallback(ANewAddrVA: UInt64): Boolean;
begin
  Result := True;
end;

procedure TfrmCpuView.InternalShowInDump(AddrVA: Int64);
begin
  Core.ShowDumpAtAddr(AddrVA);
  ActiveDumpView.SelStart := AddrVA;
  if ActiveViewIndex = 0 then
    ActiveDumpView.SelEnd := AddrVA + AsmView.SelectedRawLength - 1
  else
    ActiveDumpView.SelEnd := AddrVA + FDbgGate.PointerSize - 1;
  ActiveControl := ActiveDumpView;
end;

procedure TfrmCpuView.UpdateStatusBar;
const
  DbgStates: array [TAbstractDebugState] of string = (
    'Error', 'Stoped', 'Start', 'Paused', 'Running', 'Finished'
  );
var
  AddrVA: UInt64;
  AccessStr, Symbol: string;
  AMeasureCanvas: TBitmap;
begin
  StatusBar.Panels[0].Text := Format('Pid: %d, Tid: %d, State: %s',
    [DbgGate.ProcessID, DbgGate.ThreadID, DbgStates[DbgGate.DebugState]]);
  AddrVA := ActiveViewerSelectedValue;
  AccessStr := QweryAccessStr(AddrVA);
  Symbol := FCore.QuerySymbolAtAddr(AddrVA);
  StatusBar.Panels[1].Text := Format('Addr:  0x%x (%s) %s', [AddrVA, AccessStr, Symbol]);
  AMeasureCanvas := MeasureCanvas;
  try
    StatusBar.Panels[0].Width :=
      AMeasureCanvas.Canvas.TextWidth(StatusBar.Panels[0].Text) + ToDpi(16);
    StatusBar.Panels[1].Width :=
      AMeasureCanvas.Canvas.TextWidth(StatusBar.Panels[1].Text) + ToDpi(16);
  finally
    AMeasureCanvas.Free;
  end;
end;

procedure TfrmCpuView.LoadSettings;
var
  R: TRect;
begin
  Settings.Load(ConfigPath);
  Settings.SetSettingsToAsmView(AsmView);
  Settings.SetSettingsToDumpView(DumpView);
  Settings.SetSettingsToRegView(RegView);
  Settings.SetSettingsToContext(DbgGate.Context);
  Settings.SetSettingsToStackView(StackView);
  R := Settings.CpuViewDlgSettings.BoundsRect;
  if R.IsEmpty then
    Position := poScreenCenter
  else
  begin
    Position := poDesigned;
    SetBounds(R.Left, R.Top, ToDpi(R.Width), ToDpi(R.Height));
  end;
  if Settings.CpuViewDlgSettings.Maximized then
    WindowState := wsMaximized
  else
    WindowState := wsNormal;
  RegView.Width := Round(Settings.CpuViewDlgSettings.SplitterPos[spTopHorz] * (ClientWidth / 100));
  StackView.Width := Round(Settings.CpuViewDlgSettings.SplitterPos[spBottomHorz] * (ClientWidth / 100));
  pnDumps.Height := Round(Settings.CpuViewDlgSettings.SplitterPos[spCenterVert] * (ClientHeight / 100));

  if (Core.ShowCallFuncName <> Settings.ShowCallFuncName) or
    (DbgGate.ShowSourceLines <> Settings.ShowSourceLines) or
    (DbgGate.UseDebugInfo <> Settings.UseDebugInfo) then
  begin
    Core.ShowCallFuncName := Settings.ShowCallFuncName;
    DbgGate.ShowSourceLines := Settings.ShowSourceLines;
    DbgGate.UseDebugInfo := Settings.UseDebugInfo;
    Core.UpdateAfterSettingsChange;
  end;

  FCrashDump.Enabled := Settings.UseCrashDump;
  CpuViewDebugLog.Enabled := Settings.UseDebugLog;
end;

procedure TfrmCpuView.SaveSettings;
var
  DlgSettings: TCpuViewDlgSettings;
begin
  if not (Settings.SaveViewersSession or Settings.SaveFormSession) then Exit;
  if Settings.SaveViewersSession then
  begin
    Settings.GetSessionFromAsmView(AsmView);
    Settings.GetSessionFromDumpView(DumpView);
    Settings.GetSessionFromRegView(RegView);
    Settings.GetSessionFromContext(DbgGate.Context);
    Settings.GetSessionFromStackView(StackView);
  end;
  if Settings.SaveFormSession then
  begin
    DlgSettings.BoundsRect := FLastBounds;
    DlgSettings.BoundsRect.Width := ToDefaultDpi(FLastBounds.Width);
    DlgSettings.BoundsRect.Height := ToDefaultDpi(FLastBounds.Height);
    DlgSettings.Maximized := WindowState = wsMaximized;
    DlgSettings.SplitterPos[spTopHorz] := RegView.Width / (ClientWidth / 100);
    DlgSettings.SplitterPos[spBottomHorz] := StackView.Width / (ClientWidth / 100);
    DlgSettings.SplitterPos[spCenterVert] := pnDumps.Height / (ClientHeight / 100);
    Settings.CpuViewDlgSettings := DlgSettings;
  end;
  Settings.Save(ConfigPath);
end;

function TfrmCpuView.ActiveDumpView: TDumpView;
begin
  Result := pcDumps.ActivePage.Controls[0] as TDumpView;
end;

function TfrmCpuView.ActiveViewIndex: Integer;
begin
  Result := -1;
  if AsmView.Focused then
    Exit(0);
  if RegView.Focused then
    Exit(1);
  if StackView.Focused then
    Exit(2);
  if ActiveDumpView.Focused then
    Exit(3);
end;

function TfrmCpuView.ToDpi(Value: Integer): Integer;
begin
  Result := MulDiv(Value, PixelsPerInch, 96);
end;

function TfrmCpuView.ToDefaultDpi(Value: Integer): Integer;
begin
  Result := MulDiv(Value, 96, PixelsPerInch);
end;

procedure TfrmCpuView.LockZOrder;
begin
  InterceptorOwner := Handle;
  InterceptorActive := True;
  tmpZOrderLock.Enabled := True;
end;

function TfrmCpuView.MeasureCanvas: TBitmap;
begin
  Result := TBitmap.Create;
  Result.Canvas.Font.PixelsPerInch := Font.PixelsPerInch;
  Result.Canvas.Font := Font;
end;

function TfrmCpuView.QweryAccessStr(AddrVA: UInt64): string;
var
  RegionData: TRegionData;
begin
  Result := 'No access';
  if DbgGate.Utils.QueryRegion(AddrVA, RegionData) then
  begin
    if (RegionData.Access <> []) and not (raProtect in RegionData.Access) then
    begin
      Result := '...';
      if raRead in RegionData.Access then
        Result[1] := 'R';
      if raWrite in RegionData.Access then
        Result[2] := 'W';
      if raExecute in RegionData.Access then
        Result[3] := 'E';
    end;
  end;
end;

procedure TfrmCpuView.UnlockZOrder;
begin
  tmpZOrderLock.Enabled := False;
  InterceptorActive := False;
end;

procedure TfrmCpuView.ActionRegModifyUpdate(Sender: TObject);
begin
  TAction(Sender).Visible :=
    (FDbgGate.DebugState = adsPaused) and
    (FContextRegister.RegID >= 0) and
    (TModifyAction(TAction(Sender).Tag) in FContextRegisterParam.ModifyActions);
end;

procedure TfrmCpuView.acViewFitColumnToBestSizeExecute(Sender: TObject);
begin
  case ActiveViewIndex of
    0: AsmView.FitColumnsToBestSize;
    1: RegView.FitColumnsToBestSize;
    2: StackView.FitColumnsToBestSize;
    3: ActiveDumpView.FitColumnsToBestSize;
  end;
end;

procedure TfrmCpuView.acViewGotoExecute(Sender: TObject);
var
  NewAddress: UInt64;
begin
  FQweryAddrViewerIndex := ActiveViewIndex;
  if (FQweryAddrViewerIndex < 0) or (FQweryAddrViewerIndex = 1) then Exit;
  NewAddress := 0;
  if QueryAddress('Go to Address', 'Address:', NewAddress, CheckAddressCallback) then
    case FQweryAddrViewerIndex of
      0:
      begin
        FCore.ShowDisasmAtAddr(NewAddress);
        AsmView.FocusOnAddress(NewAddress, ccmSelectRow);
      end;
      2:
      begin
        FCore.ShowStackAtAddr(NewAddress);
        StackView.FocusOnAddress(NewAddress, ccmSelectRow);
      end;
      3:
      begin
        FCore.ShowDumpAtAddr(NewAddress);
        ActiveDumpView.FocusOnAddress(NewAddress, ccmSetNewSelection);
      end;
    end;
end;

procedure TfrmCpuView.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  frmCpuView := nil;
  CloseAction := caFree;
end;

procedure TfrmCpuView.DumpViewSelectionChange(Sender: TObject);
begin
  FDumpSelectedValue := 0;
  ActiveDumpView.ReadDataAtSelStart(FDumpSelectedValue, FDbgGate.PointerSize);
  UpdateStatusBar;
end;

procedure TfrmCpuView.FormChangeBounds(Sender: TObject);
begin
  if WindowState = wsNormal then
    FLastBounds := BoundsRect;
end;

procedure TfrmCpuView.acShowInDumpUpdate(Sender: TObject);
begin
  if RegView.Focused then
  begin
    if not ((FContextRegister.RegID >= 0) and
      (maChange in FContextRegisterParam.ModifyActions) and
      (FContextRegisterParam.RegType = crtValue)) then
    begin
      TAction(Sender).Enabled := False;
      Exit;
    end;
  end;
  TAction(Sender).Enabled :=
    (DbgGate.DebugState = adsPaused) and
    Core.AddrInDump(ActiveViewerSelectedValue);
end;

procedure TfrmCpuView.acShowInNewDumpExecute(Sender: TObject);
var
  NewPage: TTabSheet;
  NewDump: TDumpView;
  AddrVA: Int64;
begin
  AddrVA := ActiveViewerSelectedValue;
  Inc(FDumpNameIdx);
  NewPage := pcDumps.AddTabSheet;
  NewPage.Caption := 'DUMP' + IntToStr(FDumpNameIdx);
  NewDump := TDumpView.Create(NewPage);
  NewDump.Parent := NewPage;
  NewDump.Align := alClient;
  NewDump.PopupMenu := pmDump;
  NewDump.OnSelectionChange := DumpViewSelectionChange;
  Core.DumpViewList.Add(NewDump);
  pcDumps.ActivePage := NewPage;
  Core.DumpViewList.ItemIndex := NewPage.PageIndex;
  InternalShowInDump(AddrVA);
end;

procedure TfrmCpuView.acShowInStackExecute(Sender: TObject);
begin
  Core.ShowStackAtAddr(ActiveViewerSelectedValue);
  ActiveControl := StackView;
end;

procedure TfrmCpuView.acShowInStackUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled :=
    (DbgGate.DebugState = adsPaused) and
    Core.AddrInStack(ActiveViewerSelectedValue);
end;

procedure TfrmCpuView.acStackFollowRSPExecute(Sender: TObject);
begin
  Core.ShowStackAtAddr(DbgGate.Context.StackPoint);
  ActiveControl := StackView;
end;

procedure TfrmCpuView.acTEAnsiExecute(Sender: TObject);
begin
  ActiveDumpView.Encoder.EncodeType :=
    TCharEncoderType(TAction(Sender).Tag);
end;

procedure TfrmCpuView.acTEAnsiUpdate(Sender: TObject);
begin
  TAction(Sender).Checked := ActiveDumpView.Encoder.EncodeType =
    TCharEncoderType(TAction(Sender).Tag);
end;

procedure TfrmCpuView.AsmViewSelectionChange(Sender: TObject);
begin
  FAsmViewSelectedAddr := AsmView.SelectedInstructionAddr;
  UpdateStatusBar;
end;

procedure TfrmCpuView.acShowInDumpExecute(Sender: TObject);
begin
  InternalShowInDump(ActiveViewerSelectedValue);
end;

procedure TfrmCpuView.acShowInAsmUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled :=
    (DbgGate.DebugState = adsPaused) and
    Core.AddrInAsm(ActiveViewerSelectedValue);
end;

procedure TfrmCpuView.acShowInAsmExecute(Sender: TObject);
begin
  Core.ShowDisasmAtAddr(ActiveViewerSelectedValue);
  ActiveControl := AsmView;
end;

procedure TfrmCpuView.acHighlightRegUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled :=
    (DbgGate.DebugState = adsPaused) and (FContextRegName <> '');
end;

procedure TfrmCpuView.acRegModifyDecExecute(Sender: TObject);
begin
  Dec(FContextRegValue);
  FCore.UpdateRegValue(FContextRegister.RegID, FContextRegValue);
end;

procedure TfrmCpuView.acRegModifyIncExecute(Sender: TObject);
begin
  Inc(FContextRegValue);
  FCore.UpdateRegValue(FContextRegister.RegID, FContextRegValue);
end;

procedure TfrmCpuView.acRegModifyNewValueExecute(Sender: TObject);
var
  ACount, I: Integer;
  SetValues: array of string;
begin
  {%H-}case FContextRegister.ValueType of
    crtValue, crtExtra:
      if QueryAddress('Edit ' + FContextRegName, 'New value:', FContextRegValue, CheckRegCallback) then
        FCore.UpdateRegValue(FContextRegister.RegID, FContextRegValue);
    crtEnumValue:
    begin
      ACount := FDbgGate.Context.RegQueryEnumValuesCount(FContextRegister.RegID);
      if ACount = 0 then Exit;
      SetLength(SetValues{%H-}, ACount);
      for I := 0 to ACount - 1 do
        SetValues[I] := FDbgGate.Context.RegQueryEnumString(FContextRegister.RegID, I);
      I := Integer(FContextRegValue);
      if QuerySetList('Edit ' + FContextRegName, 'New value:', SetValues, I) then
      begin
        FContextRegValue := UInt64(I);
        FCore.UpdateRegValue(FContextRegister.RegID, FContextRegValue);
      end;
    end;
  end;
end;

procedure TfrmCpuView.acRegModifyToggleExecute(Sender: TObject);
begin
  FContextRegValue := FContextRegValue xor 1;
  FCore.UpdateRegValue(FContextRegister.RegID, FContextRegValue);
end;

procedure TfrmCpuView.acRegModifyZeroExecute(Sender: TObject);
begin
  FContextRegValue := 0;
  FCore.UpdateRegValue(FContextRegister.RegID, FContextRegValue);
end;

procedure TfrmCpuView.acHighlightRegExecute(Sender: TObject);
begin
  if AsmView.HighlightReg = FContextRegName then
    AsmView.HighlightReg := ''
  else
    AsmView.HighlightReg := FContextRegName;
end;

procedure TfrmCpuView.acDbgRunTilReturnExecute(Sender: TObject);
begin
  LockZOrder;
  DbgGate.TraceTilReturn;
end;

procedure TfrmCpuView.acAsmShowSourceUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled :=
    (DbgGate.DebugState = adsPaused) and
    DbgGate.GetSourceLine(FAsmViewSelectedAddr, FSourcePath, FSourceLine) and
    (FSourceLine > 0);
end;

procedure TfrmCpuView.acAsmShowSourceExecute(Sender: TObject);
begin
  DebugBoss.JumpToUnitSource(FSourcePath, FSourceLine, False);
end;

procedure TfrmCpuView.acAsmReturnToIPExecute(Sender: TObject);
begin
  Core.ShowDisasmAtAddr(DbgGate.CurrentInstructionPoint);
end;

procedure TfrmCpuView.acAsmReturnToIPUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := (DbgGate.DebugState = adsPaused) and
    (DbgGate.CurrentInstructionPoint <> FAsmViewSelectedAddr);
end;

procedure TfrmCpuView.acAsmSetNewIPExecute(Sender: TObject);
begin
  Core.UpdateRegValue(DbgGate.Context.InstructonPointID, FAsmViewSelectedAddr);
end;

procedure TfrmCpuView.acDbgRunToExecute(Sender: TObject);
begin
  LockZOrder;
  DbgGate.TraceTo(FAsmViewSelectedAddr);
end;

procedure TfrmCpuView.acDbgRunToUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := (DbgGate.DebugState = adsPaused) and
    (FAsmViewSelectedAddr <> 0);
end;

procedure TfrmCpuView.acDbgStepInExecute(Sender: TObject);
begin
  LockZOrder;
  DbgGate.TraceIn;
end;

procedure TfrmCpuView.acDbgStepOutExecute(Sender: TObject);
begin
  LockZOrder;
  DbgGate.TraceOut;
end;

procedure TfrmCpuView.acDbgToggleBpExecute(Sender: TObject);
begin
  FAsmViewSelectedAddr := AsmView.SelectedInstructionAddr;
  DbgGate.ToggleBreakPoint(FAsmViewSelectedAddr);
end;

procedure TfrmCpuView.acDumpsCloseAllToTheRightExecute(Sender: TObject);
var
  I: Integer;
begin
  for I := pcDumps.PageCount - 1 downto pcDumps.PageIndex + 1 do
  begin
    Core.DumpViewList.Delete(I);
    pcDumps.Pages[I].Free;
  end;
end;

procedure TfrmCpuView.acDumpsCloseAllToTheRightUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := pcDumps.PageIndex < pcDumps.PageCount - 1;
end;

procedure TfrmCpuView.acDumpsClosePageExecute(Sender: TObject);
begin
  Core.DumpViewList.Delete(pcDumps.PageIndex);
  pcDumps.ActivePage.Free;
  Core.DumpViewList.ItemIndex := pcDumps.PageIndex;
end;

procedure TfrmCpuView.acDumpsClosePageUpdate(Sender: TObject);
begin
  TAction(Sender).Enabled := pcDumps.PageIndex > 0;
end;

end.

