{
  Copyright 2014-2014 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{ Spine skins. }

{$ifdef read_interface}
  TSkin = class
    Attachments: TAttachmentList;
    Name: string;
    constructor Create;
    destructor Destroy; override;
    procedure Parse(const Json: TJSONObject);
    procedure BuildNodes(const BaseUrl: string; const Atlas: TAtlas);
  end;

  TSkinList = class(specialize TFPGObjectList<TSkin>)
    { Find by name.
      @raises ESpineReadError If does not exist. }
    function Find(const Name: string): TSkin;
    procedure Parse(const Json: TJSONObject; var DefaultSkin: TSkin);
    procedure BuildNodes(const BaseUrl: string; const Atlas: TAtlas);
  end;
{$endif}

{$ifdef read_implementation}

{ TSkin ---------------------------------------------------------------------- }

constructor TSkin.Create;
begin
  inherited;
  Attachments := TAttachmentList.Create;
end;

destructor TSkin.Destroy;
begin
  FreeAndNil(Attachments);
  inherited;
end;

procedure TSkin.Parse(const Json: TJSONObject);

  procedure ParseSlotMap(const Json: TJSONObject; const SlotName: string);
  var
    I: Integer;
    Attachment: TAttachment;
  begin
    for I := 0 to Json.Count - 1 do
      if Json.Items[I] is TJSONObject then
      begin
        Attachment := TAttachment.CreateAndParse(
          TJSONObject(Json.Items[I]), SlotName, Json.Names[I]);
        if Attachment <> nil then
          Attachments.Add(Attachment);
      end;
  end;

var
  I: Integer;
begin
  for I := 0 to Json.Count - 1 do
    if Json.Items[I] is TJSONObject then
      ParseSlotMap(TJSONObject(Json.Items[I]), Json.Names[I]);
end;

procedure TSkin.BuildNodes(const BaseUrl: string; const Atlas: TAtlas);
var
  I: Integer;
begin
  for I := 0 to Attachments.Count - 1 do
    Attachments[I].BuildNodes(BaseUrl, Atlas);
end;

{ TSkinList ------------------------------------------------------------------ }

function TSkinList.Find(const Name: string): TSkin;
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    if Items[I].Name = Name then
      Exit(Items[I]);
  raise ESpineReadError.CreateFmt('Skin name "%s" not found', [Name]);
end;

procedure TSkinList.Parse(const Json: TJSONObject; var DefaultSkin: TSkin);
var
  I: Integer;
  Skin: TSkin;
  ChildObj: TJSONObject;
begin
  ChildObj := Json.Find('skins', jtObject) as TJSONObject;
  if ChildObj = nil then
    raise ESpineReadError.Create('Spine JSON skeleton: Missing "skins" object');

  for I := 0 to ChildObj.Count - 1 do
    if ChildObj.Items[I] is TJSONObject then
    begin
      Skin := TSkin.Create;
      Add(Skin);
      Skin.Name := ChildObj.Names[I];
      Skin.Parse(TJSONObject(ChildObj.Items[I]));

      if Skin.Name = 'default' then
        DefaultSkin := Skin;
    end;

  if DefaultSkin = nil then
    raise ESpineReadError.Create('Spine JSON skeleton: Missing "default" skin definition');
end;

procedure TSkinList.BuildNodes(const BaseUrl: string; const Atlas: TAtlas);
var
  I: Integer;
begin
  for I := 0 to Count - 1 do
    Items[I].BuildNodes(BaseUrl, Atlas);
end;

{$endif}