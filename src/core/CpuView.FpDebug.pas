﻿unit CpuView.FpDebug;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

{$DEFINE DEBUG_LOG}

interface

{$I CpuViewCfg.inc}

uses
  LCLType,
  LCLIntf,

  SysUtils,
  Classes,
  Forms,
  Generics.Collections,

  // IdeDebugger
  Debugger,
  BaseDebugManager,

  // DebuggerIntf
  DbgIntfDebuggerBase,
  DbgIntfMiscClasses,

  // IDEIntf
  LazIDEIntf,
  IDEWindowIntf,
  SrcEditorIntf,

  // LazDebuggerIntf
  LazDebuggerIntfBaseTypes,

  // LazDebuggerFp
  FpDebugDebugger,
  FpDebugDebuggerBase,
  FpDebugDebuggerWorkThreads,
  FpDebugDebuggerUtils,

  // fpdebug
  FPDbgController,
  FpDbgClasses,
  FpDbgInfo,
  FpDbgUtil,
  {$IFDEF MSWINDOWS}
  FpDbgWinClasses,
  {$ENDIF}

  // LazUtils
  LazLoggerBase,

  // CodeTools
  CodeCache,
  CodeToolManager,

  {$IFDEF MSWINDOWS}
  CpuView.Windows,
  {$ENDIF}
  {$IFDEF LINUX}
  CpuView.Linux,
  {$ENDIF}

  CpuView.Common,
  CpuView.Stream,
  CpuView.CPUContext,
  CpuView.DebugerGate;

type

  TCpuViewDebugGate = class;

  { TThreadWorkerMaskBreakpoints }

  TThreadWorkerMaskBreakpoints = class(TFpDbgDebggerThreadWorkerItem)
  private
    FBuff: PByte;
    FAddrVA: UInt64;
    FSize: Int64;
  protected
    procedure DoExecute; override;
  public
    constructor Create(ADebugger: TFpDebugDebuggerBase; pBuff: PByte;
      AAddrVA: UInt64; ASize: Int64);
  end;

  { TThreadWorkerChangeThreadContext }

  TThreadWorkerChangeThreadContext = class(TFpDbgDebggerThreadWorkerItem)
  private
    FDbgIntf: TCpuViewDebugGate;
  protected
    procedure DoExecute; override;
  public
    constructor Create(ADbgIntf: TCpuViewDebugGate);
  end;

  { TCpuViewDebugGate }

  TCpuViewDebugGate = class(TAbstractDebugger)
  private
    FBreakPoints: TIDEBreakPoints;
    FBreakpointsNotification: TIDEBreakPointsNotification;
    FDebugger: TDebuggerIntf;
    FDbgController: TDbgController;
    FProcess: TDbgProcess;
    FRegisterInDebugBoss, FRegisterDestroyNotification: Boolean;
    FSupportStream: TRemoteStream;
    FPreviosSrcLine: Integer;
    FPreviosSrcFuncName, FPreviosSrcFileName: string;
    FLockTimeOut: Int64;
    FSnapshotManager:  TSnapshotManager;
    FTemporaryIP: TDictionary<Integer, UInt64>;
    FThreadsMonitor: TIdeThreadsMonitor;
    FThreadsNotification: TThreadsNotification;
    procedure BreakPointChanged(const {%H-}ASender: TIDEBreakPoints;
      const {%H-}ABreakpoint: TIDEBreakPoint);
    procedure CallStackCtxChanged(Sender: TObject);
    function CurrentInstruction: TInstruction;
    procedure DoDebuggerDestroy(Sender: TObject);
    function FormatAsmCode(const Value: string; var AnInfo: TDbgInstInfo;
        CodeSize: Integer): string;
    function IsMainThreadId: Boolean;
    procedure OnActivateIDEForm(Sender: TObject; var AHandled: Boolean);
    procedure OnActivateSourceEditor(Sender: TObject; var AHandled: Boolean);
    procedure OnState(ADebugger: TDebuggerIntf; AOldState: TDBGState);
    procedure Reset;
    procedure StopAllWorkers;
    procedure UpdateDebugger(ADebugger: TDebuggerIntf);
  protected
    function GetUtilsClass: TCommonAbstractUtilsClass; override;
  public
    constructor Create(ACpuViewForm: TCustomForm); override;
    destructor Destroy; override;
    function CommandAvailable(ACommand: TInterfaceDebugCommand): Boolean; override;
    function CurrentInstructionPoint: UInt64; override;
    function DebugState: TAbstractDebugState; override;
    function Disassembly(AddrVA: Int64; pBuff: PByte; nSize: Integer): TList<TInstruction>; override;
    function IsActive: Boolean; override;
    function IsActiveJmp: Boolean; override;
    function GetSourceLine(AddrVA: Int64; out ASourcePath: string;
      out ASourceLine: Integer): Boolean; override;
    procedure Pause; override;
    function PointerSize: Integer; override;
    function ProcessID: Cardinal; override;
    function QuerySymbolAtAddr(AddrVA: Int64; AParam: TQuerySymbol): string; override;
    function ReadMemory(AddrVA: Int64; var Buff; Size: Integer): Boolean; override;
    procedure Run; override;
    procedure Stop; override;
    procedure SetNewIP(AddrVA: UInt64); override;
    procedure ToggleBreakPoint(AddrVA: UInt64); override;
    function ThreadStackLimit: TStackLimit; override;
    function ThreadID: Cardinal; override;
    procedure TraceIn; override;
    procedure TraceOut; override;
    procedure TraceTilReturn; override;
    procedure TraceTo(AddrVA: Int64); override;
    function UpdateRegValue(RegID: Integer; ANewRegValue: UInt64): Boolean; override;
    procedure UpdateRemoteStream(pBuff: PByte; AAddrVA: UInt64; ASize: Int64); override;
    property Debugger: TDebuggerIntf read FDebugger;
    property DbgController: TDbgController read FDbgController;
  end;

implementation

type
  TDbgProcessAccess = class(TDbgProcess);
  TFpDebugDebuggerAccess = class(TFpDebugDebugger);
  {$IFDEF MSWINDOWS}
  TDebugThreadAcces = class(TDbgWinThread);
  {$ENDIF}

{ TThreadWorkerMaskBreakpoints }

procedure TThreadWorkerMaskBreakpoints.DoExecute;
begin
  if Assigned(FDebugger.DbgController) then
    TDbgProcessAccess(FDebugger.DbgController.CurrentProcess).MaskBreakpointsInReadData(FAddrVA, FSize, FBuff^);
end;

constructor TThreadWorkerMaskBreakpoints.Create(ADebugger: TFpDebugDebuggerBase;
  pBuff: PByte; AAddrVA: UInt64; ASize: Int64);
begin
  inherited Create(ADebugger, twpContinue);
  FAddrVA := AAddrVA;
  FBuff := pBuff;
  FSize := ASize;
end;

{ TThreadWorkerChangeThreadContext }

procedure TThreadWorkerChangeThreadContext.DoExecute;
var
  DebugThread: TDbgThread;
begin
  FDbgIntf.DbgController.CurrentProcess.GetThread(FDbgIntf.ThreadID, DebugThread);
  if DebugThread <> nil then
    DebugThread.BeforeContinue;
end;

constructor TThreadWorkerChangeThreadContext.Create(ADbgIntf: TCpuViewDebugGate);
begin
  inherited Create((ADbgIntf.Debugger as TFpDebugDebugger), twpContinue);
  FDbgIntf := ADbgIntf;
end;

{ TCpuViewDebugGate }

procedure TCpuViewDebugGate.BreakPointChanged(const ASender: TIDEBreakPoints;
  const ABreakpoint: TIDEBreakPoint);
var
  I, A: Integer;
  BP: TIDEBreakPoint;
  BPList: TDBGPtrArray;
  BBP: TBasicBreakPoint;
  DuplicateController: TDictionary<UInt64, Boolean>;
begin
  BreakPointList.Clear;
  if FBreakPoints = nil then Exit;
  if FProcess = nil then Exit;
  DuplicateController := TDictionary<UInt64, Boolean>.Create;
  try
    for I := 0 to FBreakPoints.Count - 1 do
    begin
      // вот тут идут дубли - надо их контролировать!!!
      // this is where the duplicates come in - we need to control them!!!!
      BP := FBreakPoints.Items[I];
      case BP.Kind of
        bpkAddress:
        begin
          BBP.AddrVA := BP.Address;
          BBP.Active := BP.Enabled;
          if DuplicateController.TryAdd(BBP.AddrVA, BBP.Active) then
            BreakPointList.Add(BBP);
        end;
        bpkSource:
        begin
          BPList := nil;
          if not FProcess.GetLineAddresses(BP.Source, BP.Line, BPList) then
            Continue;
          for A := 0 to Length(BPList) - 1 do
          begin
            BBP.AddrVA := BPList[A];
            BBP.Active := BP.Enabled;
            if DuplicateController.TryAdd(BBP.AddrVA, BBP.Active) then
              BreakPointList.Add(BBP);
          end;
        end
      else
        Continue;
      end;
    end;
  finally
    DuplicateController.Free;
  end;

  DoBreakPointsChange;
end;

procedure TCpuViewDebugGate.CallStackCtxChanged(Sender: TObject);
begin
  UpdateContext;
  DoStateChange;
end;

function TCpuViewDebugGate.CurrentInstruction: TInstruction;
var
  CurrentIP: Int64;
  ALen, I: Integer;
  InstructionOpcode: array of Byte;
  List: TList<TInstruction>;
begin
  FillChar(Result, SizeOf(Result), 0);
  CurrentIP := CurrentInstructionPoint;
  SetLength(InstructionOpcode, 16);
  FSupportStream.Position := CurrentIP;
  ALen := FSupportStream.Read(InstructionOpcode[0], 16);
  if ALen = 0 then Exit;
  List := Disassembly(CurrentIP, @InstructionOpcode[0], 16);
  try
    for I := 0 to List.Count - 1 do
      if List.List[I].Len > 0 then
      begin
        Result := List[I];
        Break;
      end;
  finally
    List.Free;
  end;
end;

procedure TCpuViewDebugGate.DoDebuggerDestroy(Sender: TObject);
begin
  Reset;
end;

function TCpuViewDebugGate.FormatAsmCode(const Value: string;
  var AnInfo: TDbgInstInfo; CodeSize: Integer): string;
var
  I, Len, Cursor: Integer;
  NumberMode, SignRip, RipMode: Boolean;

  function IsNumber: Boolean;
  begin
    Result := CharInSet(Value[I], ['1'..'9', 'a'..'f', 'A'..'F']);
  end;

  procedure AppendChar(var AResult: string);
  begin
    // upcase
    if CharInSet(Value[I], ['a'..'z']) then
      AResult[Cursor] := Char(Byte(Value[I]) - Byte('a') + Byte('A'))
    else
      AResult[Cursor] := Value[I];
    Inc(Cursor);
    Inc(I);
  end;

  procedure MoveNumber(var AResult: string);
  var
    Digit: Byte;
  begin
    if not IsNumber then
    begin
      AResult[Cursor] := '0';
      Inc(Cursor);
      Exit;
    end;
    while IsNumber do
    begin
      if RipMode then
      begin
        Digit := Byte(Value[I]);
        if Byte(Digit - Byte('0')) <= 9 then
          Dec(Digit, Byte('0'))
        else if Byte(Digit - Byte('a')) < 6 then
          Dec(Digit, Byte('a') - 10)
        else if Byte(Digit - Byte('A')) < 6 then
          Dec(Digit, Byte('A') - 10)
        else
          Digit := 0; // impossible situation, just for debugging
        AnInfo.InstrTargetOffs := (AnInfo.InstrTargetOffs shl 4) or Digit;
      end;
      AppendChar(AResult);
    end;
    if RipMode then
    begin
      if SignRip then
        AnInfo.InstrTargetOffs := -AnInfo.InstrTargetOffs;
      Inc(AnInfo.InstrTargetOffs, CodeSize);
    end;
  end;


begin
  Len := Length(Value);
  SetLength(Result, Len shl 1);
  I := 1;
  Cursor := 1;
  NumberMode := False;
  while I <= Len do
  begin

    // trim lead zeros
    if NumberMode then
    begin
      if Value[I] = '0' then
      begin
        Inc(I);
        Continue;
      end;
      NumberMode := False;
      MoveNumber(Result);
      Continue;
    end;

    // detect number start
    if Value[I] = '$' then
    begin
      // detect RIP
      if (AnInfo.InstrTargetOffs = 0) and (Cursor > 5) then
      begin
        RipMode :=
          (Result[Cursor - 4] = 'R') and
          (Result[Cursor - 3] = 'I') and
          (Result[Cursor - 2] = 'P');
        SignRip := Result[Cursor - 1] = '-';
      end
      else
        RipMode := False;
      Result[Cursor] := '0';
      Inc(Cursor);
      Result[Cursor] := 'x';
      Inc(Cursor);
      Inc(I);
      NumberMode := True;
      Continue;
    end;

    AppendChar(Result);
  end;

  if NumberMode then
    MoveNumber(Result);

  SetLength(Result, Cursor - 1);
end;

function TCpuViewDebugGate.IsMainThreadId: Boolean;
begin
  if Assigned(FDbgController) then
    Result := ThreadID = FDbgController.CurrentProcess.ThreadID
  else
    Result := True;
end;

procedure TCpuViewDebugGate.OnActivateIDEForm(Sender: TObject;
  var AHandled: Boolean);
var
  AFormClassName: string;
begin
  if not (Sender is TCustomForm) then Exit;
  AFormClassName := TCustomForm(Sender).ClassName;
  AHandled :=
    AnsiSameText('TAssemblerDlg', AFormClassName) or
    AnsiSameText('TSourceNotebook', AFormClassName);
end;

procedure TCpuViewDebugGate.OnActivateSourceEditor(Sender: TObject;
  var AHandled: Boolean);
begin
  AHandled := Assigned(FDebugger) and (FDebugger.State = dsPause) and
    CpuViewForm.Visible and CpuViewForm.Active;
end;

procedure TCpuViewDebugGate.OnState(ADebugger: TDebuggerIntf;
  AOldState: TDBGState);
begin
  {$IFDEF DEBUG_LOG}
  DebugLn(['State: ', dbgs(ADebugger.State)]);
  {$ENDIF}
  if ADebugger.State in [dsStop, dsDestroying, dsError, dsNone] then
    Reset
  else
  begin
    FTemporaryIP.Clear;
    if FDebugger <> ADebugger then
      UpdateDebugger(ADebugger)
    else
      UpdateContext;
  end;
  DoStateChange;
end;

procedure TCpuViewDebugGate.Reset;
begin
  FTemporaryIP.Clear;
  if Assigned(FDebugger) then
  begin
    //FDebugger.OnActivateSourceEditor := nil;
    if FRegisterDestroyNotification then
    begin
      FDebugger.RemoveNotifyEvent(dnrDestroy, DoDebuggerDestroy);
      FRegisterDestroyNotification := False;
    end;
    FDebugger := nil;
  end;
  {$message 'Bad approach, utilitarianism should stand alone'}
  {$IFDEF LINUX}
  LinuxDebugger := nil;
  {$ENDIF}
  FDbgController := nil;
  FProcess := nil;
  Utils.ProcessID := 0;
  //if Assigned(IDEWindowCreators) then
    //IDEWindowCreators.OnActivateIDEForm := nil;
  if Assigned(FBreakPoints) then
  begin
    FBreakPoints.RemoveNotification(FBreakpointsNotification);
    FBreakPoints := nil;
  end;
  if Assigned(FThreadsMonitor) then
  begin
    FThreadsMonitor.RemoveNotification(FThreadsNotification);
    FThreadsMonitor := nil;
  end;
  FSnapshotManager := nil;
end;

procedure TCpuViewDebugGate.StopAllWorkers;
begin
  if Assigned(FDebugger) then
    TFpDebugDebuggerAccess(FDebugger).StopAllWorkers(True)
end;

procedure TCpuViewDebugGate.UpdateDebugger(ADebugger: TDebuggerIntf);
begin
  FDebugger := ADebugger;
  if Assigned(FDebugger) and (FDebugger is TFpDebugDebugger) then
  begin
    {$IFDEF LINUX}
    LinuxDebugger := TFpDebugDebugger(FDebugger);
    {$ENDIF}
    FDbgController := TFpDebugDebugger(FDebugger).DbgController;
    FProcess := FDbgController.CurrentProcess;
    if Assigned(FProcess) and not FProcess.GotExitProcess then
    begin
      FDebugger.AddNotifyEvent(dnrDestroy, DoDebuggerDestroy);
      FRegisterDestroyNotification := True;
      //if Assigned(IDEWindowCreators) then
      //  IDEWindowCreators.OnActivateIDEForm := OnActivateIDEForm;
      //FDebugger.OnActivateSourceEditor := OnActivateSourceEditor;
      if Assigned(DebugBoss) then
      begin
        if Assigned(DebugBoss.BreakPoints) then
        begin
          FBreakPoints := DebugBoss.BreakPoints;
          FBreakPoints.AddNotification(FBreakpointsNotification);
          BreakPointChanged(FBreakPoints, nil);
        end;
        if Assigned(DebugBoss.Threads) then
        begin
          FThreadsMonitor := DebugBoss.Threads;
          FThreadsMonitor.AddNotification(FThreadsNotification);
        end;
        if Assigned(DebugBoss.Snapshots) then
          FSnapshotManager := DebugBoss.Snapshots;
      end;
      Utils.ProcessID := ProcessID;
      if ADebugger.State = dsPause then
        UpdateContext;
      Exit;
    end;
  end;
  Reset;
end;

function TCpuViewDebugGate.GetUtilsClass: TCommonAbstractUtilsClass;
begin
  Result := TCommonUtils;
end;

constructor TCpuViewDebugGate.Create(ACpuViewForm: TCustomForm);
begin
  inherited;
  FTemporaryIP := TDictionary<Integer, UInt64>.Create;
  FSupportStream := TRemoteStream.Create(Utils);
  FSupportStream.OnUpdated := UpdateRemoteStream;
  FBreakpointsNotification := TIDEBreakPointsNotification.Create;
  FBreakpointsNotification.AddReference;
  FBreakpointsNotification.OnAdd := BreakPointChanged;
  FBreakpointsNotification.OnUpdate := BreakPointChanged;
  FBreakpointsNotification.OnRemove := BreakPointChanged;
  FThreadsNotification := TThreadsNotification.Create;
  FThreadsNotification.AddReference;
  FThreadsNotification.OnChange := CallStackCtxChanged;
  if Assigned(DebugBoss) then
  begin
    DebugBoss.RegisterStateChangeHandler(OnState);
    FRegisterInDebugBoss := True;
    UpdateDebugger(DebugBoss.Snapshots.Debugger);
  end;
end;

destructor TCpuViewDebugGate.Destroy;
begin
  if FRegisterInDebugBoss and Assigned(DebugBoss) then
    DebugBoss.UnregisterStateChangeHandler(OnState);
  Reset;
  FSupportStream.Free;
  FBreakpointsNotification.OnAdd := nil;
  FBreakpointsNotification.OnRemove := nil;
  FBreakpointsNotification.OnUpdate := nil;
  ReleaseRefAndNil(FBreakpointsNotification);
  FThreadsNotification.OnChange := nil;
  ReleaseRefAndNil(FThreadsNotification);
  FTemporaryIP.Free;
  inherited Destroy;
end;

function TCpuViewDebugGate.CommandAvailable(ACommand: TInterfaceDebugCommand
  ): Boolean;
const
  RemapCmd: array [idcRun..idcStepOut] of TDBGCommand = (
    dcRun, dcRunTo, dcPause, dcStepInto, dcStepOver, dcStepOut
  );
var
  AvailableCommands: TDBGCommands;
begin
  Result := False;
  if FDebugger = nil then Exit;
  if ACommand = idcBreakPoint then
    Exit(DebugState = adsPaused);
  if FDebugger.State = dsStop then
    AvailableCommands := FDebugger.SupportedCommandsFor(dsStop)
  else
    AvailableCommands := FDebugger.Commands;
  Result := RemapCmd[ACommand] in AvailableCommands;
end;

function TCpuViewDebugGate.CurrentInstructionPoint: UInt64;
var
  AEntry: TThreadEntry;
begin
  Result := 0;
  if Assigned(FDebugger) and (FDebugger.State = dsPause) then
  begin
    if not FTemporaryIP.TryGetValue(ThreadID, Result) then
    begin
      if IsMainThreadId then
        Result := FDebugger.GetLocation.Address
      else
        if Assigned(FThreadsMonitor) then
        begin
          AEntry := FThreadsMonitor.Threads.EntryById[ThreadID];
          if Assigned(AEntry) then
            Result := AEntry.TopFrame.Address;
        end;
    end;
  end;
end;

function TCpuViewDebugGate.DebugState: TAbstractDebugState;
begin
  if Assigned(FDebugger) then
  begin
    case FDebugger.State of
      dsInit: Result := adsStart;
      dsPause: Result := adsPaused;
      dsRun: Result := adsRunning;
      {$message 'for debug'}
      dsInternalPause: Result := adsRunning;
      dsStop: Result := adsStoped;
    else
      Result := adsFinished;
    end;
  end
  else
    Result := adsFinished;
end;

function TCpuViewDebugGate.Disassembly(AddrVA: Int64; pBuff: PByte;
  nSize: Integer): TList<TInstruction>;
var
  Disasm: TDbgAsmDecoder;
  Process: TDbgProcess;
  Instruction: TInstruction;
  PrevVA: Int64;
  ACodeBytes, ACode, RipSimbol: string;
  AnInfo: TDbgInstInfo;
  ExternalAddr, RipAddr: Int64;
begin
  Result := TList<TInstruction>.Create;
  if FDbgController = nil then Exit;
  Process := FDbgController.CurrentProcess;
  if Process = nil then Exit;
  Disasm := Process.Disassembler;
  if Disasm = nil then Exit;
  while nSize > 0 do
  begin
    Instruction.AsString := QuerySymbolAtAddr(AddrVA, qsSourceLine);
    if Instruction.AsString <> '' then
    begin
      Instruction.AddrVA := AddrVA;
      Instruction.Hint := '';
      Instruction.JmpTo := 0;
      Instruction.Len := 0;
      Result.Add(Instruction);
    end;
    PrevVA := {%H-}Int64(pBuff);
    Disasm.Disassemble(pBuff, ACodeBytes, ACode, AnInfo);
    Instruction.AddrVA := AddrVA;
    Instruction.AsString := FormatAsmCode(ACode, AnInfo, Length(ACodeBytes) shr 1);
    ExternalAddr := AddrVA + AnInfo.InstrTargetOffs;

    if AnInfo.InstrTargetOffs <> 0 then
    begin
      Instruction.Hint := QuerySymbolAtAddr(ExternalAddr, qsName);
      if Instruction.Hint = '' then
        Instruction.Hint := '0x' + IntToHex(ExternalAddr, 1);
    end
    else
      Instruction.Hint := '';

    if AnInfo.InstrType = itJump then
      Instruction.JmpTo := ExternalAddr
    else
    begin
      Instruction.JmpTo := 0;
      if AnInfo.InstrTargetOffs <> 0 then
      begin
        FSupportStream.Position := ExternalAddr;
        RipAddr := 0;
        RipSimbol := '';
        FSupportStream.Read(RipAddr, PointerSize);
        if RipAddr <> 0 then
          RipSimbol := QuerySymbolAtAddr(RipAddr, qsName);
        if RipSimbol = '' then
          Instruction.Hint := Format('RIP (0x%.1x) %s', [ExternalAddr, Instruction.Hint])
        else
          Instruction.Hint := Format('RIP (0x%.1x -> 0x%.1x) %s', [ExternalAddr, RipAddr, RipSimbol]);
      end;
    end;

    Instruction.Len := {%H-}Int64(pBuff) - PrevVA;
    Inc(AddrVA, Instruction.Len);
    Dec(nSize, Instruction.Len);
    if nSize >= 0 then
      Result.Add(Instruction);
  end;
end;

function TCpuViewDebugGate.IsActive: Boolean;
begin
  Result := not (DebugState in [adsStoped, adsFinished]);
end;

function TCpuViewDebugGate.IsActiveJmp: Boolean;
var
  Inst: TInstruction;
begin
  Result := False;
  Inst := CurrentInstruction;
  if Inst.JmpTo = 0 then Exit;
  Result := Context.IsActiveJump(Inst.AsString);
end;

function TCpuViewDebugGate.GetSourceLine(AddrVA: Int64; out
  ASourcePath: string; out ASourceLine: Integer): Boolean;
var
  Sym: TFpSymbol;
  PasSource: TCodeBuffer;
  Editor: TSourceEditorInterface;
begin
  ASourcePath := '';
  ASourceLine := 0;
  if FDbgController = nil then Exit;
  Sym := FDbgController.CurrentProcess.FindProcSymbol(AddrVA);
  if Sym = nil then Exit;
  try
    ASourcePath := Sym.FileName;
    ASourceLine := Sym.Line;
  finally
    Sym.ReleaseReference;
  end;
  if ASourceLine <= 0 then Exit;
  if DebugBoss.GetFullFilename(ASourcePath, False) then
  begin
    PasSource := CodeToolBoss.LoadFile(ASourcePath, True, False);
    if Assigned(PasSource) then
    begin
      Editor := SourceEditorManagerIntf.SourceEditorIntfWithFilename(ASourcePath);
      if Editor <> nil then
        ASourceLine := Editor.DebugToSourceLine(ASourceLine);
      Result := ASourceLine > 0;
    end;
  end;
end;

procedure TCpuViewDebugGate.Pause;
begin
  FDebugger.Pause;
end;

function TCpuViewDebugGate.PointerSize: Integer;
begin
  if Assigned(FDbgController) then
    Result := FDbgController.CurrentProcess.PointerSize
  else
    Result := 0;
end;

function TCpuViewDebugGate.ProcessID: Cardinal;
begin
  if Assigned(FDbgController) then
    Result := FDbgController.CurrentProcess.ProcessID
  else
    Result := 0;
end;

function TCpuViewDebugGate.QuerySymbolAtAddr(AddrVA: Int64; AParam: TQuerySymbol): string;
var
  Sym: TFpSymbol;
  PasSource: TCodeBuffer;
  Editor: TSourceEditorInterface;
  ASrcLineNumber: Cardinal;
  ASrcFileName: string;
begin
  Result := '';
  if FDbgController = nil then Exit;
  Sym := FDbgController.CurrentProcess.FindProcSymbol(AddrVA);
  if Sym = nil then Exit;
  try

    if (AParam = qsName) or (Sym.Line <= 0) then
    begin
      Result := Sym.Name;
      if Result = '' then Exit;
      if Sym.Parent <> nil then
        Result := Sym.Parent.Name + '.' + Result;
      if Sym.Line > 0 then
        Result := Format('%s %s:%d', [
          Result, ExtractFileName(Sym.FileName), Sym.Line])
      else
      begin
        if AParam <> qsName then
        begin
          if FPreviosSrcFuncName = Result then
          begin
            Result := '';
            Exit;
          end;
          FPreviosSrcFuncName := Result;
        end;
        if AddrVA <> Sym.Address.Address then
          Result := Format('%s+%d', [Result, AddrVA - Sym.Address.Address]);
      end;
      Exit;
    end;

    ASrcFileName := Sym.FileName;
    ASrcLineNumber := Sym.Line;
    if (FPreviosSrcLine = ASrcLineNumber) and (FPreviosSrcFileName = ASrcFileName) then
      Exit;
    FPreviosSrcLine := ASrcLineNumber;
    FPreviosSrcFileName := ASrcFileName;
    FPreviosSrcFuncName := Sym.Name;

    if DebugBoss.GetFullFilename(ASrcFileName, False) then
    begin
      PasSource := CodeToolBoss.LoadFile(ASrcFileName, True, False);
      if Assigned(PasSource) then
      begin
        Editor := SourceEditorManagerIntf.SourceEditorIntfWithFilename(ASrcFileName);
        if Editor <> nil then
          ASrcLineNumber := Editor.DebugToSourceLine(ASrcLineNumber);
        Result := Format('%s:%d %s', [
          ExtractFileName(ASrcFileName), ASrcLineNumber,
          Trim(PasSource.GetLine(ASrcLineNumber - 1, False))]);
      end;
    end;
  finally
    Sym.ReleaseReference;
  end;
end;

function TCpuViewDebugGate.ReadMemory(AddrVA: Int64; var Buff; Size: Integer
  ): Boolean;
begin
  FSupportStream.Position := AddrVA;
  Result := FSupportStream.Read(Buff, Size) = Size;
end;

procedure TCpuViewDebugGate.Run;
begin
  FDebugger.Run;
end;

procedure TCpuViewDebugGate.Stop;
begin
  FDebugger.Stop;
end;

procedure TCpuViewDebugGate.SetNewIP(AddrVA: UInt64);
begin
  UpdateRegValue(Context.InstructonPointID, AddrVA);
end;

procedure TCpuViewDebugGate.ToggleBreakPoint(AddrVA: UInt64);
var
  Sym: TFpSymbol;
  Bp: TIDEBreakPoint;
  AFileName: string;
  I, ALine: Integer;
  BPList: TDBGPtrArray;
  AddrIsSourceLine: Boolean;
begin
  if FDbgController = nil then Exit;
  AFileName := '';
  ALine := -1;
  Bp := nil;
  AddrIsSourceLine := False;
  Sym := FDbgController.CurrentProcess.FindProcSymbol(AddrVA);
  if Assigned(Sym) then
  try
    AFileName := Sym.FileName;
    ALine := Sym.Line;
  finally
    Sym.ReleaseReference;
  end;
  if ALine > 0 then
  begin
    if FProcess.GetLineAddresses(AFileName, ALine, BPList{%H-}) then
    begin
      for I := 0 to Length(BPList) - 1 do
        if BPList[I] = AddrVA then
        begin
          AddrIsSourceLine := True;
          Bp := FBreakPoints.Find(AFileName, ALine);
          Break;
        end;
    end
  end;
  if Bp = nil then
    Bp := FBreakPoints.Find(AddrVA);
  if Assigned(Bp) then
  begin
    Bp.ReleaseReference;
    Exit;
  end;
  DebugBoss.LockCommandProcessing;
  try
    if AddrIsSourceLine then
      DebugBoss.DoCreateBreakPoint(AFileName, ALine, True, Bp)
    else
      DebugBoss.DoCreateBreakPoint(AddrVA, True, Bp);
  finally
    DebugBoss.UnLockCommandProcessing;
  end;
end;

function TCpuViewDebugGate.ThreadStackLimit: TStackLimit;
begin
  Result := Utils.GetThreadStackLimit(ThreadId, PointerSize = 4);
end;

function TCpuViewDebugGate.ThreadID: Cardinal;
var
  Snapshot: TSnapshot;
begin
  if Assigned(FDbgController) then
  begin
    if Assigned(FSnapshotManager) then
      Snapshot := FSnapshotManager.SelectedEntry
    else
      Snapshot := nil;
    if Assigned(FThreadsMonitor) then
    begin
      if Assigned(Snapshot) then
        Result := FThreadsMonitor.Snapshots[Snapshot].CurrentThreadId
      else
        Result := FThreadsMonitor.CurrentThreads.CurrentThreadId;
    end
    else
      Result := FDbgController.CurrentProcess.ThreadID
  end
  else
    Result := 0;
end;

procedure TCpuViewDebugGate.TraceIn;
begin
  FLockTimeOut := GetTickCount64;
  FDebugger.StepIntoInstr;
end;

procedure TCpuViewDebugGate.TraceOut;
begin
  FLockTimeOut := GetTickCount64;
  FDebugger.StepOverInstr;
end;

procedure TCpuViewDebugGate.TraceTilReturn;
begin
  FDebugger.StepOut;
end;

procedure TCpuViewDebugGate.TraceTo(AddrVA: Int64);
var
  ALocation: TDBGPtrArray;
begin
  if FDbgController = nil then Exit;
  if FDebugger = nil then Exit;
  if FDebugger.State <> dsPause then Exit;

  StopAllWorkers;

  SetLength(ALocation{%H-}, 1);
  ALocation[0] := QWord(AddrVA);
  FDbgController.InitializeCommand(TDbgControllerRunToCmd.Create(FDbgController, ALocation));
  TFpDebugDebuggerAccess(FDebugger).StartDebugLoop;
end;

function TCpuViewDebugGate.UpdateRegValue(RegID: Integer; ANewRegValue: UInt64
  ): Boolean;
var
  WorkQueue: TFpThreadPriorityWorkerQueue;
  WorkItem: TThreadWorkerChangeThreadContext;
  RegValue: TRegValue;
begin
  if FDebugger = nil then Exit;
  if FDebugger.State <> dsPause then Exit;

  StopAllWorkers;

  WorkQueue := TFpDebugDebugger(FDebugger).WorkQueue;
  if Assigned(WorkQueue) then
  begin
    RegValue := Default(TRegValue);
    RegValue.QwordValue := ANewRegValue;
    WorkItem := TThreadWorkerChangeThreadContext.Create(Self);
    WorkQueue.PushItem(WorkItem);
    WorkQueue.WaitForItem(WorkItem, True);
    WorkItem.DecRef;
  end;

  RegValue := Default(TRegValue);
  RegValue.QwordValue := ANewRegValue;
  Context.ThreadID := ThreadID;
  Context.BeginUpdate;
  try
    Result := Context.RegSetValue(RegID, RegValue);
    if Result and (RegID = Context.InstructonPointID) then
      FTemporaryIP.AddOrSetValue(ThreadID, ANewRegValue);
  finally
    Context.EndUpdate;
  end;
end;

procedure TCpuViewDebugGate.UpdateRemoteStream(pBuff: PByte; AAddrVA: UInt64;
  ASize: Int64);
var
  WorkQueue: TFpThreadPriorityWorkerQueue;
  WorkItem: TThreadWorkerMaskBreakpoints;
begin
  if FDebugger = nil then Exit;
  if FDebugger.State <> dsPause then Exit;

  StopAllWorkers;

  WorkQueue := TFpDebugDebugger(FDebugger).WorkQueue;
  if Assigned(WorkQueue) then
  begin
    WorkItem := TThreadWorkerMaskBreakpoints.Create(
      TFpDebugDebugger(FDebugger), pBuff, AAddrVA, ASize);
    WorkQueue.PushItem(WorkItem);
    WorkQueue.WaitForItem(WorkItem, True);
    WorkItem.DecRef;
  end;
end;

end.