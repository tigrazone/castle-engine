{
  Copyright 2017-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Interface and implementation of record-based vector types using the Integer components. }

{$ifdef read_interface}

type
  { Vector of 2 Integer values.
    @seealso TVector3Integer }
  TVector2Integer = record
  public
    type
      TIndex = 0..1;
  strict private
    function GetItems(const Index: TIndex): Integer;
    procedure SetItems(const Index: TIndex; const Value: Integer);
  public
    var
      Data: array [TIndex] of Integer;
    {$ifndef BUGGY_ZERO_CONSTANT}
    const
      Zero: TVector2Integer = (Data: (0, 0));
    {$endif}

    class operator {$ifdef FPC}+{$else}Add{$endif} (const A, B: TVector2Integer): TVector2Integer;
    class operator {$ifdef FPC}-{$else}Subtract{$endif} (const A, B: TVector2Integer): TVector2Integer;
    class operator {$ifdef FPC}-{$else}Negative{$endif} (const V: TVector2Integer): TVector2Integer;

    function ToString: string;
    property Items [const Index: TIndex]: Integer read GetItems write SetItems; default;
    function IsZero: boolean;
    class function Equals(const V1, V2: TVector2Integer): boolean; static;

    {$ifdef BUGGY_ZERO_CONSTANT}
    class function Zero: TVector2Integer; static;
    {$endif}
  end;

  { Vector of 3 Integer values. }
  TVector3Integer = record
  public
    type
      TIndex = 0..2;
  strict private
    function GetItems(const Index: TIndex): Integer;
    procedure SetItems(const Index: TIndex; const Value: Integer);
  public
    var
      Data: array [TIndex] of Integer;
    {$ifndef BUGGY_ZERO_CONSTANT}
    const
      Zero: TVector3Integer = (Data: (0, 0, 0));
    {$endif}

    class operator {$ifdef FPC}+{$else}Add{$endif} (const A, B: TVector3Integer): TVector3Integer;
    class operator {$ifdef FPC}-{$else}Subtract{$endif} (const A, B: TVector3Integer): TVector3Integer;
    class operator {$ifdef FPC}-{$else}Negative{$endif} (const V: TVector3Integer): TVector3Integer;

    function ToString: string;
    property Items [const Index: TIndex]: Integer read GetItems write SetItems; default;
    function IsZero: boolean;
    class function Equals(const V1, V2: TVector3Integer): boolean; static;

    {$ifdef BUGGY_ZERO_CONSTANT}
    class function Zero: TVector3Integer; static;
    {$endif}
  end;

  { Vector of 4 Integer values. }
  TVector4Integer = record
  public
    type
      TIndex = 0..3;
  strict private
    function GetItems(const Index: TIndex): Integer;
    procedure SetItems(const Index: TIndex; const Value: Integer);
  public
    var
      Data: array [TIndex] of Integer;
    {$ifndef BUGGY_ZERO_CONSTANT}
    const
      Zero: TVector4Integer = (Data: (0, 0, 0, 0));
    {$endif}

    class operator {$ifdef FPC}+{$else}Add{$endif} (const A, B: TVector4Integer): TVector4Integer;
    class operator {$ifdef FPC}-{$else}Subtract{$endif} (const A, B: TVector4Integer): TVector4Integer;
    class operator {$ifdef FPC}-{$else}Negative{$endif} (const V: TVector4Integer): TVector4Integer;

    function ToString: string;
    property Items [const Index: TIndex]: Integer read GetItems write SetItems; default;
    function IsZero: boolean;
    class function Equals(const V1, V2: TVector4Integer): boolean; static;

    {$ifdef BUGGY_ZERO_CONSTANT}
    class function Zero: TVector4Integer; static;
    {$endif}
  end;

  PVector2Integer = ^TVector2Integer;
  PVector3Integer = ^TVector3Integer;
  PVector4Integer = ^TVector4Integer;

  TArray_Vector2Integer = packed array [0..MaxInt div SizeOf(TVector2Integer)-1] of TVector2Integer;
  PArray_Vector2Integer = ^TArray_Vector2Integer;
  TArray_Vector3Integer = packed array [0..MaxInt div SizeOf(TVector3Integer)-1] of TVector3Integer;
  PArray_Vector3Integer = ^TArray_Vector3Integer;
  TArray_Vector4Integer = packed array [0..MaxInt div SizeOf(TVector4Integer)-1] of TVector4Integer;
  PArray_Vector4Integer = ^TArray_Vector4Integer;

function Vector2Integer(const X, Y: Integer): TVector2Integer;
function Vector3Integer(const X, Y, Z: Integer): TVector3Integer;
function Vector4Integer(const X, Y, Z, W: Integer): TVector4Integer;

(*
Not defined for now, it's not obvious whether this is the most intuitive Lerp.

function Lerp(const A: Single; const V1, V2: TVector2Integer): TVector2Integer; overload;
function Lerp(const A: Single; const V1, V2: TVector3Integer): TVector3Integer; overload;
function Lerp(const A: Single; const V1, V2: TVector4Integer): TVector4Integer; overload;

The other approach is to convert to floating-point type while doing Lerp, like this:

function Lerp(const A: Single; const V1, V2: TVector2Integer): TVector2; overload;
function Lerp(const A: Single; const V1, V2: TVector3Integer): TVector3; overload;
function Lerp(const A: Single; const V1, V2: TVector4Integer): TVector4; overload;
*)

{$endif read_interface}

{$ifdef read_implementation}

{ TVector2Integer ------------------------------------------------------------ }

class operator TVector2Integer. {$ifdef FPC}+{$else}Add{$endif} (const A, B: TVector2Integer): TVector2Integer;
begin
  Result.Data[0] := A.Data[0] + B.Data[0];
  Result.Data[1] := A.Data[1] + B.Data[1];
end;

class operator TVector2Integer. {$ifdef FPC}-{$else}Subtract{$endif} (const A, B: TVector2Integer): TVector2Integer;
begin
  Result.Data[0] := A.Data[0] - B.Data[0];
  Result.Data[1] := A.Data[1] - B.Data[1];
end;

class operator TVector2Integer. {$ifdef FPC}-{$else}Negative{$endif} (const V: TVector2Integer): TVector2Integer;
begin
  Result.Data[0] := - V.Data[0];
  Result.Data[1] := - V.Data[1];
end;

function TVector2Integer.ToString: string;
begin
  Result := Format('%d %d', [Data[0], Data[1]]);
end;

function TVector2Integer.GetItems(const Index: TIndex): Integer;
begin
  Result := Data[Index];
end;

procedure TVector2Integer.SetItems(const Index: TIndex; const Value: Integer);
begin
  Data[Index] := Value;
end;

function TVector2Integer.IsZero: boolean;
begin
  Result := IsMemCharFilled(Data, SizeOf(Data), #0);
end;

class function TVector2Integer.Equals(const V1, V2: TVector2Integer): boolean;
begin
  Result := (V1[0] = V2[0]) and
            (V1[1] = V2[1]);
end;

{$ifdef BUGGY_ZERO_CONSTANT}
class function TVector2Integer.Zero: TVector2Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
end;
{$endif}

{ TVector3Integer ------------------------------------------------------------ }

class operator TVector3Integer. {$ifdef FPC}+{$else}Add{$endif} (const A, B: TVector3Integer): TVector3Integer;
begin
  Result.Data[0] := A.Data[0] + B.Data[0];
  Result.Data[1] := A.Data[1] + B.Data[1];
  Result.Data[2] := A.Data[2] + B.Data[2];
end;

class operator TVector3Integer. {$ifdef FPC}-{$else}Subtract{$endif} (const A, B: TVector3Integer): TVector3Integer;
begin
  Result.Data[0] := A.Data[0] - B.Data[0];
  Result.Data[1] := A.Data[1] - B.Data[1];
  Result.Data[2] := A.Data[2] - B.Data[2];
end;

class operator TVector3Integer. {$ifdef FPC}-{$else}Negative{$endif} (const V: TVector3Integer): TVector3Integer;
begin
  Result.Data[0] := - V.Data[0];
  Result.Data[1] := - V.Data[1];
  Result.Data[2] := - V.Data[2];
end;

function TVector3Integer.ToString: string;
begin
  Result := Format('%d %d %d', [Data[0], Data[1], Data[2]]);
end;

function TVector3Integer.GetItems(const Index: TIndex): Integer;
begin
  Result := Data[Index];
end;

procedure TVector3Integer.SetItems(const Index: TIndex; const Value: Integer);
begin
  Data[Index] := Value;
end;

function TVector3Integer.IsZero: boolean;
begin
  Result := IsMemCharFilled(Data, SizeOf(Data), #0);
end;

class function TVector3Integer.Equals(const V1, V2: TVector3Integer): boolean;
begin
  Result := (V1[0] = V2[0]) and
            (V1[1] = V2[1]) and
            (V1[2] = V2[2]);
end;

{$ifdef BUGGY_ZERO_CONSTANT}
class function TVector3Integer.Zero: TVector3Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
end;
{$endif}

{ TVector4Integer ------------------------------------------------------------ }

class operator TVector4Integer. {$ifdef FPC}+{$else}Add{$endif} (const A, B: TVector4Integer): TVector4Integer;
begin
  Result.Data[0] := A.Data[0] + B.Data[0];
  Result.Data[1] := A.Data[1] + B.Data[1];
  Result.Data[2] := A.Data[2] + B.Data[2];
  Result.Data[3] := A.Data[3] + B.Data[3];
end;

class operator TVector4Integer. {$ifdef FPC}-{$else}Subtract{$endif} (const A, B: TVector4Integer): TVector4Integer;
begin
  Result.Data[0] := A.Data[0] - B.Data[0];
  Result.Data[1] := A.Data[1] - B.Data[1];
  Result.Data[2] := A.Data[2] - B.Data[2];
  Result.Data[3] := A.Data[3] - B.Data[3];
end;

class operator TVector4Integer. {$ifdef FPC}-{$else}Negative{$endif} (const V: TVector4Integer): TVector4Integer;
begin
  Result.Data[0] := - V.Data[0];
  Result.Data[1] := - V.Data[1];
  Result.Data[2] := - V.Data[2];
  Result.Data[3] := - V.Data[3];
end;

function TVector4Integer.ToString: string;
begin
  Result := Format('%d %d %d %d', [Data[0], Data[1], Data[2], Data[3]]);
end;

function TVector4Integer.GetItems(const Index: TIndex): Integer;
begin
  Result := Data[Index];
end;

procedure TVector4Integer.SetItems(const Index: TIndex; const Value: Integer);
begin
  Data[Index] := Value;
end;

function TVector4Integer.IsZero: boolean;
begin
  Result := IsMemCharFilled(Data, SizeOf(Data), #0);
end;

class function TVector4Integer.Equals(const V1, V2: TVector4Integer): boolean;
begin
  Result := (V1[0] = V2[0]) and
            (V1[1] = V2[1]) and
            (V1[2] = V2[2]) and
            (V1[3] = V2[3]);
end;

{$ifdef BUGGY_ZERO_CONSTANT}
class function TVector4Integer.Zero: TVector4Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
end;
{$endif}

{ global routines ------------------------------------------------------------ }

function Vector2Integer(const X, Y: Integer): TVector2Integer;
begin
  Result.Data[0] := X;
  Result.Data[1] := Y;
end;

function Vector3Integer(const X, Y, Z: Integer): TVector3Integer;
begin
  Result.Data[0] := X;
  Result.Data[1] := Y;
  Result.Data[2] := Z;
end;

function Vector4Integer(const X, Y, Z, W: Integer): TVector4Integer;
begin
  Result.Data[0] := X;
  Result.Data[1] := Y;
  Result.Data[2] := Z;
  Result.Data[3] := W;
end;

(*
function Lerp(const A: Single; const V1, V2: TVector2Integer): TVector2Integer;
begin
  Result.Data[0] := Clamped(Round(V1.Data[0] + A * (V2.Data[0] - V1.Data[0])), Low(Integer), High(Integer));
  Result.Data[1] := Clamped(Round(V1.Data[1] + A * (V2.Data[1] - V1.Data[1])), Low(Integer), High(Integer));
end;

function Lerp(const A: Single; const V1, V2: TVector3Integer): TVector3Integer;
begin
  Result.Data[0] := Clamped(Round(V1.Data[0] + A * (V2.Data[0] - V1.Data[0])), Low(Integer), High(Integer));
  Result.Data[1] := Clamped(Round(V1.Data[1] + A * (V2.Data[1] - V1.Data[1])), Low(Integer), High(Integer));
  Result.Data[2] := Clamped(Round(V1.Data[2] + A * (V2.Data[2] - V1.Data[2])), Low(Integer), High(Integer));
end;

function Lerp(const A: Single; const V1, V2: TVector4Integer): TVector4Integer;
begin
  Result.Data[0] := Clamped(Round(V1.Data[0] + A * (V2.Data[0] - V1.Data[0])), Low(Integer), High(Integer));
  Result.Data[1] := Clamped(Round(V1.Data[1] + A * (V2.Data[1] - V1.Data[1])), Low(Integer), High(Integer));
  Result.Data[2] := Clamped(Round(V1.Data[2] + A * (V2.Data[2] - V1.Data[2])), Low(Integer), High(Integer));
  Result.Data[3] := Clamped(Round(V1.Data[3] + A * (V2.Data[3] - V1.Data[3])), Low(Integer), High(Integer));
end;
*)

{$endif read_implementation}