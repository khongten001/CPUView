﻿unit CpuView.Common;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

type
  // режимы отображения регистров
  TRegViewMode = (
    rvmHex, rvmHexW, rvmHexD, rvmHexQ,
    rvmOct, rvmBin, rvmIntB, rvmUIntB,
    rvmIntW, rvmIntD, rvmIntQ,
    rvmUIntW, rvmUIntD, rvmUIntQ,
    rvmFloat32, rvmFloat64, rvmFloat80);
  TRegViewModes = set of TRegViewMode;

  TStackLimit = record
    Base, Limit: UInt64;
  end;

  TStackFrame = record
    AddrStack,
    AddrFrame,
    AddrPC: UInt64;
  end;

  TRegionData = record
    AllocationBase,
    BaseAddr,
    RegionSize: Int64;
    Executable: Boolean;
    Readable: Boolean;
  end;

  // Расширеная информация по потоку (если присутствует)
  TThreadExtendedData = record
    LastError, LastStatus: Cardinal;
  end;

  { TCommonAbstractUtils }

  TCommonAbstractUtils = class
  private
    FProcessID: Integer;
  protected
    procedure SetProcessID(const Value: Integer); virtual;
  public
    function GetThreadExtendedData(ThreadID: Integer; ThreadIs32: Boolean): TThreadExtendedData; virtual; abstract;
    function GetThreadStackLimit(ThreadID: Integer; ThreadIs32: Boolean): TStackLimit; virtual; abstract;
    function NeedUpdateReadData: Boolean; virtual;
    function QueryRegion(AddrVA: Int64; out RegionData: TRegionData): Boolean; virtual; abstract;
    function ReadData(AddrVA: Pointer; var Buff; ASize: Longint): Longint; virtual; abstract;
    function SetThreadExtendedData(ThreadID: Integer; ThreadIs32: Boolean; const AData: TThreadExtendedData): Boolean; virtual; abstract;
    procedure Update; virtual; abstract;
    property ProcessID: Integer read FProcessID write SetProcessID;
  end;

  TCommonAbstractUtilsClass = class of TCommonAbstractUtils;

implementation

{ TCommonAbstractUtils }

function TCommonAbstractUtils.NeedUpdateReadData: Boolean;
begin
  Result := True;
end;

procedure TCommonAbstractUtils.SetProcessID(const Value: Integer);
begin
  FProcessID := Value;
end;

end.
