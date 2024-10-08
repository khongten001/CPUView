﻿unit CpuView.Core;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

{$message 'asm Подсветка активных джампов'}
{$message 'asm Подсветка адреса перехода заливкой бэкграунда'}
{$message 'Калькулятор выражений. Пока два типа команд "? [eax+ebx]" и бряки "bp user32.MessageBoxW"'}
{$message 'Хинты по выделеной инструкции (через калькулятор выражений)'}
{$message 'asm добавить View Source'}
{$message 'asm добавить NEW EIP/RIP'}
{$message 'disasm не умеет обрабатывать RIP адресацию, поэтому теряется куча информации'}

{
Настройки:
отображать имена функций вместо адресов
показывать опкоды инструкций
показывать строки исходоного кода
}

uses
  {$IFDEF FPC}
  {$ELSE}
  Windows,
  {$ENDIF}
  Classes,
  Math,
  SysUtils,
  Controls,
  Generics.Collections,
  FWHexView.Common,
  FWHexView,
  CpuView.Common,
  CpuView.Viewers,
  CpuView.Settings,
  CpuView.Stream,
  {$IFDEF MSWINDOWS}
  CpuView.Stream.Windows,
  {$ENDIF}
  CpuView.DebugerGate,
  CpuView.CPUContext;

type
  TAsmLine = record
    AddrVA: Int64;
    DecodedStr, HintStr: string;
    Len: Integer;
    JmpTo: Int64;
    CallInstruction: Boolean;
  end;

  { TCpuViewCore }

  TCpuViewCore = class
  private const
    CacheVisibleRows = 150;
  private
    FAddrIndex: TDictionary<Int64, Integer>;
    FAsmView: TAsmView;
    FAsmSelStart, FAsmSelEnd: Int64;
    FAsmStream: TBufferedROStream;
    FCacheList: TList<TAsmLine>;
    FCacheListIndex: Integer;
    FDebugger: TAbstractDebugger;
    FDisassemblyStream: TBufferedROStream;
    FInvalidReg: TRegionData;
    FKnownFunctionAddrVA: TDictionary<Int64, string>;
    FLockSelChange: Boolean;
    FLastCtx: TCommonCpuContext;
    FRegView: TRegView;
    FShowCallFuncName: Boolean;
    FStackView: TStackView;
    FStackStream: TBufferedROStream;
    FDumpView: TDumpView;
    FDumpStream:  TBufferedROStream;
    FDumpLastAddrVA: Int64;
    FOldAsmScroll: TOnVerticalScrollEvent;
    FOldAsmSelect: TNotifyEvent;
    function GetAddrMode: TAddressMode;
    procedure OnAsmScroll(Sender: TObject; AStep: TScrollStepDirection);
    procedure OnAsmSelectionChange(Sender: TObject);
    procedure OnBreakPointsChange(Sender: TObject);
    procedure OnDebugerChage(Sender: TObject);
    procedure OnDebugerStateChange(Sender: TObject);
    procedure SetAsmView(const Value: TAsmView);
    procedure SetDebugger(const Value: TAbstractDebugger);
    procedure SetDumpView(const Value: TDumpView);
    procedure SetRegView(const Value: TRegView);
    procedure SetShowCallFuncName(AValue: Boolean);
    procedure SetStackView(const Value: TStackView);
  protected
    procedure BuildAsmWindow(AAddress: Int64);
    function GenerateCache(AAddress: Int64): Integer;
    function GetKnownFunctionAtAddr(AddrVA: Uint64): string;
    procedure LoadFromCache(AIndex: Integer);
    procedure RegViewQueryComment(Sender: TObject; AddrVA: UInt64;
      var AComment: string);
    procedure RefreshView(Forced: Boolean = False);
    procedure ResetCache;
    procedure StackViewQueryComment(Sender: TObject; AddrVA: UInt64;
      var AComment: string);
    procedure UpdateStreamsProcessID;
  public
    constructor Create;
    destructor Destroy; override;
    function AddrInAsm(AddrVA: Int64): Boolean;
    function AddrInDump(AddrVA: Int64): Boolean;
    function AddrInStack(AddrVA: Int64): Boolean;
    procedure ShowDisasmAtAddr(AddrVA: Int64);
    procedure ShowDumpAtAddr(AddrVA: Int64);
    procedure ShowStackAtAddr(AddrVA: Int64);
    function UpdateRegValue(RegID: Integer; ANewRegValue: UInt64): Boolean;
    property AsmView: TAsmView read FAsmView write SetAsmView;
    property Debugger: TAbstractDebugger read FDebugger write SetDebugger;
    property DumpView: TDumpView read FDumpView write SetDumpView;
    property RegView: TRegView read FRegView write SetRegView;
    property StackView: TStackView read FStackView write SetStackView;
  public
    property ShowCallFuncName: Boolean read FShowCallFuncName write SetShowCallFuncName;
  end;

implementation

const
  DisasmBuffSize = 4096;

{ TCpuViewCore }

function TCpuViewCore.AddrInStack(AddrVA: Int64): Boolean;
var
  StackLim: TStackLimit;
begin
  StackLim := FDebugger.ThreadStackLimit;
  Result := (AddrVA <= StackLim.Base) and (AddrVA >= StackLim.Limit);
end;

procedure TCpuViewCore.BuildAsmWindow(AAddress: Int64);
const
  MM_HIGHEST_USER_ADDRESS32 = $7FFEFFFF;
  MM_HIGHEST_USER_ADDRESS64 = $7FFFFFFF0000;
var
  CacheIndex: Integer;
  StreamSize: Int64;
begin
  if FAsmStream = nil then Exit;
  FAsmView.BeginUpdate;
  try
    if not FAddrIndex.TryGetValue(AAddress, CacheIndex) then
    begin
      CacheIndex := GenerateCache(AAddress);
      if CacheIndex >= 0 then
        AAddress := FCacheList[CacheIndex].AddrVA;
    end;
    if Assigned(FDebugger) and (FDebugger.PointerSize = 4) then
      StreamSize := MM_HIGHEST_USER_ADDRESS32
    else
      StreamSize := MM_HIGHEST_USER_ADDRESS64;
    FAsmStream.SetAddrWindow(AAddress, StreamSize);
    FAsmView.SetDataStream(FAsmStream, AAddress);
    LoadFromCache(CacheIndex);
  finally
    FAsmView.EndUpdate;
  end;
  if CacheIndex >= 0 then
  begin
    FAsmView.SelStart := Max(FAsmSelStart, FCacheList.List[CacheIndex].AddrVA);
    FAsmView.SelEnd := FAsmSelEnd;
  end;
end;

constructor TCpuViewCore.Create;
var
  RemoteStream: TRemoteStream;
begin
  FCacheList := TList<TAsmLine>.Create;
  FAddrIndex := TDictionary<Int64, Integer>.Create;
  RemoteStream := TRemoteStream.Create;
  FAsmStream := TBufferedROStream.Create(RemoteStream, soOwned);
  FAsmStream.BufferSize := DisasmBuffSize;
  RemoteStream := TRemoteStream.Create;
  FDisassemblyStream := TBufferedROStream.Create(RemoteStream, soOwned);
  FDisassemblyStream.BufferSize := DisasmBuffSize;
  RemoteStream := TRemoteStream.Create;
  FStackStream := TBufferedROStream.Create(RemoteStream, soOwned);
  RemoteStream := TRemoteStream.Create;
  FDumpStream := TBufferedROStream.Create(RemoteStream, soOwned);
  FKnownFunctionAddrVA := TDictionary<Int64, string>.Create;
  FShowCallFuncName := True;
end;

destructor TCpuViewCore.Destroy;
begin
  FCacheList.Free;
  FAddrIndex.Free;
  FAsmStream.Free;
  FDisassemblyStream.Free;
  FStackStream.Free;
  FDumpStream.Free;
  FKnownFunctionAddrVA.Free;
  inherited;
end;

function TCpuViewCore.AddrInAsm(AddrVA: Int64): Boolean;
begin
  Result :=
    Assigned(Debugger) and
    Assigned(AsmView) and
    Assigned(AsmView.DataStream) and
    (AddrVA > $10000) and
    (AddrVA < AsmView.StartAddress + AsmView.DataStream.Size - Debugger.PointerSize);
end;

function TCpuViewCore.AddrInDump(AddrVA: Int64): Boolean;
var
  RegData: TRegionData;
begin
  if FInvalidReg.RegionSize = 0 then
    FDumpStream.Stream.QueryRegion(AddrVA, FInvalidReg);
  if AddrVA < FInvalidReg.RegionSize then
    Result := False
  else
  begin
    Result := FDumpStream.Stream.QueryRegion(AddrVA, RegData);
    if Result then
      Result := (AddrVA > 0) and (AddrVA >= RegData.AllocationBase);
  end;
end;

function TCpuViewCore.GenerateCache(AAddress: Int64): Integer;

  procedure BuildCacheFromBuff(FromAddr: Int64; FromBuff: PByte;
    BufSize: Integer);
  var
    List: TList<TInstruction>;
    Inst: TInstruction;
    AsmLine: TAsmLine;
    SpaceIndex: Integer;
  begin
    List := Debugger.Disassembly(FromAddr, FromBuff, BufSize);
    try
      for Inst in List do
      begin
        AsmLine.AddrVA := FromAddr;
        if Inst.Len > BufSize then
          Break;
        AsmLine.DecodedStr := Inst.AsString;
        AsmLine.HintStr := Inst.Hint;
        AsmLine.Len := Inst.Len;
        AsmLine.JmpTo := Inst.JmpTo;
        AsmLine.CallInstruction := False;
        if ShowCallFuncName and (AsmLine.JmpTo <> 0) then
        begin
          if AsmLine.DecodedStr.StartsWith('CALL') then
          begin
            SpaceIndex := Pos(' ', AsmLine.HintStr);
            if SpaceIndex = 0 then
              SpaceIndex := Length(AsmLine.HintStr) + 1;
            AsmLine.DecodedStr := 'CALL ' + Copy(AsmLine.HintStr, 1, SpaceIndex - 1);
            AsmLine.HintStr := '';
            AsmLine.CallInstruction := True;
          end;
        end;
        FAddrIndex.TryAdd(FromAddr, FCacheList.Count);
        FCacheList.Add(AsmLine);
        Inc(FromAddr, AsmLine.Len);
        Dec(BufSize, AsmLine.Len);
      end;
    finally
      List.Free;
    end;

    if BufSize > 0 then
    begin
      AsmLine.DecodedStr := '???';
      AsmLine.Len := BufSize;
      AsmLine.JmpTo := 0;
      FAddrIndex.TryAdd(FromAddr, FCacheList.Count);
      FCacheList.Add(AsmLine);
    end;
  end;

var
  WindowAddr: Int64;
  Count, TopCacheSize: Integer;
  Buff: array of Byte;
  RegData: TRegionData;
begin
  Result := -1;
  if FDisassemblyStream = nil then Exit;
  ResetCache;
  FDisassemblyStream.Stream.QueryRegion(AAddress, RegData);
  WindowAddr := Max(AAddress - 1024, RegData.AllocationBase);
  TopCacheSize := AAddress - WindowAddr;

  FDisassemblyStream.SetAddrWindow(WindowAddr, DisasmBuffSize);
  SetLength(Buff, DisasmBuffSize);
  Count := FDisassemblyStream.Read(Buff[0], DisasmBuffSize);
  if Count > 0 then
  begin
    BuildCacheFromBuff(WindowAddr, @Buff[0], TopCacheSize);
    Result := FCacheList.Count;
    BuildCacheFromBuff(AAddress, @Buff[TopCacheSize], Count - TopCacheSize);
  end;
end;

function TCpuViewCore.GetKnownFunctionAtAddr(AddrVA: Uint64): string;
begin
  Result := '';
  if not FKnownFunctionAddrVA.TryGetValue(AddrVA, Result) then
  begin
    Result := Debugger.QuerySymbolAtAddr(AddrVA, qsName);
    // держим кэш на 1024 адреса, этого будет достаточно
    if FKnownFunctionAddrVA.Count > 1024 then
      FKnownFunctionAddrVA.Clear;
    FKnownFunctionAddrVA.Add(AddrVA, Result);
  end;
end;

procedure TCpuViewCore.LoadFromCache(AIndex: Integer);
var
  I: Integer;
  Line: TAsmLine;
begin
  FAsmView.BeginUpdate;
  try
    FAsmView.DataMap.Clear;
    FCacheListIndex := AIndex;
    if AIndex < 0 then Exit;
    Line := FCacheList.List[AIndex];
    if Line.Len = 0 then
      FAsmView.DataMap.AddComment(Line.AddrVA, Line.DecodedStr)
    else
      if Line.CallInstruction then
        FAsmView.DataMap.AddAsm(Line.AddrVA, Line.Len, Line.DecodedStr, '', Line.JmpTo, 5, Length(Line.DecodedStr) - 5)
      else
        FAsmView.DataMap.AddAsm(Line.AddrVA, Line.Len, Line.DecodedStr, Line.HintStr, Line.JmpTo, 0, 0);
    for I := 1 to Min(CacheVisibleRows, FCacheList.Count - AIndex - 1) do
    begin
      Line := FCacheList.List[I + AIndex];
      if Line.Len = 0 then
        FAsmView.DataMap.AddComment(Line.DecodedStr)
      else
        if Line.CallInstruction then
          FAsmView.DataMap.AddAsm(Line.Len, Line.DecodedStr, '', Line.JmpTo, 5, Length(Line.DecodedStr) - 5)
        else
          FAsmView.DataMap.AddAsm(Line.Len, Line.DecodedStr, Line.HintStr, Line.JmpTo, 0, 0);
    end;
  finally
    FAsmView.EndUpdate;
  end;
end;

procedure TCpuViewCore.RegViewQueryComment(Sender: TObject; AddrVA: UInt64;
  var AComment: string);
begin
  AComment := GetKnownFunctionAtAddr(AddrVA);
end;

function TCpuViewCore.GetAddrMode: TAddressMode;
begin
  case FDebugger.PointerSize of
    8: Result := am64bit;
    4: Result := am32bit;
    2: Result := am16bit;
  else
    Result := am8bit;
  end;
end;

procedure TCpuViewCore.OnAsmScroll(Sender: TObject;
  AStep: TScrollStepDirection);
var
  NewCacheIndex: Integer;
begin
  if FCacheList.Count = 0 then Exit;
  NewCacheIndex := FCacheListIndex;
  case AStep of
    ssdLineUp: Dec(NewCacheIndex);
    ssdWheelUp: Dec(NewCacheIndex, FAsmView.WheelMultiplyer);
    ssdPageUp: Dec(NewCacheIndex, FAsmView.VisibleRowCount);
    ssdLineDown: Inc(NewCacheIndex);
    ssdWheelDown: Inc(NewCacheIndex, FAsmView.WheelMultiplyer);
    ssdPageDown: Inc(NewCacheIndex, FAsmView.VisibleRowCount);
  end;
  if NewCacheIndex < 0 then
    NewCacheIndex := GenerateCache(FCacheList[0].AddrVA);
  if NewCacheIndex >= FCacheList.Count - CacheVisibleRows then
    NewCacheIndex := GenerateCache(FCacheList[FCacheList.Count - 1].AddrVA);
  FLockSelChange := True;
  if (NewCacheIndex >= 0) and (NewCacheIndex < FCacheList.Count) then
    BuildAsmWindow(FCacheList[NewCacheIndex].AddrVA)
  else
    FLockSelChange := False; // dbg...
  FLockSelChange := False;
  if Assigned(FOldAsmScroll) then
    FOldAsmScroll(Sender, AStep);
end;

procedure TCpuViewCore.OnAsmSelectionChange(Sender: TObject);
begin
  if FLockSelChange then Exit;
  FAsmSelStart := Min(FAsmView.SelStart, FAsmView.SelEnd);
  FAsmSelEnd := Max(FAsmView.SelStart, FAsmView.SelEnd);
  if Assigned(FOldAsmSelect) then
    FOldAsmSelect(Sender);
end;

procedure TCpuViewCore.OnBreakPointsChange(Sender: TObject);
var
  I: Integer;
  BP: TBasicBreakPoint;
begin
  AsmView.BreakPoints.Clear;
  for I := 0 to FDebugger.BreakPointList.Count - 1 do
  begin
    BP := FDebugger.BreakPointList[I];
    AsmView.BreakPoints.Add(Int64(BP.AddrVA), BP.Active);
  end;
  AsmView.Invalidate;
end;

procedure TCpuViewCore.OnDebugerChage(Sender: TObject);
begin
  RefreshView;
end;

procedure TCpuViewCore.OnDebugerStateChange(Sender: TObject);
begin
  case FDebugger.DebugState of
    adsStoped, adsStart:
      UpdateStreamsProcessID;
    adsPaused: RefreshView;
    adsRunning:
    begin
      {$message 'наверное нужно снимать стримы по аналогу с adsFinished'}
      if Assigned(FAsmView) then
      begin
        FAsmView.InstructionPoint := 0;
        FAsmView.CurrentIPIsActiveJmp := False;
        FAsmView.Invalidate;
      end;
      if Assigned(FStackView) then
      begin
        FStackView.Frames.Clear;
        FStackView.Invalidate;
      end;
    end;
    adsFinished:
    begin
      if Assigned(FAsmView) then
        FAsmView.SetDataStream(nil, 0);
      if Assigned(FRegView) then
        FRegView.Context := nil;
      if Assigned(FDumpView) then
        FDumpView.SetDataStream(nil, 0);
      if Assigned(FStackView) then
        FStackView.SetDataStream(nil, 0);
    end;
  end;
end;

procedure TCpuViewCore.RefreshView(Forced: Boolean);
var
  StackLim: TStackLimit;
begin
  if (FDebugger = nil) or not FDebugger.IsActive then Exit;
  FLastCtx := FDebugger.Context;
  if Assigned(FAsmView) then
  begin
    FAsmView.AddressMode := GetAddrMode;
    FAsmView.InstructionPoint := FDebugger.CurrentInstructionPoint;
    FAsmView.CurrentIPIsActiveJmp := FDebugger.IsActiveJmp;
    if Forced or not FAsmView.IsAddrVisible(FAsmView.InstructionPoint) then
      BuildAsmWindow(FAsmView.InstructionPoint);
    FAsmView.FocusOnAddress(FAsmView.InstructionPoint, ccmSelectRow);
  end;
  if Assigned(FRegView) then
    FRegView.Context := FLastCtx;
  if Assigned(FStackView) then
  begin
    StackLim := FDebugger.ThreadStackLimit;
    FDebugger.FillThreadStackFrames(StackLim, FLastCtx.StackPoint,
      FLastCtx.StackBase, FStackStream.Stream, FStackView.Frames);
    FStackStream.SetAddrWindow(StackLim.Limit, StackLim.Base - StackLim.Limit);
    FStackView.AddressMode := GetAddrMode;
    FStackView.SetDataStream(FStackStream, StackLim.Limit);
    FStackView.FramesUpdated;
    FStackView.FocusOnAddress(FLastCtx.StackPoint, ccmSelectRow);
  end;
  if Assigned(FDumpView) then
  begin
    FDumpView.AddressMode := GetAddrMode;
    ShowDumpAtAddr(FDumpLastAddrVA);
  end;
end;

procedure TCpuViewCore.ResetCache;
begin
  FAddrIndex.Clear;
  FCacheList.Clear;
  FAsmSelStart := 0;
  FAsmSelEnd := 0;
  FCacheListIndex := 0;
  FKnownFunctionAddrVA.Clear;
end;

procedure TCpuViewCore.StackViewQueryComment(Sender: TObject; AddrVA: UInt64;
  var AComment: string);
var
  AStackValue: Int64;
begin
  AStackValue := 0;
  if Debugger = nil then Exit;
  FStackStream.Stream.Position := AddrVA;
  FStackStream.Stream.ReadBuffer(AStackValue, Debugger.PointerSize);
  AComment := GetKnownFunctionAtAddr(AStackValue);
end;

procedure TCpuViewCore.SetAsmView(const Value: TAsmView);
begin
  if AsmView <> Value then
  begin
    FAsmView := Value;
    if Value = nil then Exit;
    FOldAsmSelect := FAsmView.OnSelectionChange;
    FAsmView.OnSelectionChange := OnAsmSelectionChange;
    FOldAsmScroll := FAsmView.OnVerticalScroll;
    FAsmView.OnVerticalScroll := OnAsmScroll;
    FAsmView.FitColumnsToBestSize;
    RefreshView;
  end;
end;

procedure TCpuViewCore.SetDebugger(const Value: TAbstractDebugger);
begin
  FDebugger := Value;
  if Assigned(Value) then
  begin
    FDebugger.OnChange := OnDebugerChage;
    FDebugger.OnStateChange := OnDebugerStateChange;
    FDebugger.OnBreakPointsChange := OnBreakPointsChange;
    FAsmStream.Stream.OnUpdated := FDebugger.UpdateRemoteStream;
    FDisassemblyStream.Stream.OnUpdated := FDebugger.UpdateRemoteStream;
    FDumpStream.Stream.OnUpdated := FDebugger.UpdateRemoteStream;
    FStackStream.Stream.OnUpdated := FDebugger.UpdateRemoteStream;
  end
  else
  begin
    FAsmStream.Stream.OnUpdated := nil;
    FDisassemblyStream.Stream.OnUpdated := nil;
    FDumpStream.Stream.OnUpdated := nil;
    FStackStream.Stream.OnUpdated := nil;
  end;
  UpdateStreamsProcessID;
end;

procedure TCpuViewCore.SetDumpView(const Value: TDumpView);
begin
  if DumpView <> Value then
  begin
    FDumpView := Value;
    if Value = nil then Exit;
    Value.FitColumnsToBestSize;
    RefreshView;
  end;
end;

procedure TCpuViewCore.SetRegView(const Value: TRegView);
begin
  if RegView <> Value then
  begin
    FRegView := Value;
    if Value = nil then Exit;
    FRegView.OnQueryComment := RegViewQueryComment;
    RefreshView;
  end;
end;

procedure TCpuViewCore.SetShowCallFuncName(AValue: Boolean);
begin
  if ShowCallFuncName <> AValue then
  begin
    FShowCallFuncName := AValue;
    ResetCache;
    RefreshView(True);
  end;
end;

procedure TCpuViewCore.SetStackView(const Value: TStackView);
begin
  if StackView <> Value then
  begin
    FStackView := Value;
    if Value = nil then Exit;
    Value.FitColumnsToBestSize;
    FStackView.OnQueryComment := StackViewQueryComment;
    RefreshView;
  end;
end;

procedure TCpuViewCore.ShowDisasmAtAddr(AddrVA: Int64);
begin
  if Assigned(FAsmView) then
  begin
    try
      FAsmSelStart := 0;
      FAsmSelEnd := 0;
      if not FAsmView.IsAddrVisible(AddrVA) then
        BuildAsmWindow(AddrVA);
      FAsmView.FocusOnAddress(AddrVA, ccmSelectRow);
    except
      RefreshView;
      raise;
    end;
  end;
end;

procedure TCpuViewCore.ShowDumpAtAddr(AddrVA: Int64);
var
  RegData: TRegionData;
begin
  if FDumpView = nil then Exit;
  if (AddrVA = 0) and Assigned(FDebugger) then
    AddrVA := FDebugger.CurrentInstructionPoint;
  {$message 'чо бум делать если память не доступна?'}
  if not FDumpStream.Stream.QueryRegion(AddrVA, RegData) then Exit;
  FDumpStream.SetAddrWindow(RegData.BaseAddr, RegData.RegionSize);
  FDumpView.SetDataStream(FDumpStream, RegData.BaseAddr);
  FDumpView.FocusOnAddress(AddrVA, ccmSelectRow);
  FDumpLastAddrVA := AddrVA;
end;

procedure TCpuViewCore.ShowStackAtAddr(AddrVA: Int64);
begin
  if Assigned(FStackView) then
    FStackView.FocusOnAddress(AddrVA, ccmSelectRow);
end;

function TCpuViewCore.UpdateRegValue(RegID: Integer;
  ANewRegValue: UInt64): Boolean;
begin
  Result := False;
  if Assigned(FDebugger) and FDebugger.IsActive then
  begin
    Result := FDebugger.UpdateRegValue(RegID, ANewRegValue);
    if Result and Assigned(FRegView) then
      FRegView.RefreshSelected;
  end;
end;

procedure TCpuViewCore.UpdateStreamsProcessID;
begin
  if Assigned(FDebugger) and FDebugger.IsActive then
  begin
    FAsmStream.Stream.ProcessID := FDebugger.ProcessID;
    FDisassemblyStream.Stream.ProcessID := FDebugger.ProcessID;
    FDumpStream.Stream.ProcessID := FDebugger.ProcessID;
    FStackStream.Stream.ProcessID := FDebugger.ProcessID;
  end
  else
  begin
    FAsmStream.Stream.ProcessID := 0;
    FDisassemblyStream.Stream.ProcessID := 0;
    FDumpStream.Stream.ProcessID := 0;
    FStackStream.Stream.ProcessID := 0;
    ResetCache;
  end;
end;

end.
