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
  {$IFDEF WINDOWS}
  FpDbgWinClasses,
  {$ENDIF}

  // LazUtils
  LazLoggerBase,

  // CodeTools
  CodeCache,
  CodeToolManager,

  {$IFDEF MSWINDOWS}
  CpuView.Windows,
  CpuView.Stream.Windows,
  {$ENDIF}

  CpuView.Common,
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
    FRegID: Integer;
    FNewRegValue: UInt64;
    FThreadResult: Boolean;
  protected
    procedure DoExecute; override;
  public
    constructor Create(ADbgIntf: TCpuViewDebugGate; ARegID: Integer; ANewRegValue: UInt64);
    property ThreadResult: Boolean read FThreadResult;
  end;

  { TCpuViewDebugGate }

  TCpuViewDebugGate = class(TAbstractDebugger)
  private
    FBreakPoints: TIDEBreakPoints;
    FBreakpointsNotification: TIDEBreakPointsNotification;
    FDebugger: TDebuggerIntf;
    FDbgController: TDbgController;
    FProcess: TDbgProcess;
    FRegisterInDebugBoss: Boolean;
    FSupportStream: TRemoteStream;
    FPreviosSrcLine: Integer;
    FPreviosSrcFuncName, FPreviosSrcFileName: string;
    FLockTimeOut: Int64;
    procedure BreakPointChanged(const {%H-}ASender: TIDEBreakPoints;
      const {%H-}ABreakpoint: TIDEBreakPoint);
    procedure DoDebuggerDestroy(Sender: TObject);
    procedure OnActivateIDEForm(Sender: TObject; var AHandled: Boolean);
    procedure OnActivateSourceEditor(Sender: TObject; var AHandled: Boolean);
    procedure OnState(ADebugger: TDebuggerIntf; AOldState: TDBGState);
    procedure Reset;
    procedure UpdateDebugger(ADebugger: TDebuggerIntf);
  public
    constructor Create(ACpuViewForm: TCustomForm); override;
    destructor Destroy; override;
    function CommandAvailable(ACommand: TInterfaceDebugCommand): Boolean; override;
    function CurrentInstructionPoint: UInt64; override;
    function DebugState: TAbstractDebugState; override;
    function Disassembly(AddrVA: Int64; pBuff: PByte; nSize: Integer): TList<TInstruction>; override;
    function IsActive: Boolean; override;
    function IsActiveJmp: Boolean; override;
    procedure Pause; override;
    function PointerSize: Integer; override;
    function ProcessID: Cardinal; override;
    function QuerySymbolAtAddr(AddrVA: Int64; AParam: TQuerySymbol): string; override;
    procedure Run; override;
    procedure Stop; override;
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
  if FDbgIntf.Debugger = nil then Exit;
  if FDbgIntf.Debugger.State <> dsPause then Exit;

  FDbgIntf.DbgController.CurrentProcess.GetThread(FDbgIntf.ThreadID, DebugThread);
  if DebugThread <> nil then
    DebugThread.BeforeContinue;

  FDbgIntf.Context.ThreadID := FDbgIntf.ThreadID;
  FThreadResult := FDbgIntf.Context.UpdateRegValue(FRegID, FNewRegValue);

  //if DebugThread <> nil then
  //  TDebugThreadAcces(DebugThread).ReadThreadState;
end;

constructor TThreadWorkerChangeThreadContext.Create(
  ADbgIntf: TCpuViewDebugGate; ARegID: Integer; ANewRegValue: UInt64);
begin
  inherited Create((ADbgIntf.Debugger as TFpDebugDebugger), twpContinue);
  FDbgIntf := ADbgIntf;
  FRegID := ARegID;
  FNewRegValue := ANewRegValue;
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

procedure TCpuViewDebugGate.DoDebuggerDestroy(Sender: TObject);
begin
  Reset;
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
    if FDebugger <> ADebugger then
      UpdateDebugger(ADebugger)
    else
      UpdateContext;
  end;
  DoStateChange;
end;

procedure TCpuViewDebugGate.Reset;
begin
  if Assigned(FDebugger) then
  begin
    //FDebugger.OnActivateSourceEditor := nil;
    FDebugger := nil;
  end;
  FDbgController := nil;
  FProcess := nil;
  //if Assigned(IDEWindowCreators) then
    //IDEWindowCreators.OnActivateIDEForm := nil;
  if Assigned(FBreakPoints) then
  begin
    DebugBoss.BreakPoints.RemoveNotification(FBreakpointsNotification);
    FBreakPoints := nil;
  end;
end;

procedure TCpuViewDebugGate.UpdateDebugger(ADebugger: TDebuggerIntf);
begin
  FDebugger := ADebugger;
  if Assigned(FDebugger) and (FDebugger is TFpDebugDebugger) then
  begin
    FDbgController := TFpDebugDebugger(FDebugger).DbgController;
    FProcess := FDbgController.CurrentProcess;
    if Assigned(FProcess) and not FProcess.GotExitProcess then
    begin
      FDebugger.AddNotifyEvent(dnrDestroy, DoDebuggerDestroy);
      //if Assigned(IDEWindowCreators) then
      //  IDEWindowCreators.OnActivateIDEForm := OnActivateIDEForm;
      //FDebugger.OnActivateSourceEditor := OnActivateSourceEditor;
      if Assigned(DebugBoss) and Assigned(DebugBoss.BreakPoints) then
      begin
        FBreakPoints := DebugBoss.BreakPoints;
        FBreakPoints.AddNotification(FBreakpointsNotification);
        BreakPointChanged(FBreakPoints, nil);
      end;
      if ADebugger.State = dsPause then
        UpdateContext;
      Exit;
    end;
  end;
  Reset;
end;

constructor TCpuViewDebugGate.Create(ACpuViewForm: TCustomForm);
begin
  inherited;
  FSupportStream := TRemoteStream.Create;
  FSupportStream.OnUpdated := UpdateRemoteStream;
  FBreakpointsNotification := TIDEBreakPointsNotification.Create;
  FBreakpointsNotification.AddReference;
  FBreakpointsNotification.OnAdd := BreakPointChanged;
  FBreakpointsNotification.OnUpdate := BreakPointChanged;
  FBreakpointsNotification.OnRemove := BreakPointChanged;
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
  FSupportStream.Free;
  Reset;
  FBreakpointsNotification.OnAdd := nil;
  FBreakpointsNotification.OnRemove := nil;
  FBreakpointsNotification.OnUpdate := nil;
  ReleaseRefAndNil(FBreakpointsNotification);
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
begin
  if Assigned(FDebugger) and (FDebugger.State = dsPause) then
    Result := FDebugger.GetLocation.Address
  else
    Result := 0;
end;

function TCpuViewDebugGate.DebugState: TAbstractDebugState;
begin
  if Assigned(FDebugger) then
  begin
    case FDebugger.State of
      dsInit: Result := adsStart;
      dsPause: Result := adsPaused;
      dsRun: Result := adsRunning;
      {$message 'отладочное'}
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
  I: Integer;
  PrevVA: Int64;
  ACodeBytes, ACode: string;
  AnInfo: TDbgInstInfo;
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
    PrevVA := Int64(pBuff);
    Disasm.Disassemble(pBuff, ACodeBytes, ACode, AnInfo);
    Instruction.AddrVA := AddrVA;
    Instruction.AsString := AnsiUpperCase(Trim(ACode));
    Instruction.AsString := StringReplace(Instruction.AsString, '$', '0x', [rfReplaceAll]);
    if AnInfo.InstrType = itJump then
    begin
      Instruction.JmpTo := AddrVA + AnInfo.InstrTargetOffs;
      Instruction.Hint := QuerySymbolAtAddr(Instruction.JmpTo, qsName);
      if Instruction.Hint = '' then
        Instruction.Hint := '0x' + IntToHex(Instruction.JmpTo, 1);
    end
    else
    begin
      Instruction.JmpTo := 0;
      Instruction.Hint := '';
    end;
    Instruction.Len := Int64(pBuff) - PrevVA;
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
begin
  Result := False;
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
  Tmp: Int64;
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

procedure TCpuViewDebugGate.Run;
begin
  FDebugger.Run;
end;

procedure TCpuViewDebugGate.Stop;
begin
  FDebugger.Stop;
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
  {$IFDEF CPUX64}
  if PointerSize = 4 then
    Result := GetThreadWow64StackLimit(ProcessID, ThreadId)
  else
  {$ENDIF}
    Result := GetThreadStackLimit(ProcessID, ThreadId);
end;

function TCpuViewDebugGate.ThreadID: Cardinal;
begin
  if Assigned(FDbgController) then
    Result := FDbgController.CurrentProcess.ThreadID
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
begin
  {$message 'не реализовано'}
end;

function TCpuViewDebugGate.UpdateRegValue(RegID: Integer; ANewRegValue: UInt64
  ): Boolean;
var
  WorkQueue: TFpThreadPriorityWorkerQueue;
  WorkItem: TThreadWorkerChangeThreadContext;
begin
  if FDebugger = nil then Exit;
  if FDebugger.State <> dsPause then Exit;
  WorkQueue := TFpDebugDebugger(FDebugger).WorkQueue;
  if Assigned(WorkQueue) then
  begin
    WorkItem := TThreadWorkerChangeThreadContext.Create(
      Self, RegID, ANewRegValue);
    WorkQueue.PushItem(WorkItem);
    WorkQueue.WaitForItem(WorkItem, True);
    Result := WorkItem.ThreadResult;
    WorkItem.DecRef;
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