unit uYAFFI;

{$mode objfpc}{$H+}

interface

uses
  Windows, Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs,
  StdCtrls, ComCtrls, ActiveX, ComObj, Variants;

type

  { TfrmYAFFI }

  TfrmYAFFI = class(TForm)
    btnListAttachedDisks: TButton;
    Memo1: TMemo;
    TreeView1: TTreeView;
    procedure btnListAttachedDisksClick(Sender: TObject);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  frmYAFFI: TfrmYAFFI;

  // These four functions are needed for traversing the attached disks.
  // Yes, all these for just that!!
  // Credit to RRUZ at SO : https://stackoverflow.com/questions/12271269/how-can-i-correlate-logical-drives-and-physical-disks-using-the-wmi-and-delphi/12271778#comment49108167_12271778
  // https://theroadtodelphi.wordpress.com/2010/12/01/accesing-the-wmi-from-pascal-code-delphi-oxygene-freepascal/#Lazarus
  function ListDrives : string;
  function VarStrNull(const V:OleVariant):string;
  function GetWMIObject(const objectName: String): IDispatch;
  function VarArrayToStr(const vArray: variant): string;

implementation

{$R *.lfm}

{ TfrmYAFFI }

procedure TfrmYAFFI.btnListAttachedDisksClick(Sender: TObject);
begin

  try
    ListDrives;
  finally
  end;
end;

function VarArrayToStr(const vArray: variant): string;

    function _VarToStr(const V: variant): string;
    var
    Vt: integer;
    begin
    Vt := VarType(V);
        case Vt of
          varSmallint,
          varInteger  : Result := IntToStr(integer(V));
          varSingle,
          varDouble,
          varCurrency : Result := FloatToStr(Double(V));
          varDate     : Result := VarToStr(V);
          varOleStr   : Result := WideString(V);
          varBoolean  : Result := VarToStr(V);
          varVariant  : Result := VarToStr(Variant(V));
          varByte     : Result := char(byte(V));
          varString   : Result := String(V);
          varArray    : Result := VarArrayToStr(Variant(V));
        end;
    end;

var
i : integer;
begin
    Result := '[';
     if (VarType(vArray) and VarArray)=0 then
       Result := _VarToStr(vArray)
    else
    for i := VarArrayLowBound(vArray, 1) to VarArrayHighBound(vArray, 1) do
     if i=VarArrayLowBound(vArray, 1)  then
      Result := Result+_VarToStr(vArray[i])
     else
      Result := Result+'|'+_VarToStr(vArray[i]);

    Result:=Result+']';
end;

function VarStrNull(const V:OleVariant):string; //avoid problems with null strings
begin
  Result:='';
  if not VarIsNull(V) then
  begin
    if VarIsArray(V) then
       Result:=VarArrayToStr(V)
    else
    Result:=VarToStr(V);
  end;
end;

function GetWMIObject(const objectName: String): IDispatch; //create the Wmi instance
var
  chEaten: PULONG;
  BindCtx: IBindCtx;
  Moniker: IMoniker;
begin
  OleCheck(CreateBindCtx(0, bindCtx));
  OleCheck(MkParseDisplayName(BindCtx, StringToOleStr(objectName), chEaten, Moniker));
  OleCheck(Moniker.BindToObject(BindCtx, nil, IDispatch, Result));
end;

function ListDrives : string;
var
  FSWbemLocator  : Variant;
  objWMIService  : Variant;
  colDiskDrives  : Variant;
  colLogicalDisks: Variant;
  colPartitions  : Variant;
  objdiskDrive   : Variant;
  objPartition   : Variant;
  objLogicalDisk : Variant;
  oEnumDiskDrive : IEnumvariant;
  oEnumPartition : IEnumvariant;
  oEnumLogical   : IEnumvariant;
  iValue         : pULONG;
  DeviceID       : widestring;
  s              : widestring;
  Node           : TTreeNode;

begin;
  Result:='';
  FSWbemLocator   := CreateOleObject('WbemScripting.SWbemLocator');
  objWMIService   := FSWbemLocator.ConnectServer('localhost', 'root\CIMV2', '', '');
  colDiskDrives   := objWMIService.ExecQuery('SELECT DeviceID FROM Win32_DiskDrive', 'WQL');
  oEnumDiskDrive  := IUnknown(colDiskDrives._NewEnum) as IEnumVariant;

   Node:=frmYAFFI.TreeView1.Items.Add(nil,'Expand Tree') ;
   Node.ImageIndex :=0; // enables a change of any property of the node

  while oEnumDiskDrive.Next(1, objdiskDrive, nil) = 0 do
   begin
      frmYAFFI.Memo1.Lines.Add(Format('DeviceID %s',[string(objdiskDrive.DeviceID)]));
      frmYAFFI.Treeview1.Items.AddChild(frmYAFFI.Treeview1.Items[0], Format('DeviceID %s',[string(objdiskDrive.DeviceID)]));
      //Escape the `\` chars in the DeviceID value because the '\' is a reserved character in WMI.
      DeviceID        := StringReplace(objdiskDrive.DeviceID,'\','\\',[rfReplaceAll]);
      //link the Win32_DiskDrive class with the Win32_DiskDriveToDiskPartition class
      s:=Format('ASSOCIATORS OF {Win32_DiskDrive.DeviceID="%s"} WHERE AssocClass = Win32_DiskDriveToDiskPartition',[DeviceID]);
      colPartitions   := objWMIService.ExecQuery(s, 'WQL');
      oEnumPartition  := IUnknown(colPartitions._NewEnum) as IEnumVariant;
      while oEnumPartition.Next(1, objPartition, nil) = 0 do
      begin
       if not VarIsNull(objPartition.DeviceID) then
       begin
        frmYAFFI.Memo1.Lines.Add(Format('   Partition %s',[string(objPartition.DeviceID)]));
        frmYAFFI.Treeview1.Items.AddChild(frmYAFFI.Treeview1.Items[1], Format('   Partition %s',[string(objPartition.DeviceID)]));

        //link the Win32_DiskPartition class with theWin32_LogicalDiskToPartition class.
        s:='ASSOCIATORS OF {Win32_DiskPartition.DeviceID="'+VarToStr(objPartition.DeviceID)+'"} WHERE AssocClass = Win32_LogicalDiskToPartition';
        colLogicalDisks := objWMIService.ExecQuery(s);
        oEnumLogical  := IUnknown(colLogicalDisks._NewEnum) as IEnumVariant;
          while oEnumLogical.Next(1, objLogicalDisk, nil) = 0 do
          begin
            frmYAFFI.Memo1.Lines.Add(Format('     Logical Disk %s',[string(objLogicalDisk.DeviceID)]));
            frmYAFFI.Treeview1.Items.AddChild(frmYAFFI.Treeview1.Items[2], Format('     Logical Disk %s',[string(objLogicalDisk.DeviceID)]));
            objLogicalDisk:=Unassigned;
          end;
       end;
       objPartition:=Unassigned;
      end;
       objdiskDrive:=Unassigned;
   end;
end;
end.

