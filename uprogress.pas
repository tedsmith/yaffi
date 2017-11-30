unit uProgress;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, StdCtrls,
  ComCtrls, ExtCtrls;

type

  { TfrmProgress }

  TfrmProgress = class(TForm)
    btnCloseProgressWindow: TButton;
    GroupBox1: TGroupBox;
    lblPercent: TLabel;
    lblResult: TLabel;
    lblStatus: TLabel;
    lblTotalBytesSource: TLabel;
    lblTotalBytesRead: TLabel;
    ProgressBar1: TProgressBar;
    procedure btnCloseProgressWindowClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormCreate(Sender: TObject);
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
  lblStatus.Caption:= 'Aborting...';
  frmYaffi.Stop:= true;
end;

procedure TfrmProgress.FormCreate(Sender: TObject);
begin
  btnCloseProgressWindow.Enabled:=false;
end;

procedure TfrmProgress.btnCloseProgressWindowClick(Sender: TObject);
begin
  frmProgress.Visible := false;
end;

end.

