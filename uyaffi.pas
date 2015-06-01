unit UYaffi;

{$mode objfpc}{$H+}

interface

uses
  {$ifdef UNIX}
  process,
   {$IFDEF UseCThreads}
      cthreads,
    {$ENDIF}
  {$endif}

  {$ifdef Windows}
    Windows, ActiveX, ComObj, Variants,
  {$endif}
    Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
    ComCtrls;

type

  { TfrmYaffi }

  TfrmYaffi = class(TForm)
    Button1: TButton;
    cbdisks: TComboBox;
    ImageList1: TImageList;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    lt: TLabel;
    ls: TLabel;
    lm: TLabel;
    lv: TLabel;
    TreeView1: TTreeView;

    // Two procedures below contributed by Paweld :
    // http://forum.lazarus.freepascal.org/index.php/topic,28560.0.html
    procedure Button1Click(Sender: TObject);
    procedure cbdisksChange(Sender: TObject);

  private
    { private declarations }
  public
    { public declarations }
  end;

var
  frmYaffi: TfrmYaffi;

  {$ifdef Windows}
  // These four functions are needed for traversing the attached disks in Windows.
  // Yes, all these for just that!! The joy of Windows coding
  // Credit to RRUZ at SO : https://stackoverflow.com/questions/12271269/how-can-i-correlate-logical-drives-and-physical-disks-using-the-wmi-and-delphi/12271778#comment49108167_12271778
  // https://theroadtodelphi.wordpress.com/2010/12/01/accesing-the-wmi-from-pascal-code-delphi-oxygene-freepascal/#Lazarus
  function ListDrives : string;
  function VarStrNull(const V:OleVariant):string;
  function GetWMIObject(const objectName: String): IDispatch;
  function VarArrayToStr(const vArray: variant): string;
  {$endif}

implementation

{$R *.lfm}

{ TfrmYaffi }

procedure TfrmYaffi.Button1Click(Sender: TObject);
var
   {$ifdef UNIX}
  DisksProcess: TProcess;
   {$endif UNIX}
  i: Integer;
  slDisklist: TSTringList;
begin
  {$ifdef Windows}
  try
    ListDrives;
  finally
  end;
  {$endif}

  {$ifdef UNIX}
  DisksProcess:=TProcess.Create(nil);
  DisksProcess.Options:=[poWaitOnExit, poUsePipes];
  DisksProcess.CommandLine:='cat /proc/partitions';   //get all disks/partitions list
  DisksProcess.Execute;
  slDisklist:=TStringList.Create;
  slDisklist.LoadFromStream(DisksProcess.Output);
  slDisklist.Delete(0);  //delete columns name line
  slDisklist.Delete(0);  //delete separator line
  cbdisks.Items.Clear;
  for i:=0 to slDisklist.Count-1 do
  begin
    if Length(Copy(slDisklist.Strings[i], 26, Length(slDisklist.Strings[i])-25))=3 then
    cbdisks.Items.Add(Copy(slDisklist.Strings[i], 26, Length(slDisklist.Strings[i])-25));
  end;
  slDisklist.Free;
  DisksProcess.Free;
  {$endif}
end;

procedure TfrmYaffi.cbdisksChange(Sender: TObject);
const
  smodel  = 'ID_MODEL=';
  sserial = 'ID_SERIAL_SHORT=';
  stype   = 'ID_TYPE=';
  svendor = 'ID_VENDOR=';
var
  {$ifdef UNIX}
  DiskInfoProcess          : TProcess;
  DiskInfoProcessUDISKS    : TProcess;
  {$endif}
  diskinfo, diskinfoUDISKS : TStringList;
  i: Integer;
  stmp: String;
begin
  {$ifdef UNIX}
  if cbdisks.ItemIndex<0 then
  exit;
  lv.Caption:='';
  lm.Caption:='';
  ls.Caption:='';
  lt.Caption:='';

  // Probe all attached disks and populate the interface
  DiskInfoProcess:=TProcess.Create(nil);
  DiskInfoProcess.Options:=[poWaitOnExit, poUsePipes];
  DiskInfoProcess.CommandLine:='/sbin/udevadm info --query=property --name='+cbdisks.Text;  //get info about selected disk
  DiskInfoProcess.Execute;

  diskinfo:=TStringList.Create;
  diskinfo.LoadFromStream(DiskInfoProcess.Output);


  for i:=0 to diskinfo.Count-1 do
  begin
    if pos(smodel, diskinfo.Strings[i])>0 then
    begin
      stmp:=diskinfo.Strings[i];
      Delete(stmp, 1, Length(smodel));
      if pos('_', stmp)>0 then
      begin
        lv.Caption:=Copy(stmp, 1, pos('_', stmp)-1);
        Delete(stmp, 1, pos('_', stmp));
        lm.Caption:=stmp;
      end
      else
      lm.Caption:=stmp;
    end
    else if pos(sserial, diskinfo.Strings[i])>0 then
    ls.Caption:=Copy(diskinfo.Strings[i], Length(sserial)+1, Length(diskinfo.Strings[i])-Length(sserial))
    else if pos(stype, diskinfo.Strings[i])>0 then
    lt.Caption:=Copy(diskinfo.Strings[i], Length(stype)+1, Length(diskinfo.Strings[i])-Length(stype))
    else if pos(svendor, diskinfo.Strings[i])>0 then
    begin
      lm.Caption:=lv.Caption+' '+lm.Caption;
      lv.Caption:=Copy(diskinfo.Strings[i], Length(svendor)+1, Length(diskinfo.Strings[i])-Length(svendor));
    end;
  end;

  // Get all technical specifications about a user selected disk and save it
  DiskInfoProcessUDISKS := TProcess.Create(nil);
  DiskInfoProcessUDISKS.Options := [poWaitOnExit, poUsePipes];
  DiskInfoProcessUDISKS.CommandLine := 'udisks --show-info /dev/' + cbdisks.Text;
  DiskInfoProcessUDISKS.Execute;
  diskinfoUDISKS := TStringList.Create;
  diskinfoUDISKS.LoadFromStream(diskinfoProcessUDISKS.Output);
  diskinfoUDISKS.SaveToFile('TechnicalDiskDetails.txt');

  // Free everything
  diskinfo.Free;
  diskinfoUDISKS.Free;
  DiskInfoProcess.Free;
  DiskInfoProcessUDISKS.Free;
  {$endif} // End of Linux compiler check
end;

// These are Windows centric functions. Many call upon the Windows API.
{$ifdef Windows}

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
  DeviceID, Val1, Val2, Val3 : widestring;
  s              : widestring;
  PhyDiskNode, PartitionNoNode, DriveLetterNode           : TTreeNode;

begin;
  Result:='';
  Val1 := '';
  Val2 := '';
  Val3 := '';

  frmYAFFI.Treeview1.Images := frmYAFFI.ImageList1;
  PhyDiskNode     := frmYAFFI.TreeView1.Items.Add(nil,'Physical Disk') ;
  PhyDiskNode.ImageIndex :=0;

 PartitionNoNode := frmYAFFI.TreeView1.Items.Add(nil,'Logical Partition') ;
 PartitionNoNode.ImageIndex :=1;

 DriveLetterNode := frmYAFFI.TreeView1.Items.Add(nil,'Drive Letter') ;
 DriveLetterNode.ImageIndex :=1;


  FSWbemLocator   := CreateOleObject('WbemScripting.SWbemLocator');
  objWMIService   := FSWbemLocator.ConnectServer('localhost', 'root\CIMV2', '', '');
  colDiskDrives   := objWMIService.ExecQuery('SELECT DeviceID FROM Win32_DiskDrive', 'WQL');
  oEnumDiskDrive  := IUnknown(colDiskDrives._NewEnum) as IEnumVariant;


  while oEnumDiskDrive.Next(1, objdiskDrive, nil) = 0 do
   begin
      Val1 := Format('%s',[string(objdiskDrive.DeviceID)]);
      if Length(Val1) > 0 then
      begin
        frmYaffi.TreeView1.Items.AddChild(PhyDiskNode, Val1);
      end;
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
        val2 := Format('%s',[string(objPartition.DeviceID)]);
         if Length(Val2) > 0 then
         begin
           frmYaffi.TreeView1.Items.AddChild(PartitionNoNode, Val2);
         end;
        //link the Win32_DiskPartition class with theWin32_LogicalDiskToPartition class.
        s:='ASSOCIATORS OF {Win32_DiskPartition.DeviceID="'+VarToStr(objPartition.DeviceID)+'"} WHERE AssocClass = Win32_LogicalDiskToPartition';
        colLogicalDisks := objWMIService.ExecQuery(s);
        oEnumLogical  := IUnknown(colLogicalDisks._NewEnum) as IEnumVariant;

        while oEnumLogical.Next(1, objLogicalDisk, nil) = 0 do
          begin
            Val3 := Format('Drive %s',[string(objLogicalDisk.DeviceID)]);
             if Length(Val3) > 0 then
              begin
                frmYaffi.TreeView1.Items.AddChild(DriveLetterNode, Val3);
              end;
            objLogicalDisk:=Unassigned;
          end;
       end;
       objPartition:=Unassigned;
      end;
       objdiskDrive:=Unassigned;
   end;
end;
{$endif}
end.

