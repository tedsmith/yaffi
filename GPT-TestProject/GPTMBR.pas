unit GPTMBR;

{$mode objfpc}{$H+}

interface

uses
  {$ifdef Windows}
  Windows, SysUtils, Dialogs, Forms, Classes;
  {$endif}
  {$ifdef UNIX}
  SysUtils;
  {$endif}
type

  // the first 512 byte Protected MBR that came when GPT was introduced
  // At offset 446 starts some of the GPT data
  TProtectiveMBR = record
      StartOfSector : array [0..445] of byte; // The first 446 bytes are MBR specific
      BootIndicator : byte;                   // One hex byte
      StartingHead : byte;                    // One hex byte
      StartingSector : byte;                  // One hex byte
      StartingCylinder : byte;                // One hex byte
      SystemID : byte;                        // One hex byte. Should be 0xEE for GPT
      EndingHead : byte;                      // One hex byte
      EndingSector : byte;                    // One hex byte
      EndingCylinder : byte;                  // One hex byte
      StartLBA : integer;                     // 4 byte integer
      SizeInLBA : integer;                    // 4 byte integer
      EndOfSector : array [0..49] of byte     // The last 50 bytes
  end;

  TGUIDPartitionTableHeader = record
      Signature : array [0..7] of byte;       // 8 hex digits, starting 0x45 and ending 0x54
      RevisionNo : array [0..3] of byte;      // 4 hex bytes
      HeaderSize : integer;                   // 32-bit 4 byte integer, and should equal 92
      HeaderCRC32 : integer;                  // to be displayed as hex but a 4 byte integer
      EmptyData : integer;                    // 4 bytes to be ignored
      PrimaryLBA : Int64;                     // 8 byte integer that should equal 1
      BackupLBA : Int64;                      // 8 byte integer
      FirstUseableLBA : Int64;                // 8 bytes
      LastUseableLBA : Int64;                 // 8 bytes
      DiskGUID : array [0..15] of byte;       // 16 hex values
      PartitionEntryLBA : Int64;              // Should equal 2
      MaxPossiblePartitions : integer;        // 4 bytes
      SizeOfPartitionEntry : integer;         // 4 bytes
      PartitionEntryArrayCRC32 : integer;     // 4 bytes displayed as hex
      // 92 bytes to here. Remaining sector size is 420
      EndOfSector : array [0..419] of byte;
  end;

  TGUIDPartitionTableEntry = record
      PartitionTypeGUID : array [0..15] of byte;   // 16 byte hex string
      UniquePartitionGUID : array [0..15] of byte; // 16 byte hex string
      StartingLBA : Int64;                         // 8 byte integer
      EndingLBA : Int64;                           // 8 byte integer
      AttributeBits : array [0..7] of byte;       // 8 byte hex string
      PartitionName : array [0..35] of widechar;  // 36 byte Unicode string
      EndOfSector : array [0..419] of byte;        // assuming 512 sector size, the first records = 92 bytes. So 420 left as padding
  end;

// QueryGPT parses GPT disks, if GPT disks are detected. It calls
// ReadProtectiveMBR and ReadGUIDPartitionTableHeader
function QueryGPT(SelectedDisk : widestring; ExactSectorSize : Integer) : ansistring;
function ReadProtectiveMBR(Drive : THandle; ExactSectorSize : Integer) : ansistring;
function ReadGUIDPartitionTableHeader(Drive : THandle; ExactSectorSize : Integer) : ansistring;

implementation

// Read in the Protective MBR - the kind created by GPT disks, not normal MBRs
function ReadProtectiveMBR(Drive : THandle; ExactSectorSize : Integer) : ansistring;
var
  BytesRead, DiskPos : integer;
  ProtectiveMBR : TProtectiveMBR;
  Tmp : ansistring;
begin
  result := 'Failed';
  BytesRead := -1;
  DiskPos := -1;

  //FileSeek(Drive, 0, 0);
  DiskPos := FileSeek(Drive, 0, fsFromBeginning);

  if DiskPos > -1 then
    begin
      FillChar(ProtectiveMBR, SizeOf(ProtectiveMBR), 0);
      // TODO implement IOCTL_DISK_GET_DRIVE_GEOMETRY to lookup bytes per sector
      // because FileRead is sector aligned, so you must read complete sectors
      BytesRead := FileRead(Drive, ProtectiveMBR, 512);
      if BytesRead > -1 then
          begin
            tmp :=' Boot ID : '            + IntToHex(ProtectiveMBR.BootIndicator,2) +
                  ', Starting Head : '     + IntToHex(ProtectiveMBR.StartingHead, 2) +
                  ', Starting Sector : '   + IntToHex(ProtectiveMBR.StartingSector, 2) +
                  ', Starting Cylinder : ' + IntToHex(ProtectiveMBR.StartingCylinder, 2) +
                  ', System ID : '         + IntToHex(ProtectiveMBR.SystemID,2) +
                  ', Ending Head : '       + IntToHex(ProtectiveMBR.EndingHead, 2) +
                  ', Ending Sector : '     + IntToHex(ProtectiveMBR.EndingSector, 2) +
                  ', Ending Cylinder : '   + IntToHex(ProtectiveMBR.EndingCylinder, 2) +
                  ', Size in LBA : '       + IntToStr(ProtectiveMBR.SizeInLBA) +
                  ', Start LBA : '         + IntToStr(ProtectiveMBR.StartLBA);
          result := tmp;
          end
      else RaiseLastOSError; // BytesRead = -1
    end
  else RaiseLastOSError; // DiskPos = -1
end;


// Read in the GUID Partition Table Header
function ReadGUIDPartitionTableHeader(Drive : THandle; ExactSectorSize : Integer) : ansistring;
var
  GUIDPartitionTableHeader : TGUIDPartitionTableHeader;

  i, BytesRead, DiskPos : integer;

  Tmp, Signature, RevisionNo, DiskGUID, HeaderSize, HeaderCRC32, PrimaryLBA,
    BackupLBA, FirstUseableLBA, LastUsableLBA, PartitionEntryLBA,
    MaxPossiblePartitions, SizeOfPartitionEntry, PartitionEntryCRC32 : ansistring;
begin
  result := 'false';
  BytesRead := -1;
  DiskPos := -1;
  i := 0;
  //FileSeek(Drive, 0, 0);
  // Move read point to offset 512, i.e. offset zero of sector two (if 512 byte sector aligned)
  DiskPos := FileSeek(Drive, 512, fsFromBeginning);

  if DiskPos > -1 then
    begin
      FillChar(GUIDPartitionTableHeader, SizeOf(GUIDPartitionTableHeader), 0);
      // TODO implement IOCTL_DISK_GET_DRIVE_GEOMETRY to lookup bytes per sector
      // because FileRead is sector aligned, so you must read complete sectors
      BytesRead := FileRead(Drive, GUIDPartitionTableHeader, 512);

      if BytesRead > -1 then
        begin

          for i := 0 to 7 do
          begin
            Signature := Signature + IntToHex(GUIDPartitionTableHeader.Signature[i], 2);
          end;

          for i := 0 to 3 do
          begin
            RevisionNo := RevisionNo + IntToHex(GUIDPartitionTableHeader.RevisionNo[i], 2);
          end;

          HeaderSize      := IntToStr(GUIDPartitionTableHeader.HeaderSize);
          HeaderCRC32     := IntToHex(GUIDPartitionTableHeader.HeaderCRC32, 2);
          PrimaryLBA      := IntToStr(GUIDPartitionTableHeader.PrimaryLBA);
          BackupLBA       := IntToStr(GUIDPartitionTableHeader.BackupLBA);
          FirstUseableLBA := IntToStr(GUIDPartitionTableHeader.FirstUseableLBA);
          LastUsableLBA   := IntToStr(GUIDPartitionTableHeader.LastUseableLBA);

          for i := 0 to 15 do
          begin
            DiskGUID := DiskGUID + IntToHex(GUIDPartitionTableHeader.DiskGUID[i], 2);
          end;

          PartitionEntryLBA      := IntToStr(GUIDPartitionTableHeader.PartitionEntryLBA);
          MaxPossiblePartitions  := IntToStr(GUIDPartitionTableHeader.MaxPossiblePartitions);
          SizeOfPartitionEntry   := IntToStr(GUIDPartitionTableHeader.SizeOfPartitionEntry);
          PartitionEntryCRC32    := IntToHex(GUIDPartitionTableHeader.PartitionEntryArrayCRC32, 2);


          result := ('Signature : '              + Signature             +
                  ', Rev No : '               + RevisionNo            +
                  ', Header Size : '          + HeaderSize            +
                  ', Header CRC32 : '         + HeaderCRC32           +
                  ', Primary LBA : '          + PrimaryLBA            +
                  ', Backup LBA : '           + BackupLBA             +
                  ', First Useable LBA : '    + FirstUseableLBA       +
                  ', Last Useable LBA : '     + LastUsableLBA         +
                  ', Disk GUID : '            + DiskGUID              +
                  ', Partition Entry LBA : '  + PartitionEntryLBA     +
                  ', Max No of Partitions : ' + MaxPossiblePartitions +
                  ', Partition Entry Size : ' + SizeOfPartitionEntry  +
                  ', Partition Entry CRC32 : '+ PartitionEntryCRC32)  ;
        end
      else
      begin
        result := 'false';
        RaiseLastOSError; // BytesRead = -1
      end;
    end
  else
  begin
    result := 'false';
    RaiseLastOSError; // DiskPos = -1
  end;
end;

// Lookup the data in the third part of the GPT - the partition table entry itself
function ReadGUIDPartitionTableEntry(Drive : THandle; ExactSectorSize : Integer) : ansistring;
var
  GUIDPartitionTableEntry : TGUIDPartitionTableEntry;
  i, BytesRead, DiskPos : integer;
  PartitionName : ansistring;
  PartitionTypeGUID, UniquePartitionGUID, StartingLBA, EndingLBA, AttributeBits : ansistring;
begin
    PartitionTypeGUID := '';
    UniquePartitionGUID := '';
    StartingLBA := '';
    EndingLBA := '';
    AttributeBits := '';
    result := 'false';
    BytesRead := -1;
    DiskPos := -1;
    i := 0;
    //FileSeek(Drive, 0, 0);
    // Move read point to offset 1024, i.e. offset zero of sector three (if 512 byte sector aligned)
    DiskPos := FileSeek(Drive, 1024, fsFromBeginning);    //1535

    if DiskPos > -1 then
      begin
        FillChar(GUIDPartitionTableEntry, SizeOf(GUIDPartitionTableEntry), 0);
        // TODO implement IOCTL_DISK_GET_DRIVE_GEOMETRY to lookup bytes per sector
        // because FileRead is sector aligned, so you must read complete sectors
        BytesRead := FileRead(Drive, GUIDPartitionTableEntry, 512);

        if BytesRead > -1 then
          begin
            for i := 0 to 15 do
            begin
              PartitionTypeGUID := PartitionTypeGUID + IntToHex(GUIDPartitionTableEntry.PartitionTypeGUID[i], 1);
            end;

            for i := 0 to 15 do
            begin
              UniquePartitionGUID := UniquePartitionGUID + IntToHex(GUIDPartitionTableEntry.UniquePartitionGUID[i], 1);
            end;

            StartingLBA     := IntToStr(GUIDPartitionTableEntry.StartingLBA);
            EndingLBA       := IntToStr(GUIDPartitionTableEntry.EndingLBA);

            for i := 0 to 7 do
            begin
              AttributeBits  := AttributeBits + IntToHex(GUIDPartitionTableEntry.AttributeBits[i], 1);
            end;

            PartitionName := WideCharToString(@GUIDPartitionTableEntry.PartitionName);

            result := ('Partition Type GUID : ' + PartitionTypeGUID   +
                    ', UniquePartitionGUID  : ' + UniquePartitionGUID +
                    ', Starting LBA : '         + StartingLBA         +
                    ', Ending LBA : '           + EndingLBA           +
                    ', Attribute Bits : '       + AttributeBits       +
                    ', Partition Name : '       + PartitionName);
          end
        else
        begin
          result := 'false';
          RaiseLastOSError; // BytesRead = -1
        end;
      end
    else
    begin
      result := 'false';
      RaiseLastOSError; // DiskPos = -1
    end;
  end;

// Returns the partitioning style of a physical disk by utilising sector 0
// offset 446 for MBR or offset 38 of sector 1 for GPT. Returns resulting
// text string and Windows signature
function QueryGPT(SelectedDisk : widestring; ExactSectorSize : Integer) : ansistring;
var
  Drive: widestring;
  hDevice: THandle;
  ProtectedMBRData, GUIDPartitionTableHeader, GUIDPartitionTableEntry  : ansistring;

begin
  result := '';
  Drive := SelectedDisk;
  // This particular handle assignment does not require admin rights as it allows
  // simply to query the device attributes without accessing actual disk data as such

  hDevice := FileOpen(PWideChar(Drive), fmOpenRead);
  {
  The handle below is Windows specific. No good for cross platform.
  hDevice := CreateFileW(PWideChar(Drive),
                             FILE_READ_DATA,
                             FILE_SHARE_READ AND FILE_SHARE_WRITE,
                             nil,
                             OPEN_EXISTING,
                             FILE_FLAG_SEQUENTIAL_SCAN,
                             0);
  }
  if hDevice = -1 then   // or INVALID_HANDLE_VALUE when using Windows API call
    begin
      RaiseLastOSError;  // disk handle opening failed
    end
  else
    begin
      ProtectedMBRData          := ReadProtectiveMBR(hDevice, ExactSectorSize);
      GUIDPartitionTableHeader  := ReadGUIDPartitionTableHeader(hDevice, ExactSectorSize);
      GUIDPartitionTableEntry   := ReadGUIDPartitionTableEntry(hDevice, ExactSectorSize);
      result := ProtectedMBRData + GUIDPartitionTableHeader + GUIDPartitionTableEntry;
      CloseHandle(hDevice);
    end;
end;

end.

