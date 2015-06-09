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
    ComCtrls, ExtCtrls, sha1Customised, md5Customised;

type

  { TfrmYaffi }

  TfrmYaffi = class(TForm)
    btnChooseImageName: TButton;
    Button1: TButton;
    btnStartImaging: TButton;
    btnAbort: TButton;
    cbdisks: TComboBox;
    comboHashChoice: TComboBox;
    ledtImageHashA: TLabeledEdit;
    ledtComputedHashB: TEdit;
    GroupBox1: TGroupBox;
    ImageList1: TImageList;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    ledtComputedHashA: TLabeledEdit;
    ledtImageHashB: TLabeledEdit;
    ledtImageName: TLabeledEdit;
    ledtSeizureRef: TLabeledEdit;
    ledtSelectedItem: TLabeledEdit;
    lt: TLabel;
    ls: TLabel;
    lm: TLabel;
    lv: TLabel;
    memNotes: TMemo;
    SaveImageDialog: TSaveDialog;
    TreeView1: TTreeView;

    // Two procedures below contributed by Paweld :
    // http://forum.lazarus.freepascal.org/index.php/topic,28560.0.html
    procedure btnAbortClick(Sender: TObject);
    procedure btnStartImagingClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure btnChooseImageNameClick(Sender: TObject);
    procedure cbdisksChange(Sender: TObject);
    procedure TreeView1SelectionChanged(Sender: TObject);
    function Stop : boolean;
    function InitialiseHashChoice(Sender : TObject) : Integer;
  private
    { private declarations }
  public

    { public declarations }
  end;

var
  frmYaffi: TfrmYaffi;
  PhyDiskNode, PartitionNoNode, DriveLetterNode           : TTreeNode;

  {$ifdef Windows}
  // These four functions are needed for traversing the attached disks in Windows.
  // Yes, all these for just that!! The joy of Windows coding
  // Credit to RRUZ at SO : https://stackoverflow.com/questions/12271269/how-can-i-correlate-logical-drives-and-physical-disks-using-the-wmi-and-delphi/12271778#comment49108167_12271778
  // https://theroadtodelphi.wordpress.com/2010/12/01/accesing-the-wmi-from-pascal-code-delphi-oxygene-freepascal/#Lazarus
  function ListDrives : string;
  function VarStrNull(const V:OleVariant):string;
  function GetWMIObject(const objectName: String): IDispatch;
  function VarArrayToStr(const vArray: variant): string;
  function WindowsImageDisk(hDiskHandle : THandle; DiskSize : Int64; HashChoice : Integer; hImageName : THandle) : Int64;
  function GetDiskLengthInBytes(hSelectedDisk : THandle) : Int64;

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
  TreeView1.Items.Clear;
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

procedure TfrmYaffi.btnAbortClick(Sender: TObject);
begin
  Stop;
end;

function TfrmYaffi.Stop : boolean;
begin
  result := true;
end;

procedure TfrmYaffi.btnChooseImageNameClick(Sender: TObject);
begin
  SaveImageDialog.Execute;
  ledtImageName.Text:= SaveImageDialog.Filename;
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

procedure TfrmYaffi.TreeView1SelectionChanged(Sender: TObject);
var
  DriveLetter : string;
  PosToStartFrom : Integer;
begin
   if Sender is TTreeView then
   begin
    if  (TTreeView(Sender).Selected.Text = 'Physical Disk')
      or (TTreeView(Sender).Selected.Text = 'Partition No')
        or (TTreeView(Sender).Selected.Text = 'Drive Letter') then
          ledtSelectedItem.Text := '...'
    else
    // If the user Chooses "Drive E:", adjust the selection to "E:" for the Thandle initiation
    // We just copy the characters following "Drive ".
    if Pos('Drive', TTreeView(Sender).Selected.Text) > 0 then
      begin
       PosToStartFrom := 6;
       DriveLetter := '\\?\'+Trim(Copy(TTreeView(Sender).Selected.Text, 6, 3));
       ledtSelectedItem.Text := DriveLetter;
      end
    else
      ledtSelectedItem.Text := (TTreeView(Sender).Selected.Text);
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
  DeviceID, Val1, Val2, Val3 : widestring;
  s              : widestring;

begin;
  Result:='';
  Val1 := '';
  Val2 := '';
  Val3 := '';

  frmYAFFI.Treeview1.Images := frmYAFFI.ImageList1;
  PhyDiskNode     := frmYAFFI.TreeView1.Items.Add(nil,'Physical Disk') ;
  PhyDiskNode.ImageIndex := 0;

  PartitionNoNode := frmYAFFI.TreeView1.Items.Add(nil,'Partition No') ;
  PartitionNoNode.ImageIndex := 1;

  DriveLetterNode := frmYAFFI.TreeView1.Items.Add(nil,'Drive Letter') ;
  DriveLetterNode.ImageIndex := 2;

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

function GetDiskLengthInBytes(hSelectedDisk : THandle) : Int64;
const
  // These are defined at the MSDN.Microsoft.com website for DeviceIOControl
  // and https://forum.tuts4you.com/topic/22361-deviceiocontrol-ioctl-codes/
  {
  IOCTL_DISK_GET_DRIVE_GEOMETRY      = $0070000
  IOCTL_DISK_GET_PARTITION_INFO      = $0074004
  IOCTL_DISK_SET_PARTITION_INFO      = $007C008
  IOCTL_DISK_GET_DRIVE_LAYOUT        = $007400C
  IOCTL_DISK_SET_DRIVE_LAYOUT        = $007C010
  IOCTL_DISK_VERIFY                  = $0070014
  IOCTL_DISK_FORMAT_TRACKS           = $007C018
  IOCTL_DISK_REASSIGN_BLOCKS         = $007C01C
  IOCTL_DISK_PERFORMANCE             = $0070020
  IOCTL_DISK_IS_WRITABLE             = $0070024
  IOCTL_DISK_LOGGING                 = $0070028
  IOCTL_DISK_FORMAT_TRACKS_EX        = $007C02C
  IOCTL_DISK_HISTOGRAM_STRUCTURE     = $0070030
  IOCTL_DISK_HISTOGRAM_DATA          = $0070034
  IOCTL_DISK_HISTOGRAM_RESET         = $0070038
  IOCTL_DISK_REQUEST_STRUCTURE       = $007003C
  IOCTL_DISK_REQUEST_DATA            = $0070040
  IOCTL_DISK_CONTROLLER_NUMBER       = $0070044
  IOCTL_DISK_GET_PARTITION_INFO_EX   = $0070048
  IOCTL_DISK_SET_PARTITION_INFO_EX   = $007C04C
  IOCTL_DISK_GET_DRIVE_LAYOUT_EX     = $0070050
  IOCTL_DISK_SET_DRIVE_LAYOUT_EX     = $007C054
  IOCTL_DISK_CREATE_DISK             = $007C058
  IOCTL_DISK_GET_LENGTH_INFO         = $007405C  // Our constant...
  SMART_GET_VERSION                  = $0074080
  SMART_SEND_DRIVE_COMMAND           = $007C084
  SMART_RCV_DRIVE_DATA               = $007C088
  IOCTL_DISK_GET_DRIVE_GEOMETRY_EX   = $00700A0
  IOCTL_DISK_UPDATE_DRIVE_SIZE       = $007C0C8
  IOCTL_DISK_GROW_PARTITION          = $007C0D0
  IOCTL_DISK_GET_CACHE_INFORMATION   = $00740D4
  IOCTL_DISK_SET_CACHE_INFORMATION   = $007C0D8
  IOCTL_DISK_GET_WRITE_CACHE_STATE   = $00740DC
  IOCTL_DISK_DELETE_DRIVE_LAYOUT     = $007C100
  IOCTL_DISK_UPDATE_PROPERTIES       = $0070140
  IOCTL_DISK_FORMAT_DRIVE            = $007C3CC
  IOCTL_DISK_SENSE_DEVICE            = $00703E0
  IOCTL_DISK_INTERNAL_SET_VERIFY     = $0070403
  IOCTL_DISK_INTERNAL_CLEAR_VERIFY   = $0070407
  IOCTL_DISK_INTERNAL_SET_NOTIFY     = $0070408
  IOCTL_DISK_CHECK_VERIFY            = $0074800
  IOCTL_DISK_MEDIA_REMOVAL           = $0074804
  IOCTL_DISK_EJECT_MEDIA             = $0074808
  IOCTL_DISK_LOAD_MEDIA              = $007480C
  IOCTL_DISK_RESERVE                 = $0074810
  IOCTL_DISK_RELEASE                 = $0074814
  IOCTL_DISK_FIND_NEW_DEVICES        = $0074818
  IOCTL_DISK_GET_MEDIA_TYPES         = $0070C00
  }

  // For physical disk access
  IOCTL_DISK_GET_LENGTH_INFO  = $0007405C;

    type
  TDiskLength = packed record
    Length : Int64;
  end;

var
  ByteSize: int64;
  SourceDevice : string;
  BytesReturned: DWORD;
  DLength: TDiskLength;

begin
  ByteSize      := 0;
  BytesReturned := 0;
  SourceDevice  := frmYaffi.ledtSelectedItem.Text;
  if not DeviceIOControl(hSelectedDisk, IOCTL_DISK_GET_LENGTH_INFO, nil, 0,
         @DLength, SizeOf(TDiskLength), BytesReturned, nil) then
         raise Exception.Create('Unable to initiate IOCTL_DISK_GET_LENGTH_INFO.');

  if DLength.Length > 0 then ByteSize := DLength.Length;
  //ShowMessage(IntToStr(ByteSize));
  result := ByteSize;
end;

// Assigns numeric value to hash algorithm choice to make if else statements used later, faster
function TfrmYaffi.InitialiseHashChoice(Sender : TObject) : Integer;
begin

  if comboHashChoice.Text = 'MD5' then
   begin
     result := 1;
   end
  else if comboHashChoice.Text = 'SHA-1' then
   begin
    result := 2;
   end
  else if comboHashChoice.Text = 'Use Both' then
   begin
    result := 3;
   end
  else if comboHashChoice.Text = 'Use None' then
   begin
    result := 4;
   end
  else
  begin
    ShowMessage('Choose Hash Algorithm');
    result := -1;
    exit;
  end;
end;

procedure TfrmYaffi.btnStartImagingClick(Sender: TObject);
const
  // These values are needed for For FSCTL_ALLOW_EXTENDED_DASD_IO to work properly
  // on logical volumes. They are sourced from
  // https://github.com/magicmonty/delphi-code-coverage/blob/master/3rdParty/JCL/jcl-2.3.1.4197/source/windows/JclWin32.pas
  FILE_DEVICE_FILE_SYSTEM = $00000009;
  FILE_ANY_ACCESS = 0;
  METHOD_NEITHER = 3;
  FSCTL_ALLOW_EXTENDED_DASD_IO = ((FILE_DEVICE_FILE_SYSTEM shl 16)
                                   or (FILE_ANY_ACCESS shl 14)
                                   or (32 shl 2) or METHOD_NEITHER);

var
  SourceDevice, strImageName              : widestring;
  hSelectedDisk, hImageName               : THandle;
  ExactDiskSize, SectorCount, ImageResult : Int64;
  HashChoice                              : integer;
  slImagingLog                            : TStringList;
  BytesReturned                           : DWORD;

begin
  BytesReturned := 0;
  ExactDiskSize := 0;
  SectorCount   := 0;
  ImageResult   := 0;
  HashChoice    := -1;
  SourceDevice  := ledtSelectedItem.Text;
  strImageName  := ledtImageName.Text;
  // Determine what hash algorithm to use. MD5 = 1, SHA-1 = 2, Use Both = 3, Use Non = 4. -1 is false
  HashChoice := frmYaffi.InitialiseHashChoice(nil);
  if HashChoice = -1 then abort;

  // Create handle to source disk. Abort if fails
  // Note that 'FILE_SHARE_READ OR FILE_SHARE_WRITE' doesn't mean "allow writes to disk"
  hSelectedDisk := CreateFileW(PWideChar(SourceDevice), FILE_READ_DATA,
                   FILE_SHARE_READ OR FILE_SHARE_WRITE, nil, OPEN_EXISTING, FILE_FLAG_SEQUENTIAL_SCAN, 0);

  // Check if handle is valid before doing anything else
  if hSelectedDisk = INVALID_HANDLE_VALUE then
  begin
    RaiseLastOSError;
  end
  else
    begin
    // If chosen device is logical volume, initiate FSCTL_ALLOW_EXTENDED_DASD_IO
    // to ensure all sectors acquired, even those protected by the OS normally.
    // See:
    // https://stackoverflow.com/questions/30671387/unable-to-read-final-few-kb-of-logical-drives-on-windows-7-64-bit/30719570#30719570
    // https://msdn.microsoft.com/en-us/library/windows/desktop/aa363147%28v=vs.85%29.aspx
    // https://msdn.microsoft.com/en-us/library/windows/desktop/aa364556%28v=vs.85%29.aspx
    if Pos('?', SourceDevice) > 0 then
    begin
      if not DeviceIOControl(hSelectedDisk, FSCTL_ALLOW_EXTENDED_DASD_IO, nil, 0,
           nil, 0, BytesReturned, nil) then
             raise Exception.Create('Unable to initiate FSCTL_ALLOW_EXTENDED_DASD_IO.');
    end;
    // Now create handle to image file. Abort if fails
    hImageName := CreateFileW(PWideChar(strImageName), GENERIC_WRITE,
                  FILE_SHARE_WRITE, nil, CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, 0);

    // Check if handle to image file is valid before doing anything else
    if hImageName = INVALID_HANDLE_VALUE then
      begin
        RaiseLastOSError;
      end
    else
      begin
        // Source disk and image file handles are OK. So attempt imaging
        // First, compute the exact disk size of the disk or volume
        ExactDiskSize := GetDiskLengthInBytes(hSelectedDisk);
        SectorCount   := ExactDiskSize DIV 512;
        // Now image the chosen device, passing the exact size and
        // hash selection and Image name
        ImageResult   := WindowsImageDisk(hSelectedDisk, ExactDiskSize, HashChoice, hImageName);

        // Log the actions
        try
          slImagingLog := TStringList.Create;
          slImagingLog.Add('Image name : ' + ExtractFileName(strImageName));
          slImagingLog.Add('Full path: ' + ledtImageName.Text);
          slImagingLog.Add('Device ID : ' + SourceDevice);
          slImagingLog.Add('Hashing Algorithm : ' + comboHashChoice.Text);
          slImagingLog.Add('Hash(es) of source media : ' + ledtComputedHashA.Text + ' ' + ledtComputedHashB.Text);
          slImagingLog.Add('Hash(es) of image : ' + ledtImageHashA.Text + ' ' + ledtImageHashB.Text);
          slImagingLog.Add(ledtSeizureRef.Text);
          slImagingLog.Add(memNotes.Text);
        finally
          slImagingLog.SaveToFile(IncludeTrailingPathDelimiter(ExtractFilePath(SaveImageDialog.FileName)) + 'ImageLog.txt');
          slImagingLog.free;
        end;

        // Release existing handles to disk and image
        try
          if (hSelectedDisk > 0) or (hSelectedDisk = INVALID_HANDLE_VALUE) then
            CloseHandle(hSelectedDisk);
          if (hImageName > 0) or (hImageName = INVALID_HANDLE_VALUE) then
            CloseHandle(hImageName);
        finally
        If ImageResult = ExactDiskSize then
          begin
           ShowMessage('Imaged OK. ' + IntToStr(ExactDiskSize)+' bytes captured.');
          end;
        end;
        {
        if not hDiskHandle = INVALID_HANDLE_VALUE then CloseHandle(hDiskHandle);
        if not hImageName = INVALID_HANDLE_VALUE then CloseHandle(hImageName);
        }
      end;
    end;
end;

// Images the disk and returns the number of bytes successfully imaged
function WindowsImageDisk(hDiskHandle : THandle; DiskSize : Int64; HashChoice : Integer; hImageName : THandle) : Int64;
var
  Buffer                   : array [0..65535] of Byte;   // 1048576 (1Mb) or 262144 (240Kb) or 131072 (120Kb buffer) or 65536 (64Kb buffer)
  // Hash digests for disk reading
  MD5ctxDisk               : TMD5Context;
  SHA1ctxDisk              : TSHA1Context;
  MD5Digest                : TMD5Digest;
  SHA1Digest               : TSHA1Digest;
  // Hash digests for image reading
  MD5ctxImage              : TMD5Context;
  SHA1ctxImage             : TSHA1Context;
  MD5DigestImage           : TMD5Digest;
  SHA1DigestImage          : TSHA1Digest;

  BytesRead                : integer;

  NewPos, SectorCount,
  TotalBytesRead, BytesWritten, TotalBytesWritten : Int64;

begin
  BytesRead           := 0;
  BytesWritten        := 0;
  TotalBytesRead      := 0;
  TotalBytesWritten   := 0;
  NewPos              := 0;

    try
      // Initialise the hash digests in accordance with the users chosen algorithm
      if HashChoice = 1 then
        begin
        MD5Init(MD5ctxDisk);
        MD5Init(MD5ctxImage);
        end
        else if HashChoice = 2 then
          begin
          SHA1Init(SHA1ctxDisk);
          SHA1Init(SHA1ctxImage);
          end
            else if HashChoice = 3 then
              begin
                MD5Init(MD5ctxDisk);
                MD5Init(MD5ctxImage);
                SHA1Init(SHA1ctxDisk);
                SHA1Init(SHA1ctxImage);
              end
              else if HashChoice = 4 then
                begin
                 // No hashing initiliased
                end;
      // Now to seek to start of device
      FileSeek(hDiskHandle, 0, 0);
        repeat
          // Read device in buffered segments. Hash the disk and image portions as we go
          BytesRead     := FileRead(hDiskHandle, Buffer, SizeOf(Buffer));
          BytesWritten  := FileWrite(hImageName, Buffer, BytesRead);
          if BytesRead = -1 then
            begin
              RaiseLastOSError;
              exit;
            end;
          inc(TotalBytesRead, BytesRead);
          inc(TotalBytesWritten, BytesWritten);

          // Hash the bytes read and\or written using the algorithm required
          // If the user sel;ected no hashing, break the loop immediately; faster
          if HashChoice = 4 then
            begin
             // No hashing initiliased
            end
            else if HashChoice = 1 then
              begin
              MD5Update(MD5ctxDisk, Buffer, BytesRead);
              MD5Update(MD5ctxImage, Buffer, BytesWritten);
              end
                else if HashChoice = 2 then
                  begin
                  SHA1Update(SHA1ctxDisk, Buffer, BytesRead);
                  SHA1Update(SHA1ctxImage, Buffer, BytesWritten);
                  end
                    else if HashChoice = 3 then
                      begin
                        MD5Update(MD5ctxDisk, Buffer, BytesRead);
                        MD5Update(MD5ctxImage, Buffer, BytesWritten);
                        SHA1Update(SHA1ctxDisk, Buffer, BytesRead);
                        SHA1Update(SHA1ctxImage, Buffer, BytesWritten);
                      end;

        Application.ProcessMessages;
        until (TotalBytesRead = DiskSize);// or (frmYAFFI.Stop = true);
    finally
      // Compute the final hash value
      if HashChoice = 1 then
        begin
        MD5Final(MD5ctxDisk, MD5Digest);
        MD5Final(MD5ctxImage, MD5DigestImage);
        frmYaffi.ledtComputedHashA.Text := Uppercase(MD5Print(MD5Digest));
        end
          else if HashChoice = 2 then
            begin
            SHA1Final(SHA1ctxDisk, SHA1Digest);
            SHA1Final(SHA1ctxImage, SHA1DigestImage);
            frmYaffi.ledtComputedHashA.Text := Uppercase(SHA1Print(SHA1Digest));
            end
              else if HashChoice = 3 then
                begin
                 MD5Final(MD5ctxDisk, MD5Digest);
                 MD5Final(MD5ctxImage, MD5DigestImage);
                 SHA1Final(SHA1ctxDisk, SHA1Digest);
                 SHA1Final(SHA1ctxImage, SHA1DigestImage);
                 frmYaffi.ledtComputedHashA.Text := Uppercase('MD5: ' + MD5Print(MD5Digest));
                 frmYaffi.ledtComputedHashB.Visible := true;
                 frmYaffi.ledtComputedHashB.Enabled := true;
                 frmYaffi.ledtComputedHashB.Text := Uppercase('SHA-1: ' + SHA1Print(SHA1Digest));
                end
                else if HashChoice = 4 then
                  begin
                   frmYaffi.ledtComputedHashA.Text := Uppercase('No hash computed');
                  end;
        // If no hashing or single algorithm hashing is done, this AND comparison will
        // still be true but only one value will be printed for single algorithm hashing
        // or both values for multiple, or no hashes for no hashing.
        if (SHA1Print(SHA1Digest) = SHA1Print(SHA1DigestImage)) and (MD5Print(MD5Digest) = MD5Print(MD5DigestImage)) then
          begin
             frmYaffi.ledtImageHashA.Enabled:= true;
             frmYaffi.ledtImageHashA.Visible:= true;
             frmYaffi.ledtImageHashA.Text := 'MD5: ' + MD5Print(MD5DigestImage);
             frmYaffi.ledtImageHashB.Enabled:= true;
             frmYaffi.ledtImageHashB.Visible:= true;
             frmYaffi.ledtImageHashB.Text := 'SHA-1 : ' + SHA1Print(SHA1DigestImage);
          end;
      result := TotalBytesRead;
    end;
end;

{$endif}
end.

