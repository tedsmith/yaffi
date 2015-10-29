unit textsearch;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  strutils, LCLIntf;

type

  TCharUpCaseTable = array [Char] of Char;  // For use by InsensPosEx function

  { TfrmTextSearch }

  TfrmTextSearch = class(TForm)
    btnDontUse: TButton;
    btnTextSearchCancel: TButton;
    btnTextSearchOK: TButton;
    cbMatchCase: TCheckBox;
    cbHexSearch: TCheckBox;
    Memo1: TMemo;
    OpenDialog1: TOpenDialog;
    procedure btnTextSearchCancelClick(Sender: TObject);
    procedure btnTextSearchOKClick(Sender: TObject);
    procedure btnDontUseClick(Sender: TObject);
    procedure cbHexSearchClick(Sender: TObject);
    procedure Memo1Enter(Sender: TObject);
    private
    { private declarations }
  public
    DoCaseSensitive, DoHexSearch, DoTextOrHexSearch : boolean;

  end;

var
  frmTextSearch: TfrmTextSearch;
  slSearchList : TStringList;
  CharUpCaseTable: TCharUpCaseTable;

  function GetCaseSensitivityDecision : boolean;
  function GetHexSearchDecision : boolean;
  function ByteArrayToString(const ByteArray: array of Byte): AnsiString;
  function PosCaseInsensitive(const AText, ASubText: string): Integer;
  function IndexOfDWord(const buf: pointer; len:SizeInt; b:DWord {or QWord }):SizeInt;
  function Hex2DecBig(const S: string): QWORD;
  function SearchListToStringList : TStringList;
  procedure InitCharUpCaseTable(var Table: TCharUpCaseTable);
  function InsensPosEx(const SubStr, S: string; Offset: Integer = 1): Integer;


implementation

uses uYaffi;

{$R *.lfm}

{ TfrmTextSearch }

procedure TfrmTextSearch.btnTextSearchCancelClick(Sender: TObject);
begin
  // We know the user does not want to do a search of any kind
  DoTextOrHexSearch := false;
  // Set the search mode in main YAFFI interface to disabled
   frmYaffi.toggleSearchMode.State := cbUnChecked;
   frmYaffi.toggleSearchMode.Enabled := false;
   frmYaffi.toggleSearchMode.Caption := 'Search Mode: OFF';
  // Hide the form
  frmTextSearch.Close;
end;

procedure TfrmTextSearch.btnTextSearchOKClick(Sender: TObject);
begin
  // We know the user wants to do a search of some kind
  DoTextOrHexSearch := true;
  // Check whether the search is to be case sensitive or not
  DoCaseSensitive := GetCaseSensitivityDecision;
  // Check whether the search is to be for hex bytes or not
  DoHexSearch := GetHexSearchDecision;
  // Put the content of the memo list into a stringlist
  slSearchList := SearchListToStringList;
  // Set the search mode in main YAFFI interface to enabled
  frmYaffi.toggleSearchMode.State := cbChecked;
  frmYaffi.toggleSearchMode.Enabled := true;
  frmYaffi.toggleSearchMode.Caption := 'Search Mode: ON';
  // And now hide the form and return user to YAFFI interface
  frmTextSearch.Hide;
end;

function GetCaseSensitivityDecision : boolean;
begin
  Result := false;
  if frmTextSearch.cbMatchCase.Checked then result := true;
end;

function GetHexSearchDecision : boolean;
begin
  Result := false;
  if frmTextSearch.cbHexSearch.Checked then result := true;
end;

function SearchListToStringList : TStringList;
var
  i : integer;
begin
  i := 0;
  slSearchList := TStringList.Create;
  for i := 0 to frmTextSearch.Memo1.Lines.Count -1 do
   begin
     slSearchList.Add(frmTextSearch.Memo1.Lines[i]);
   end;
  Result := slSearchList;
end;

function ByteArrayToString(const ByteArray: array of Byte): AnsiString;
//http://stackoverflow.com/questions/19677946/converting-string-to-byte-array-wont-work
var
  I: Integer;
begin
  SetLength(Result, SizeOf(ByteArray));
  for I := 1 to SizeOf(ByteArray) do
    Result[I] := Chr(ByteArray[I - 1]);
end;

// IndexOfDWord is a customised version of IndexDWord, supplied to me by my friend Engkin
// and more optimised for rapid buffer search of 4 or 8 byte values
function IndexOfDWord(const buf: pointer; len:SizeInt; b:DWord {or QWord }):SizeInt;
var
  p,e:PDWord;
  pb: PByte absolute p;
begin
  Result := -1;
  p := PDWord(buf);
  e := PDWord(PtrUInt(buf) + len - 1 - SizeOf(DWord) {4 for DWord / 8 for QWord} );
  while (p <= e) do
  begin
    if (p^=b) then
      exit(PtrUInt(p)-PtrUInt(buf));
    inc(pb);
  end;
end;

// A bespoke version of Hex2Dec, which can't return values larger than DWORD (4 bytes)
// Hex2DecBig allows up to QWORD (twice as large as Int64), but the realistic
// max size is that of Int64 due to use of Val within StrToQword, i.e.
// 7fffffffffffffff : 9,223,372,036,854,775,807
function Hex2DecBig(const S: string): QWORD;
var
  HexStr: string;
begin
  if Pos('$',S)=0 then
    HexStr:='$'+ S
  else
    HexStr:=S;
  Result:=StrToQWord(HexStr);
end;

// Pos uses AnsiPos internally so bespoke version of Pos this is
// and used for finding search results when the user asks for no case sensitivity
Function PosCaseInsensitive(const AText, ASubText: string): Integer;
var
  s1, s2 : ansistring;
begin
  s1 := AnsiUppercase(ASubText);
  s2 :=    AnsiUppercase(AText);
  Result := AnsiPos(s2, s1);
end;

// Used by InsesnPosEx for conducting case insensitive searches of buffer
// From http://stackoverflow.com/a/1554544
procedure InitCharUpCaseTable(var Table: TCharUpCaseTable);
var
  n: cardinal;
begin
  for n := 0 to Length(Table) - 1 do
    Table[Char(n)] := Char(n);
  CharUpperBuff(@Table, Length(Table));   // CharUpperBuff is from LCLIntf unit
end;

// InsensPosEx is a fast case insensitive search function ported from Delphi by
// the LCLIntf unit allowing a starting offset to be specified.
// Used to repeat check a buffer for extra hits of the term, rather than moving
// on after PosCaseInsensitive finds the first hit
// From http://stackoverflow.com/a/1554544
function InsensPosEx(const SubStr, S: string; Offset: Integer = 1): Integer;
var
  n              :integer;
  SubStrLength   :integer;
  SLength        :integer;
label
  Fail;
begin
  SLength := length(s);
  if (SLength > 0) and (Offset > 0) then
    begin
    SubStrLength := length(SubStr);
    result := Offset;
    while SubStrLength <= SLength - result + 1 do
      begin
        for n := 1 to SubStrLength do
          if CharUpCaseTable[SubStr[n]] <> CharUpCaseTable[s[result + n - 1]] then
            goto Fail;
        exit;
  Fail:
        inc(result);
      end;
    end;
  result := 0;
end;

procedure TfrmTextSearch.btnDontUseClick(Sender: TObject);
var
  fs : TFileStream;
  TotalBytesRead, PositionFoundOnDisk, HexVal : Int64;
  BytesRead : LongInt;
  HexValAsDec : QWord;
  i, PositionFoundInBuffer : integer;
  PosInBufferOfHexValue : SizeInt;
  BufferA : array [0..32767] of byte; // the binary buffer read from disk
  SearchHitLocation : PChar;
  TextData : ansistring;
  CaseSensitive, HexSearch : Boolean;

begin
  i := 0;
  BytesRead := 0;
  TotalBytesRead := 0;
  PositionFoundInBuffer := 0;
  PositionFoundOnDisk := 0;
  HexVal := 0;
  HexValAsDec := 0;
  CaseSensitive := false;
  HexSearch := false;


  OpenDialog1.Execute;
  fs := TFileStream.Create(OpenDialog1.FileName, fmOpenRead);
  fs.Position := 0;

  //FillChar(BufferA,SizeOf(BufferA),0);
  while TotalBytesRead < fs.Size do
  repeat
    // Read the raw file
    BytesRead := fs.Read(BufferA, SizeOf(BufferA));
    if BytesRead = -1 then
      RaiseLastOSError
    else inc(TotalBytesRead, BytesRead);

    // Convert byte array to string
    TextData := ByteArrayToString(BufferA);
    // Do ANSI and Unicode search (Pos will deal with both)
    if CaseSensitive = true then
      // Do a case SENSITIVE search.
      begin
        for i := 0 to Memo1.Lines.Count -1 do
          begin
            if Pos(Trim(Memo1.Lines[i]), TextData) > 0 then
              begin
                PositionFoundInBuffer := Pos(Memo1.Lines[i], TextData);
                PositionFoundOnDisk := (TotalBytesRead - BytesRead) + (PositionFoundInBuffer -1);
                ShowMessage('found ' + Memo1.Lines[i] + ' at offset ' + IntToStr(PositionFoundOnDisk));
              end;
          end;
      end
    else if (CaseSensitive = false and HexSearch = false) then
    begin
      // Do a case INSENSITIVE search.
      for i := 0 to Memo1.Lines.Count -1 do
        begin
          if PosCaseInsensitive(Trim(Memo1.Lines[i]), TextData) > 0 then
              begin
                PositionFoundInBuffer := Pos(Memo1.Lines[i], TextData);
                PositionFoundOnDisk := (TotalBytesRead - BytesRead) + (PositionFoundInBuffer -1);
                ShowMessage('found ' + Memo1.Lines[i] + ' at offset ' + IntToStr(PositionFoundOnDisk));
              end;
        end;
    end
    else if cbHexSearch.Checked then
      begin
        for i := 0 to Memo1.Lines.Count -1 do
          begin
            // Take each hex string and convert to decimal
            // Up to 8 bytes allowed, but must not exceed 7fffffffffffffff
            // (the Int64 max of 9,223,372,036,854,775,807)
            HexValAsDec := Hex2DecBig(DelSpace(Memo1.Lines[i]));
            // Search for the integer representation using bespoke, fast, IndexOfDWord function
            PosInBufferOfHexValue := IndexOfDWord(@BufferA[0], Length(BufferA), SwapEndian(HexValAsDec)); //SwapEndian($4003E369)); //StrToInt('$' + Memo1.Lines[i]));
            PositionFoundOnDisk := (TotalBytesRead - BytesRead) + PosInBufferOfHexValue;
            ShowMessage(IntToStr(PositionFoundOnDisk));
          end;
      end;
  until TotalBytesRead = fs.size;
  ShowMessage(IntToStr(TotalBytesRead) + ' read. Done');
  fs.Free;
end;

// Uncheck and disable the case sensitivity tick box if hex search chosen
procedure TfrmTextSearch.cbHexSearchClick(Sender: TObject);
begin
  if cbHexSearch.Checked then
    begin
      cbMatchCase.Checked := false;
      cbMatchCase.Enabled := false;
    end;

  if not cbHexSearch.Checked then
    begin
      cbMatchCase.Enabled := true;
    end;
end;

procedure TfrmTextSearch.Memo1Enter(Sender: TObject);
begin
  Memo1.Clear;
end;


initialization
  // Used to initialise the upper case table as used by InsensPosEx
  // http://stackoverflow.com/a/1554544
  InitCharUpCaseTable(CharUpCaseTable);

end.

