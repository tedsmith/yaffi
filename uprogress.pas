unit uProgress;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls;

type

  { TfrmProgress }

  TfrmProgress = class(TForm)
    GroupBox1: TGroupBox;
    Label6: TLabel;
    Label7: TLabel;
    Label9: TLabel;
    lbllblTotalBytesSource: TLabel;
    lblTotalBytesRead: TLabel;
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  frmProgress: TfrmProgress;

implementation

{$R *.lfm}

end.

