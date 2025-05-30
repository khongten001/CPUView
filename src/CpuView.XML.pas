﻿////////////////////////////////////////////////////////////////////////////////
//
//  ****************************************************************************
//  * Project   : CPU-View
//  * Unit Name : CpuView.XML.pas
//  * Purpose   : Set of methods for working with XML
//  * Author    : Alexander (Rouse_) Bagel
//  * Copyright : © Fangorn Wizards Lab 1998 - 2025.
//  * Version   : 1.0
//  * Home Page : http://rouse.drkb.ru
//  * Home Blog : http://alexander-bagel.blogspot.ru
//  ****************************************************************************
//  * Latest Release : https://github.com/AlexanderBagel/CPUView/releases
//  * Latest Source  : https://github.com/AlexanderBagel/CPUView
//  ****************************************************************************
//

unit CpuView.XML;

{$IFDEF FPC}
  {$MODE Delphi}
{$ENDIF}

interface

uses
  {$IFDEF FPC}
  LCLIntf,
  DOM
  {$ELSE}
  Windows,
  XMLIntf, xmldom, XMLDoc
  {$ENDIF},
  Variants,
  SysUtils;

const
  xmlItem = 'item';
  xmlMode = 'mode';

{$IFDEF FPC}
type
  IXMLNode = TDOMNode;
  IXMLDocument = TXMLDocument;
{$ENDIF}

  function FindNode(ANode: IXMLNode; const ANodeName: string): IXMLNode;
  function GetNodeAttr(Node: IXMLNode; const Attr: string): OleVariant;
  function GetNodeAttrString(Node: IXMLNode; const Attr: string): string;
  procedure SetNodeAttr(Node: IXMLNode; const Attr: string; Value: OleVariant);
  function GetChildNode(Node: IXMLNode; Index: Integer): IXMLNode;
  procedure XMLWriteDouble(Node: IXMLNode; const Attr: string; Value: Double);
  function XMLReadDouble(Node: IXMLNode; const Attr: string): Double;
  function NewChild(Node: IXMLNode; const ChildName: string): IXMLNode;

implementation

function FindNode(ANode: IXMLNode; const ANodeName: string): IXMLNode;
{$IFDEF FPC}
var
  I: Integer;
{$ENDIF}
begin
  Result := nil;
  if ANode <> nil then
    {$IFDEF FPC}
    begin
      for I := 0 to ANode.ChildNodes.Count - 1 do
        if ANode.ChildNodes[I].NodeName = DOMString(ANodeName) then
        begin
          Result := ANode.ChildNodes[I];
          Break;
        end;
    end;
    {$ELSE}
    Result := ANode.ChildNodes.FindNode(ANodeName);
    {$ENDIF}
end;

function GetNodeAttr(Node: IXMLNode; const Attr: string): OleVariant;
{$IFDEF FPC}
var
  NamedAttr: TDOMNode;
{$ENDIF}
begin
  {$IFDEF FPC}
  NamedAttr := Node.Attributes.GetNamedItem(DOMString(Attr));
  if NamedAttr = nil then
    Result := null
  else
    Result := NamedAttr.NodeValue;
  {$ELSE}
  Result := Node.Attributes[Attr];
  {$ENDIF}
end;

function GetNodeAttrString(Node: IXMLNode; const Attr: string): string;
var
  AttrValue: OleVariant;
begin
  AttrValue := GetNodeAttr(Node, Attr);
  if AttrValue = null then
    Result := ''
  else
    Result := AttrValue;
end;

procedure SetNodeAttr(Node: IXMLNode; const Attr: string; Value: OleVariant);
begin
  {$IFDEF FPC}
  TDOMElement(Node).SetAttribute(DOMString(Attr), Value);
  {$ELSE}
  Node.Attributes[Attr] := Value;
  {$ENDIF}
end;

function GetChildNode(Node: IXMLNode; Index: Integer): IXMLNode;
begin
  {$IFDEF FPC}
  Result := Node.ChildNodes[Index];
  {$ELSE}
  Result := Node.ChildNodes.Nodes[Index];
  {$ENDIF}
end;

procedure XMLWriteDouble(Node: IXMLNode; const Attr: string; Value: Double);
var
  FS: TFormatSettings;
begin
  FS := FormatSettings;
  FS.DecimalSeparator := '.';
  SetNodeAttr(Node, Attr, FloatToStr(Value, FS));
end;

function XMLReadDouble(Node: IXMLNode; const Attr: string): Double;
var
  Atrib: OleVariant;
  FS: TFormatSettings;
begin
  Result := 0;
  if Node <> nil then
  begin
    Atrib := GetNodeAttr(Node, Attr);
    FS := FormatSettings;
    FS.DecimalSeparator := '.';
    if not VarIsNull(Atrib) then
      TryStrToFloat(Atrib, Result, FS);
  end;
end;

function NewChild(Node: IXMLNode; const ChildName: string): IXMLNode;
begin
  {$IFDEF FPC}
  Result := Node.OwnerDocument.CreateElement(DOMString(ChildName));
  Node.AppendChild(Result);
  {$ELSE}
  Result := Node.AddChild(ChildName);
  {$ENDIF}
end;

end.

