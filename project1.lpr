program project1;

{$mode objfpc}{$H+}

uses

  Interfaces, // this includes the LCL widgetset
  Forms, UYaffi, LibEWFUnit;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TfrmYaffi, frmYaffi);
  Application.Run;
end.

