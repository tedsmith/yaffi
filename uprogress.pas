unit uProgress;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, ExtCtrls;

type

  { TfrmProgress }

  TfrmProgress = class(TForm)
    GroupBox1: TGroupBox;
    lblPercent: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    lblTotalBytesSource: TLabel;
    lblTotalBytesRead: TLabel;
    ProgressBar1: TProgressBar;
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
  private
    { private declarations }
  public
    { public declarations }
  end;

var
  frmProgress: TfrmProgress;

implementation

uses
  uYaffi;
{$R *.lfm}

{ TfrmProgress }


procedure TfrmProgress.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  Label7.Caption:= 'Aborting...';
  frmYaffi.Stop:= true;
end;

end.

