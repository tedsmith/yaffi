program project1;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, textsearch
  { you can add units after this };

{$R *.res}

begin
  Application.Title:='TextSearch';
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TfrmTextSearch, frmTextSearch);
  Application.Run;
end.
