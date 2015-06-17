{ YAFFI - Yet Another Free Forensic Imager   Copyright (C) <2015>  <Ted Smith>

  A free, cross platform, GUI based imager for acquiring images in DD raw and EWF format

  https://github.com/tedsmith/yaffi

  Contributions from Erwan for the provision of a Delphi conversion of libEWF
  (http://labalec.fr/erwan/?p=1235) are welcomed and acknowledged.
  Adjusted for use with Freepascal by Ted Smith and supplied as part of this project

  Provision of the libEWF library by Joachim Metz also acknowledged
  https://github.com/libyal/libewf

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <http://www.gnu.org/licenses/>.
}
program yaffi;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, uyaffi, LibEWFUnit
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Initialize;
  Application.CreateForm(TfrmYAFFI, frmYAFFI);
  Application.Run;
end.

