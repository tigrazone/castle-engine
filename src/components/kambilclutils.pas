{
  Copyright 2008 Michalis Kamburelis.

  This file is part of "Kambi VRML game engine".

  "Kambi VRML game engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Kambi VRML game engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
}

{ Simple utilities for LCL + Kambi VRML engine. }
unit KambiLCLUtils;

interface

uses FileFilters, Dialogs;

{ Convert file filters (encoded as for TFileFiltersList.AddFiltersFromString)
  into LCL OpenDialog.Filter, OpenDialog.FilterIndex.

  @groupBegin }
procedure FileFiltersToOpenDialog(const FileFilters: string;
  OpenDialog: TOpenDialog);
procedure FileFiltersToOpenDialog(const FileFilters: string;
  out LCLFilter: string; out FilterIndex: Integer);
{ @groupEnd }

{ Convert file filters into LCL OpenDialog.Filter, OpenDialog.FilterIndex. }
procedure FileFiltersToOpenDialog(FFList: TFileFiltersList;
  out LCLFilter: string; out LCLFilterIndex: Integer);

{ Make each '&' inside string '&&', this way the string will not contain
  special '&x' sequences when used as a TMenuItem.Caption and such. }
function SQuoteLCLCaption(const S: string): string;

implementation

uses SysUtils, KambiClassUtils;

procedure FileFiltersToOpenDialog(const FileFilters: string;
  OpenDialog: TOpenDialog);
var
  LCLFilter: string;
  FilterIndex: Integer;
begin
  FileFiltersToOpenDialog(FileFilters, LCLFilter, FilterIndex);
  OpenDialog.Filter := LCLFilter;
  OpenDialog.FilterIndex := FilterIndex;
end;

procedure FileFiltersToOpenDialog(const FileFilters: string;
  out LCLFilter: string; out FilterIndex: Integer);
var
  FFList: TFileFiltersList;
begin
  FFList := TFileFiltersList.Create;
  try
    FFList.AddFiltersFromString(FileFilters);
    FileFiltersToOpenDialog(FFList, LCLFilter, FilterIndex);
  finally FreeWithContentsAndNil(FFList) end;
end;

procedure FileFiltersToOpenDialog(FFList: TFileFiltersList;
  out LCLFilter: string; out LCLFilterIndex: Integer);
var
  Filter: TFileFilter;
  I, J: Integer;
begin
  LCLFilter := '';

  for I := 0 to FFList.Count - 1 do
  begin
    Filter := FFList[I];
    LCLFilter += Filter.Name + '|';

    for J := 0 to Filter.Patterns.Count - 1 do
    begin
      if J <> 0 then LCLFilter += ';';
      LCLFilter += Filter.Patterns[J];
    end;

    LCLFilter += '|';
  end;

  { LCL FilterIndex counts from 1. }
  LCLFilterIndex := FFList.DefaultFilter + 1;
end;

function SQuoteLCLCaption(const S: string): string;
begin
  Result := StringReplace(S, '&', '&&', [rfReplaceAll]);
end;

end.
