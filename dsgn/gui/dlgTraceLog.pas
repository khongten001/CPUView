unit dlgTraceLog;

{$mode objfpc}{$H+}

interface

uses
  LCLType, LCLIntf, Messages, Classes, SysUtils, Forms, Controls, Graphics,
  Dialogs, StdCtrls, Menus;

type

  { TfrmTraceLog }

  TfrmTraceLog = class(TForm)
    memLog: TMemo;
    miSave: TMenuItem;
    miClear: TMenuItem;
    mnuCopy: TMenuItem;
    pmTraceLog: TPopupMenu;
    SaveDialog: TSaveDialog;
    Separator1: TMenuItem;
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormDestroy(Sender: TObject);
    procedure miClearClick(Sender: TObject);
    procedure miSaveClick(Sender: TObject);
    procedure mnuCopyClick(Sender: TObject);
  private
    FTraceLog: TStringList;
  public
    procedure UpdateTraceLog(Value: TStringList);
  end;

var
  frmTraceLog: TfrmTraceLog;

implementation

{$R *.lfm}

{ TfrmTraceLog }

procedure TfrmTraceLog.mnuCopyClick(Sender: TObject);
begin
  memLog.CopyToClipboard;
end;

procedure TfrmTraceLog.UpdateTraceLog(Value: TStringList);
begin
  FTraceLog := Value;
  memLog.Lines.Assign(Value);
  SendMessage(frmTraceLog.memLog.Handle, WM_VSCROLL, SB_BOTTOM, 0);
end;

procedure TfrmTraceLog.miClearClick(Sender: TObject);
begin
  memLog.Clear;
  FTraceLog.Clear;
end;

procedure TfrmTraceLog.FormClose(Sender: TObject; var CloseAction: TCloseAction
  );
begin
  CloseAction := caFree;
end;

procedure TfrmTraceLog.FormDestroy(Sender: TObject);
begin
  frmTraceLog := nil;
end;

procedure TfrmTraceLog.miSaveClick(Sender: TObject);
begin
  if SaveDialog.Execute then
    memLog.Lines.SaveToFile(SaveDialog.FileName);
end;

end.

