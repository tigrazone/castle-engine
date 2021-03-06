{
  Copyright 2010-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{$ifdef read_interface}

  { Dialog box that can display a long text, with automatic vertical scrollbar.
    You can also add buttons at the bottom.
    You can also have an input text area.
    This can be used to make either a modal or non-modal dialog boxes.

    See CastleMessages for routines that intensively use this dialog underneath,
    giving you easy MessageXxx routines that ask user for confirmation and such. }
  TCastleDialog = class abstract(TUIControlFont)
  strict private
    const
      BoxMargin = 10;
      WindowMargin = 10;
      ButtonHorizontalMargin = 10;
    type
      TDialogScrollArea = class(TUIControlSizeable)
      strict private
        Dialog: TCastleDialog;
      public
        constructor Create(AOwner: TComponent); override;
        procedure Render; override;
      end;
    var
    FInputText: string;

    { Broken Text. }
    Broken_Text: TRichText;
    { Ignored (not visible) if not DrawInputText.
      Else broken InputText. }
    Broken_InputText: TStringList;

    MaxLineWidth: integer;
    { Sum of all Broken_Text.Count + Broken_InputText.Count.
      In other words, all lines that are scrolled by the scrollbar. }
    AllScrolledLinesCount: integer;

    { Things below set in MessageCore, readonly afterwards. }
    { Main text to display. Read-only contents. }
    Text: TStringList;
    { Drawn as window background. @nil means there is no background
      (use only if there is always some other 2D control underneath TCastleDialog).
      When assigned, stretched to cover whole screen. }
    GLBackground: TGLImageCore;
    Background: TCastleImage;
    TextAlign: THorizontalPosition;
    { Should we display InputText }
    DrawInputText: boolean;
    Buttons: array of TCastleButton;
    LifeTime: TFloatTime;
    FHtml: boolean;
    ScrollView: TCastleScrollView;

    function BoxMarginScaled: Integer;
    function WindowMarginScaled: Integer;
    function ButtonHorizontalMarginScaled: Integer;

    procedure SetInputText(const value: string);

    { Calculate height in pixels needed to draw Buttons.
      Returns 0 if there are no Buttons. }
    function ButtonsHeightScaled: Integer;
    function ButtonsHeight: Integer;
    procedure UpdateSizes;
  public
    { Set this to @true to signal that modal dialog window should be closed.
      This is not magically handled --- if you implement a modal dialog box,
      you should check in your loop whether something set Answered to @true. }
    Answered: boolean;

    { The whole rectangle where we draw dialog box. }
    function Rect: TRectangle; override;

    { Input text. Displayed only if DrawInputText. }
    property InputText: string read FInputText write SetInputText;

    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { Assign display stuff. Call this before adding control to Controls list.
      ABackground instance becomes owned by this component. }
    procedure Initialize(
      const TextList: TStringList; const ATextAlign: THorizontalPosition;
      const AHtml: boolean;
      const AButtons: array of TCastleButton;
      const ADrawInputText: boolean; const AInputText: string;
      const ABackground: TCastleImage);
    procedure Resize; override;
    procedure GLContextOpen; override;
    procedure GLContextClose; override;
    procedure Update(const SecondsPassed: Single; var HandleInput: boolean); override;
    procedure Render; override;
    function CapturesEventsAtPosition(const Position: TVector2): boolean; override;
  end;

{$endif read_interface}

{$ifdef read_implementation}

{ TDialogScrollArea -------------------------------------------------------------- }

const
  CaretChar = '|';

constructor TCastleDialog.TDialogScrollArea.Create(AOwner: TComponent);
begin
  inherited;
  Dialog := AOwner as TCastleDialog;
  FullSize := true; // we want our ScreenRect to be equal to parent
end;

procedure TCastleDialog.TDialogScrollArea.Render;
type
  TCaretMode = (cmNone, cmVisible, cmInvisible);

  { Render a Text line, and move Y up to the line above. }
  procedure DrawString(X: Integer; var Y: Integer; const Color: TCastleColor;
    Text: string; const TextAlign: THorizontalPosition;
    const Caret: TCaretMode);
  var
    CaretWidth: Integer;
  begin
    if Caret <> cmNone then
      CaretWidth := Dialog.Font.TextWidth(CaretChar) else
      CaretWidth := 0;
    { change X only locally, to take TextAlign into account }
    case TextAlign of
      hpMiddle: X += (Dialog.MaxLineWidth - (Dialog.Font.TextWidth(Text) + CaretWidth)) div 2;
      hpRight : X +=  Dialog.MaxLineWidth - (Dialog.Font.TextWidth(Text) + CaretWidth);
    end;
    if Caret = cmVisible then
      Text := Text + CaretChar;
    Dialog.Font.Print(X, Y, Color, Text);
    { change Y for caller, to print next line higher }
    Y += Dialog.Font.RowHeight;
  end;

  { Render all lines in S, and move Y up to the line above. }
  procedure DrawStrings(const X: Integer; var Y: Integer;
    const Color: TCastleColor; const s: TStrings; TextAlign: THorizontalPosition;
    const AddCaret: boolean);
  const
    CaretSpeed = 1; //< how many blinks per second
  var
    I: Integer;
    Caret: TCaretMode;
  begin
    for i := S.Count - 1 downto 0 do
    begin
      if AddCaret and (I = S.Count - 1) then
      begin
        if FloatModulo(Dialog.LifeTime * CaretSpeed, 1.0) < 0.5 then
          Caret := cmVisible else
          Caret := cmInvisible;
      end else
        Caret := cmNone;
      { each DrawString call will move Y up }
      DrawString(X, Y, Color, s[i], TextAlign, Caret);
    end;
  end;

var
  TextX, TextY: Integer;
  SR: TRectangle;
begin
  inherited;

  SR := ScreenRect; // screen rectangle of ScrollView.ScrollArea
  TextX := SR.Left   + Dialog.BoxMarginScaled;
  TextY := SR.Bottom + Dialog.BoxMarginScaled;

  { draw Broken_InputText and Broken_Text.
    Order matters, as it's drawn from bottom to top. }
  if Dialog.DrawInputText then
    DrawStrings(TextX, TextY, Theme.MessageInputTextColor,
      Dialog.Broken_InputText, Dialog.TextAlign, true);

  { adjust TextX for TRichText.Print call }
  case Dialog.TextAlign of
    hpMiddle: TextX := (SR.Left + SR.Right) div 2;
    hpRight : TextX := SR.Right - Dialog.BoxMarginScaled;
  end;
  Dialog.Broken_Text.Print(TextX, TextY, Theme.MessageTextColor, 0, Dialog.TextAlign);
end;

{ TCastleDialog -------------------------------------------------------------- }

constructor TCastleDialog.Create(AOwner: TComponent);
begin
  inherited;
  { use Theme.MessageFont this way }
  CustomFont := Theme.MessageFont;
  { Contents of Broken_InputText will be initialized in TCastleDialog.UpdateSizes. }
  Broken_InputText := TStringList.Create;
  Anchor(hpMiddle);
  Anchor(vpMiddle);

  ScrollView := TCastleScrollView.Create(Self);
  ScrollView.ScrollArea.InsertFront(TDialogScrollArea.Create(Self));
  ScrollView.EnableDragging := true;
  InsertFront(ScrollView);
end;

procedure TCastleDialog.Initialize(const TextList: TStringList;
  const ATextAlign: THorizontalPosition; const AHtml: boolean;
  const AButtons: array of TCastleButton;
  const ADrawInputText: boolean; const AInputText: string;
  const ABackground: TCastleImage);
var
  I: Integer;
begin
  Text := TextList;
  Background := ABackground;
  if GLInitialized then
    GLBackground := TGLImageCore.Create(Background, true);
  TextAlign := ATextAlign;
  FHtml := AHtml;
  DrawInputText := ADrawInputText;
  FInputText := AInputText;
  SetLength(Buttons, Length(AButtons));
  for I := 0 to High(AButtons) do
  begin
    Buttons[I] := AButtons[I];
    InsertFront(Buttons[I]);
  end;
end;

destructor TCastleDialog.Destroy;
begin
  FreeAndNil(Broken_Text);
  FreeAndNil(Broken_InputText);
  FreeAndNil(Background);
  inherited;
end;

procedure TCastleDialog.GLContextOpen;
begin
  inherited;
  if (GLBackground = nil) and (Background <> nil) then
    GLBackground := TGLImageCore.Create(Background, true);
end;

procedure TCastleDialog.GLContextClose;
begin
  FreeAndNil(GLBackground);
  inherited;
end;

procedure TCastleDialog.SetInputText(const value: string);
begin
  FInputText := value;
  VisibleChange;
  UpdateSizes;
end;

function TCastleDialog.ButtonsHeightScaled: Integer;
var
  Button: TCastleButton;
begin
  Result := 0;
  for Button in Buttons do
    MaxVar(Result, Round(Button.CalculatedHeight * UIScale) + 2 * BoxMarginScaled);
end;

function TCastleDialog.ButtonsHeight: Integer;
var
  Button: TCastleButton;
begin
  Result := 0;
  for Button in Buttons do
    MaxVar(Result, Button.CalculatedHeight + 2 * BoxMargin);
end;

procedure TCastleDialog.Resize;
begin
  inherited;
  UpdateSizes;
end;

procedure TCastleDialog.UpdateSizes;

  { Reposition Buttons. }
  procedure UpdateButtons;
  var
    X, Y, I: Integer;
    Button: TCastleButton;
  begin
    if Length(Buttons) <> 0 then
    begin
      X := -BoxMargin;
      Y :=  BoxMargin;
      for I := Length(Buttons) - 1 downto 0 do
      begin
        Button := Buttons[I];
        Button.Anchor(vpBottom, Y);
        Button.Anchor(hpRight, X);
        X -= Button.CalculatedWidth + ButtonHorizontalMargin;
      end;
    end;
  end;

var
  BreakWidth, ButtonsWidth: integer;
  Button: TCastleButton;
begin
  { calculate BreakWidth, which is the width at which we should break
    our string lists Broken_Xxx. We must here always subtract
    ScrollBarWidthScaled to be on the safe side, because we don't know
    yet is ScrollBarVisible. }
  BreakWidth := Max(0, ParentRect.Width - BoxMarginScaled * 2
    - WindowMarginScaled * 2 - ScrollView.ScrollBarWidthScaled);

  { calculate MaxLineWidth and AllScrolledLinesCount }

  { calculate Broken_Text }
  FreeAndNil(Broken_Text);
  Broken_Text := TRichText.Create(Font, Text, FHtml);
  Broken_Text.Wrap(BreakWidth);
  MaxLineWidth := Broken_Text.Width;
  AllScrolledLinesCount := Broken_Text.Count;

  ButtonsWidth := 0;
  for Button in Buttons do
    ButtonsWidth += Round(Button.CalculatedWidth * UIScale) + ButtonHorizontalMarginScaled;
  if ButtonsWidth > 0 then
    ButtonsWidth -= ButtonHorizontalMarginScaled; // extract margin from last button
  MaxVar(MaxLineWidth, ButtonsWidth);

  if DrawInputText then
  begin
    { calculate Broken_InputText }
    Broken_InputText.Clear;
    Font.BreakLines(InputText, Broken_InputText, BreakWidth);
    { It's our intention that if DrawInputText then *always*
      at least 1 line of InputText (even if it's empty) will be shown.
      That's because InputText is the editable text for the user,
      so there should be indication of "empty line". }
    if Broken_InputText.count = 0 then Broken_InputText.Add('');
    MaxVar(MaxLineWidth, Font.MaxTextWidth(Broken_InputText) + Font.TextWidth(CaretChar));
    AllScrolledLinesCount += Broken_InputText.count;
  end;

  { Now we have MaxLineWidth and AllScrolledLinesCount calculated,
    so our Rect and ScreenRect return valid values. }

  ScrollView.Left := 0;
  ScrollView.Bottom := ButtonsHeight;
  ScrollView.Width := CalculatedWidth;
  ScrollView.Height := CalculatedHeight - ButtonsHeight;

  { add Font.Descend, to be able to see the descend of the bottom line when Scroll is ScrollMax. }
  ScrollView.ScrollArea.Height :=
    Round((Font.RowHeight * AllScrolledLinesCount + Font.Descend) / UIScale) + 2 * BoxMargin;
  ScrollView.ScrollArea.Width := CalculatedWidth;

  UpdateButtons;
end;

procedure TCastleDialog.Update(const SecondsPassed: Single;
  var HandleInput: boolean);
begin
  inherited;
  LifeTime += SecondsPassed;
  { when we have input text, we display blinking caret, so keep redrawing }
  if DrawInputText then
    VisibleChange;
end;

procedure TCastleDialog.Render;
begin
  inherited;

  if GLBackground <> nil then
  begin
    GLBackground.Color := Theme.BackgroundTint;
    GLBackground.Draw(ParentRect);
  end;

  Theme.Draw(ScreenRect, tiWindow, UIScale);
end;

function TCastleDialog.CapturesEventsAtPosition(const Position: TVector2): boolean;
begin
  Result := true; // always capture
end;

function TCastleDialog.Rect: TRectangle;
var
  PR: TRectangle;
begin
  PR := ParentRect;
  Result := Rectangle(0, 0,
    Min(MaxLineWidth + BoxMarginScaled * 2 + ScrollView.ScrollBarWidthScaled,
      PR.Width  - WindowMarginScaled * 2),
    Min(Font.RowHeight * AllScrolledLinesCount + Font.Descend + BoxMarginScaled * 2 + ButtonsHeightScaled
      { adding here + 2 is a hack to make sure that TCastleScrollView will
        not show scrollbars when not necessary. That's because we set
        ScrollView.ScrollArea.Height using a similar equation as above
        "Font.RowHeight * AllScrolledLinesCount + Font.Descend...",
        but it's in unscaled size (/ UIScale), and sometimes (with wild UIScale
        values) it seems like scrollbars are needed (CalculatedHeight < ScrollArea.CalculatedHeight)
        even though they actually are not.

        Reproducible if you try to resize to small sizes the demo on
        /home/michalis/sources/castle-engine/castle-engine/examples/android/android_demo/game.pas . }
      + 2,
      PR.Height - WindowMarginScaled * 2));
end;

function TCastleDialog.BoxMarginScaled: Integer;
begin
  Result := Round(BoxMargin * UIScale);
end;

function TCastleDialog.WindowMarginScaled: Integer;
begin
  Result := Round(WindowMargin * UIScale);
end;

function TCastleDialog.ButtonHorizontalMarginScaled: Integer;
begin
  Result := Round(ButtonHorizontalMargin * UIScale);
end;

{$endif read_implementation}
