{
  Copyright 2002-2017 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
}

{$ifdef read_interface}

  TX3DField = class;

  TX3DFieldClass = class of TX3DField;

  { Called when @link(TX3DEvent) is received,
    see @link(TX3DEvent.AddNotification). }
  TX3DEventReceive = procedure (Event: TX3DEvent; Value: TX3DField;
    const Time: TX3DTime) of object;

  { Base class for all VRML/X3D fields.

    Common notes for all descendants: most of them expose a field or property
    "Value", which specifies the current value of the field.
    Many of them also expose DefaultValue and DefaultValueExists
    fields/properties, these should be the default X3D value for this field.
    You can even change DefaultValue after the object is created.

    Most of descendants include constructor that initializes
    both DefaultValue and Value to the same thing, as this is what
    you usually want.

    Some notes about @code(Assign) method (inherited from TPersistent and
    overridied appropriately in TX3DField descendants):

    @orderedList(
      @item(There are some exceptions, but usually
        assignment is possible only when source and destination field classes
        are equal.)

      @item(Assignment (by @code(Assign), inherited from TPersistent)
        tries to copy everything: name (with alternative names), default value,
        IsClauseNames, ValueFromIsClause, Exposed, and of course current value.

        Exceptions are things related to hierarchy of containers:
        ParentNode, ParentInterfaceDeclaration. Also ExposedEventsLinked.

        If you want to copy only the current value, use AssignValue
        (or AssignLerp, where available).))
  }
  TX3DField = class(TX3DFieldOrEvent)
  strict private
    FExposedEvents: array [boolean] of TX3DEvent;
    FChangesAlways: TX3DChanges;

    // keep booleans together, to pack them together in memory
    FExposed: boolean;
    FValueFromIsClause: boolean;
    FExposedEventsLinked: boolean;

    procedure SetExposed(Value: boolean);
    function GetExposedEvents(InEvent: boolean): TX3DEvent;
    procedure SetExposedEventsLinked(const Value: boolean);
  strict protected
    function SendsByEvent: boolean;

    { Save field value to a stream. Must be overriden for each specific
      field.

      For classic encoding, FieldSaveToStream and SaveToStream write
      Indent, Name, ' ', then call SaveToStreamValue, then write @link(NL).

      IS clauses are not saved by FieldSaveToStream or SaveToStream.
      (They must be saved specially, by SaveToStreamClassicIsClauses
      or special XML output.)
      SaveToStream still checks ValueFromIsClause, if ValueFromIsClause
      we will not call SaveToStreamValue. So when overriding
      SaveToStreamValue, you can safely assume that ValueFromIsClause
      is @false. }
    procedure SaveToStreamValue(Writer: TX3DWriter); virtual; abstract;

    { Save method of SaveToStreamValue. May assume things that
      SaveToStreamValue may issume, for example: if this is used at all,
      then at least field value is not default (so there is a need to write
      this field) and such. }
    function SaveToXmlValue: TSaveToXmlMethod; virtual;

    { Call this inside overriden Assign methods.
      I don't want to place this inside TX3DField.Assign, since I want
      "inherited" in Assign methods to cause exception. }
    procedure VRMLFieldAssignCommon(Source: TX3DField);

    procedure AssignValueRaiseInvalidClass(Source: TX3DField);

    { Class of the fields allowed in the exposed events of this field.
      This should usually be using ClassType of this object,
      and this is the default implementation of this method in TX3DField.

      You can override this to return some ancestor (from which, and to which,
      you can assign) if your TX3DField descendant
      doesn't change how the @code(Assign) method works.
      E.g. TSFTextureUpdate class, that wants to be fully compatible with normal
      TSFString. }
    class function ExposedEventsFieldClass: TX3DFieldClass; virtual;

    { Handle exposed input event. In TX3DField class, this does everything
      usually needed --- assigns value, sends an output event, notifies
      @link(Changed).

      You can override this for some special purposes. For special needs,
      you do not even need to call @code(inherited) in overriden versions.
      This is suitable e.g. for cases when TimeSensor.set_startTime or such
      must be ignored. }
    procedure ExposedEventReceive(Event: TX3DEvent; Value: TX3DField;
      const Time: TX3DTime); virtual;
  public
    { Normal constructor.

      @italic(Descendants implementors notes:)
      when implementing constructors in descendants,
      remember that Create in this class actually just calls CreateUndefined,
      and CreateUndefined is virtual. So when calling @code(inherited Create),
      be aware that actually you may be calling your own overriden
      CreateUndefined.

      In fact, in descendants you should focus on moving all the work to
      CreateUndefined constructor.
      The Create constructor should be just a comfortable extension of
      CreateUndefined, that does the same and addiionally gets parameters
      that specify default field value. }
    constructor Create(const AParentNode: TX3DFileItem;
      const AExposed: boolean; const AName: string);

    { Virtual constructor, that you can use to construct field instance when
      field class is known only at runtime.

      The idea is that in some cases, you need to create fields using
      variable like FieldClass: TX3DFieldClass. See e.g. TX3DInterfaceDeclaration,
      VRML 2.0 feature that simply requires this ability, also
      implementation of TX3DSimpleMultField.Parse and
      TX3DSimpleMultField.CreateItemBeforeParse.

      Later you can initialize such instance from string using it's Parse method.

      Note that some exceptional fields simply cannot work when initialized
      by this constructor: these are SFEnum and SFBitMask fields.
      They simply need to know their TSFEnum.EnumNames, or
      TSFBitMask.FlagNames + TSFBitMask.NoneString + TSFBitMask.AllString
      before they can be parsed. I guess that's one of the reasons why these
      field types were entirely removed from VRML 2.0. }
    constructor CreateUndefined(const AParentNode: TX3DFileItem;
      const AExposed: boolean; const AName: string); virtual;

    destructor Destroy; override;

    { Parse inits properties from Lexer.

      In this class, Parse only appends to IsClauseNames:
      if we stand on "IS" clause (see VRML 2.0 spec about "IS" clause)
      and IsClauseAllowed then we append specified identifier to
      IsClauseNames.

      If "IS" clause not found, we call ParseValue which should
      actually parse field's value.
      Descendants should override ParseValue. }
    procedure Parse(Lexer: TX3DLexer; Reader: TX3DReader; IsClauseAllowed: boolean);

    procedure ParseValue(Lexer: TX3DLexer; Reader: TX3DReader); virtual; abstract;

    { Parse field value from X3D XML encoded attribute using a Lexer.
      Attributes in X3D are generally encoded such that normal
      @code(ParseValue(Lexer, nil)) call is appropriate,
      so this is done in this class. }
    procedure ParseXMLAttributeLexer(Lexer: TX3DLexer; Reader: TX3DReader); virtual;

    { Parse field value from X3D XML encoded attribute.

      Implementation in this class creates a Lexer to parse the string,
      and calls ParseXMLAttributeLexer. }
    procedure ParseXMLAttribute(const AttributeValue: string; Reader: TX3DReader); virtual;

    { Parse field's value from XML Element children.
      This is used to read SFNode / MFNode field value inside <field>
      (for interface declaration default field value) and <fieldValue>
      inside <ProtoInstance>. }
    procedure ParseXMLElement(Element: TDOMElement; Reader: TX3DReader); virtual;

    { Save the field to the stream.
      Field name (if set, omitted if empty) and value are saved.
      Unless the current field value equals default value and
      FieldSaveWhenDefault is @false (default), then nothing is saved.

      IS clauses are not saved here (because they often have to be treated
      specially anyway, for XML encoding, for prototype declarations etc.). }
    procedure FieldSaveToStream(Writer: TX3DWriter;
      FieldSaveWhenDefault: boolean = false;
      XmlAvoidSavingNameBeforeValue: boolean = false);

    { Save the field to the stream.

      This simply calls FieldSaveToStream(Writer).
      See FieldSaveToStream for more comments and when you need control over
      FieldSaveWhenDefault behavior.

      It doesn't actually save anything if field value is defined
      and equals default value. }
    procedure SaveToStream(Writer: TX3DWriter); override;
    function SaveToXml: TSaveToXmlMethod; override;

    { Does current field value came from expanding "IS" clause.
      If yes, then saving this field to stream will only save it's "IS" clauses,
      never saving actual value. }
    property ValueFromIsClause: boolean
      read FValueFromIsClause write FValueFromIsClause;

    { Zwraca zawsze false w tej klasie. Mozesz to przedefiniowac w podklasach
      aby SaveToStream nie zapisywalo do strumienia pol o wartosci domyslnej. }
    function EqualsDefaultValue: boolean; virtual;

    { @true if the SecondValue object has exactly the same type and properties.
      For this class, this returns just (SecondValue.Name = Name).

      All descendants (that add some property that should be compared)
      should override this like

      @longCode(#
        Result := (inherited Equals(SecondValue)) and
          (SecondValue is TMyType) and
          (TMyType(SecondValue).MyProperty = MyProperty);
      #)

      The floating-point fields may be compared with a small epsilon
      tolerance by this method.

      Note that this *doesn't* compare the default values of two fields
      instances. This compares only the current values of two fields
      instances, and eventually some other properties that affect
      parsing (like names for TSFEnum and TSFBitMask) or allowed
      future values (like TSFFloat.MustBeNonnegative).
    }
    function Equals(SecondValue: TX3DField): boolean; virtual; reintroduce;

    { Compare value of this field, with other field, fast.

      This compares only the values of the fields, not other properties
      (it doesn't care about names of the fields or such, or default values;
      only current values). In other words, it compares only the things
      copied by AssignValue.

      This tries to compare very fast, which means that for large
      (multi-valued) fields it may give up and answer @false even
      when they are in fact equal. So this is usable only for optimization
      purposes: when it answers @true, it is @true. When it answers @false,
      it actually doesn't know.

      Default implementation in this class (@classname) just returns @false. }
    function FastEqualsValue(SecondValue: TX3DField): boolean; virtual;

    { Does this field generate/accept events, that is
      an "exposedField" (in VRML 2.0) or "inputOutput" (in X3D). }
    property Exposed: boolean read FExposed write SetExposed default false;

    { These are the set_xxx and xxx_changed events exposed by this field.
      @nil if Exposed is @false. }
    property ExposedEvents [InEvent: boolean]: TX3DEvent
      read GetExposedEvents;

    { Exposed events of this field. @nil if this field is not exposed.
      EventIn is always equivalent to ExposedEvents[true],
      EventOut is always equivalent to ExposedEvents[false].
      @groupBegin }
    function EventIn: TX3DEvent;
    function EventOut: TX3DEvent;
    { @groupEnd }

    { When @true (default) we will automatically handle exposed events
      behavior. This means that we will listen on EventIn,
      and when something will be received we will set current field's value
      and produce appropriate EventOut.

      You almost certainly want to leave this as @true in all typical
      situations, as it takes care of implementing required exposed events
      behavior.

      That said, in special cases you may decide to break this. }
    property ExposedEventsLinked: boolean
      read FExposedEventsLinked write SetExposedEventsLinked
      default true;

    { Field type in X3D, like @code('SFString') or @code('MFInt32').
      As for VRML/X3D interface declaration statements.
      In base TX3DField class, this returns @code(XFAny)
      (name indicating any type, used by instantreality and us). }
    class function X3DType: string; virtual;
    class function TypeName: string; deprecated 'use X3DType';

    { Create TX3DEvent descendant suitable as exposed event for this field. }
    class function CreateEvent(const AParentNode: TX3DFileItem; const AName: string; const AInEvent: boolean): TX3DEvent; virtual;

    { Copies the current field value. Contrary to TPersistent.Assign, this
      doesn't copy the rest of properties.

      After setting, our ValueFromIsClause is always changed to @false.
      You can manually change it to @true, if this copy indeed was done
      following "IS" clause.

      @raises(EX3DFieldAssignInvalidClass
        Usually it's required the Source class to be equal to our class,
        if Source classes cannot be assigned we raise EX3DFieldCannotAssignClass.)

      @raises(EX3DFieldAssign
        Raised in case of any field assignment problem. It's guaranteed that
        in case of such problem, our value will not be modified before
        raising the exception.

        EX3DFieldAssignInvalidClass inherits from EX3DFieldAssign,
        so actually EX3DFieldAssignInvalidClass is just a special case of this
        exceptiion.)

      @italic(Descendants implementors notes):

      In this class, implementation takes care of
      setting our ValueFromIsClause to @false. In descendants,
      you should do like

      @longCode(#
        if Source is <appropriate class> then
        begin
          inherited;
          Value := Source.value;
        end else
          AssignValueRaiseInvalidClass(Source);
      #)
    }
    procedure AssignValue(Source: TX3DField); virtual;

    { Set field's default value from the current value.

      Note that for now this doesn't guarantee that every possible field's value
      can be stored as default value. In case of trouble, it will silently
      record "no default is known" information, so e.g. EqualsDefaultValue
      will always return @false.
      Our default value mechanisms are sometimes
      limited, not every value can be a default value. For example,
      for multiple-valued nodes, we usually cannot save arrays longer than
      one as default value. This is not a problem, since X3D specification
      doesn't specify too long default values. But it may be a problem
      for prototypes, since then user can assign any value as default value.
      May be corrected in the future. }
    procedure AssignDefaultValueFromValue; virtual;

    { Assigns value to this node calculated from linear interpolation
      between two given nodes Value1, Value2. Just like other lerp
      functions in our units (like @link(CastleVectors.Lerp)).

      Like AssignValue, this copies only the current value.
      All other properties (like Name, IsClauseNames, ValueFromIsClause,
      default value) are untouched.

      There are some special precautions for this:

      @unorderedList(
        @item(First of all, AssignLerp is defined only for fields where
          CanAssignLerp returns @true, so always check CanAssignLerp first.
          All float-based fields should have this implemented.)

        @item(Use this only if Value1 and Value2
          are equal or descendant of target (Self) class.)

        @item(For multiple-value fields, counts of Value1 and Value2
          must be equal, or EListsDifferentCount will be raised.)
      )

      @raises(EListsDifferentCount When field is multiple-value
        field and Value1.Count <> Value2.Count.)
    }
    procedure AssignLerp(const A: Double; Value1, Value2: TX3DField); virtual;

    { @abstract(Is AssignLerp usable on this field type?)

      @italic(Descendants implementors notes):
      In this class, this always returns @false. }
    function CanAssignLerp: boolean; virtual;

    procedure AddAlternativeName(const AlternativeName: string;
      const X3DMajorVersion: Integer); override;

    { Notify ParentNode.Scene that the value of this field changed. }
    procedure Changed;

    { What always happens when the value of this field changes.

      This is included in the @link(ExecuteChanges) method result. So instead of
      using this property, you could always override @link(ExecuteChanges)
      method. But often it's easier to use the property.

      By default this is an empty set. This is suitable for
      things that aren't *directly* an actual content (but only an
      intermediate value to change other stuff). This includes
      all metadata fields and nodes, all fields in event utilities,
      Script node, interpolators...

      See TX3DChange for possible values. }
    property ChangesAlways: TX3DChanges read FChangesAlways write FChangesAlways;

    { What happens when the value of this field changes.
      This is called, exactly once, by TCastleSceneCore.InternalChangedField
      to determine what must be done when we know that value of this field changed.

      In overridden descendants, this can also do something immediately.
      Overriding this is similar to registering your callback by
      @link(TX3DEvent.AddNotification EventOut.AddNotification), with two additional benefits:

      @orderedList(
        @item(This method may be not called (although no guarantees)
          when the actual field value did not change.
          In contrast, the event notification is always fired,
          even when you send the same value to an exposed field,
          because VRML/X3D events and routes must be fired anyway.)

        @item(This is useful also for fields that are not exposed,
          and can be changed only by ObjectPascal code.)
      )

      So overridding this is closer to "do something when field value changes"
      than registering notification by @link(TX3DEvent.AddNotification EventOut.AddNotification). }
    function ExecuteChanges: TX3DChanges; virtual;

    { Set the value of the field, notifying the scenes and events engine.
      This sets the value of this field in the nicest possible way for
      any possible TCastleSceneCore (with events on or off) containing the node
      with this field.

      Precise specification:

      @unorderedList(
        @item(If this is an exposed field and we have events engine working:

          We will send this value through
          it's input event. In this case, this is equivalent to doing
          @code(EventIn.Send(Value, Scene.Time)).
          The scenes (including events engine) will be notified correctly
          by exposed events handler already.)

        @item(Otherwise, we will just set the fields value.
          And then notify the scenes (including events engine).)
      ) }
    procedure Send(Value: TX3DField);

    { Notifications when exposed field received new value through VRML/X3D event.
      Use only for exposed fields.
      This is simply a shortcut for @code(EventOut.AddNotification),
      @code(EventOut.RemoveNotification),
      see @link(TX3DEvent.AddNotification) for details how does this work.

      Note that this observes the "out" event (not the "in" event).
      This way you know inside the handler that the field value is already
      changed as appropriate. Inside "in" event handlers, you would not
      know this (it would depend on the order in which handlers are run,
      one "in" handler sets the field value).

      Note that "out" event handlers are executed before Scene is notified
      about the field value change (before TCastleSceneCore.InternalChangedField is called).
      This is also usually exactly what you want --- you can change the scene
      graph inside the event handler (for example, load something on
      Inline.load or Inline.url changes), and let the TX3DField.ChangesAlways
      cause appropriate action on this change. }
    procedure AddNotification(const Notification: TX3DEventReceive);
    procedure RemoveNotification(const Notification: TX3DEventReceive);
  end;

  TX3DFieldList = class({$ifdef CASTLE_OBJFPC}specialize{$endif} TObjectList<TX3DField>)
  strict private
    function GetByName(const AName: string): TX3DField;
  public
    { Access field by name.
      Raises EX3DNotFound if the given Name doesn't exist. }
    property ByName[const AName: string]: TX3DField read GetByName;

    { Searches for a field with given Name, returns it's index or -1 if not found. }
    function IndexOfName(const AName: string): integer;

    { Returns if EventName is an event implicitly exposed by one of our
      exposed fields (i.e. set_xxx or xxx_changed). If yes, then
      returns index of event, and the event reference itself
      (so always @code(Fields[ReturnedIndex].ExposedEvent[ReturnedEvent.InEvent]
      = ReturnedEvent)). Otherwise, returns -1. }
    function IndexOfExposedEvent(const EventName: string;
      out Event: TX3DEvent): Integer;
  end;

{$endif read_interface}

{$ifdef read_implementation}

{ TX3DField ------------------------------------------------------------- }

constructor TX3DField.Create(const AParentNode: TX3DFileItem;
  const AExposed: boolean; const AName: string);
begin
  CreateUndefined(AParentNode, AExposed, AName);
end;

constructor TX3DField.CreateUndefined(const AParentNode: TX3DFileItem;
  const AExposed: boolean; const AName: string);
begin
  inherited Create(AParentNode, AName);
  FExposedEventsLinked := true;

  { Set Exposed by the property, to force FExposedEvents initialization }
  FExposed := false;
  Exposed := AExposed;
end;

destructor TX3DField.Destroy;
begin
  FreeAndNil(FExposedEvents[false]);
  FreeAndNil(FExposedEvents[true]);
  inherited;
end;

function TX3DField.GetExposedEvents(InEvent: boolean): TX3DEvent;
begin
  Result := FExposedEvents[InEvent];
end;

function TX3DField.EventIn: TX3DEvent;
begin
  Result := FExposedEvents[true];
end;

function TX3DField.EventOut: TX3DEvent;
begin
  Result := FExposedEvents[false];
end;

procedure TX3DField.ExposedEventReceive(Event: TX3DEvent; Value: TX3DField;
  const Time: TX3DTime);
var
  ValuePossiblyChanged: boolean;
begin
  Assert(Exposed);
  Assert(Event = FExposedEvents[true]);
  Assert(Value is ExposedEventsFieldClass);

  { When not ValuePossiblyChanged, we don't have to call InternalChangedField.
    (Although we still have to call FExposedEvents[false].Send,
    to push the change through the routes.)
    This may be an important optimization when simple field's change
    causes large time-consuming work in InternalChangedField, e.g. consider
    Switch.whichChoice which means currently rebuilding a lot of things. }
  ValuePossiblyChanged := not FastEqualsValue(Value);

  { This is trivial handling of exposed events: just set our value,
    and call out event. }

  AssignValue(Value);

  FExposedEvents[false].Send(Value, Time);

  { Tests:
  if not ValuePossiblyChanged then
    writeln('ignored field ', Name, ' change, since values the same'); }
  if ValuePossiblyChanged then
    Changed;
end;

procedure TX3DField.Changed;
var
  Parent: TX3DNode;
begin
  if ParentNode <> nil then
  begin
    Parent := ParentNode as TX3DNode;
    if Parent.Scene <> nil then
      Parent.Scene.InternalChangedField(Self);
  end;
end;

function TX3DField.ExecuteChanges: TX3DChanges;
begin
  Result := ChangesAlways;
end;

function TX3DField.SendsByEvent: boolean;
begin
  Result :=
    Exposed and
    (ParentNode <> nil) and
    ((ParentNode as TX3DNode).Scene <> nil);
end;

procedure TX3DField.Send(Value: TX3DField);
var
  ValuePossiblyChanged: boolean;
begin
  if SendsByEvent then
  begin
    EventIn.Send(Value, TX3DNode(ParentNode).Scene.NextEventTime);
  end else
  begin
    ValuePossiblyChanged := not FastEqualsValue(Value);
    { Call AssignValue regardless of ValuePossiblyChanged.
      Reason: AssignValue also removes "IS" clause. }
    AssignValue(Value);
    if ValuePossiblyChanged then Changed;
  end;
end;

const
  SetPrefix = 'set_';
  ChangedSuffix = '_changed';

procedure TX3DField.SetExposedEventsLinked(const Value: boolean);
begin
  if FExposedEventsLinked <> Value then
  begin
    FExposedEventsLinked := Value;
    if Exposed then
    begin
      if ExposedEventsLinked then
        FExposedEvents[true].AddNotification(
          {$ifdef CASTLE_OBJFPC}@{$endif} ExposedEventReceive)
      else
        FExposedEvents[true].RemoveNotification(
          {$ifdef CASTLE_OBJFPC}@{$endif} ExposedEventReceive);
    end;
  end;
end;

class function TX3DField.ExposedEventsFieldClass: TX3DFieldClass;
begin
  Result := TX3DFieldClass(ClassType);
end;

class function TX3DField.CreateEvent(const AParentNode: TX3DFileItem; const AName: string; const AInEvent: boolean): TX3DEvent;
begin
  Result := TX3DEvent.Create(AParentNode, AName, ExposedEventsFieldClass, AInEvent);
end;

procedure TX3DField.SetExposed(Value: boolean);
var
  I: Integer;
begin
  if Value <> Exposed then
  begin
    FExposed := Value;
    if Exposed then
    begin
      FExposedEvents[false] := CreateEvent(ParentNode, X3DName + ChangedSuffix, false);
      FExposedEvents[false].ParentExposedField := Self;
      FExposedEvents[true] := CreateEvent(ParentNode, SetPrefix + X3DName, true);
      FExposedEvents[true].ParentExposedField := Self;

      for I := Low(FAlternativeNames) to High(FAlternativeNames) do
        if FAlternativeNames[I] <> '' then
        begin
          FExposedEvents[false].AddAlternativeName(
            FAlternativeNames[I] + ChangedSuffix, I);
          FExposedEvents[true].AddAlternativeName(
            SetPrefix + FAlternativeNames[I], I);
        end;

      if ExposedEventsLinked then
        FExposedEvents[true].AddNotification(
          {$ifdef CASTLE_OBJFPC}@{$endif} ExposedEventReceive);
    end else
    begin
      if ExposedEventsLinked then
        FExposedEvents[true].RemoveNotification(
          {$ifdef CASTLE_OBJFPC}@{$endif} ExposedEventReceive);

      FreeAndNil(FExposedEvents[false]);
      FreeAndNil(FExposedEvents[true]);
    end;
  end;
end;

procedure TX3DField.FieldSaveToStream(Writer: TX3DWriter;
  FieldSaveWhenDefault, XmlAvoidSavingNameBeforeValue: boolean);
var
  N: string;
begin
  N := NameForVersion(Writer);

  if (not ValueFromIsClause) and
     (FieldSaveWhenDefault or (not EqualsDefaultValue)) then
  case Writer.Encoding of
    xeClassic:
      begin
        if N <> '' then
          Writer.WriteIndent(N + ' ');
        SaveToStreamValue(Writer);
        Writer.Writeln;
      end;
    xeXML:
      { for xml encoding, field must be named, unless explicitly not wanted by XmlAvoidSavingNameBeforeValue }
      if (N <> '') or XmlAvoidSavingNameBeforeValue then
      begin
        if (SaveToXml in [sxAttribute, sxAttributeCustomQuotes]) and
           (not XmlAvoidSavingNameBeforeValue) then
        begin
          Writer.Writeln;
          Writer.WriteIndent(N + '=');
        end;
        if SaveToXml = sxAttribute then
          Writer.Write('"');
        SaveToStreamValue(Writer);
        if SaveToXml = sxAttribute then
          Writer.Write('"');
      end;
    else raise EInternalError.Create('TX3DField.FieldSaveToStream Encoding?');
  end;
end;

procedure TX3DField.SaveToStream(Writer: TX3DWriter);
begin
  FieldSaveToStream(Writer);
end;

function TX3DField.SaveToXmlValue: TSaveToXmlMethod;
begin
  Result := sxAttribute;
end;

function TX3DField.SaveToXml: TSaveToXmlMethod;
begin
  { Detect sxNone for XML encoding, this allows better output in many cases,
    also avoids <fieldValue> inside <ProtoInstance> when the field value actually
    doesn't have to be specified.
    When FieldSaveToStream saves field value? FieldSaveToStream checks

     (not ValueFromIsClause) and
     (FieldSaveWhenDefault or (not EqualsDefaultValue))

    SaveToStream calls FieldSaveToStream with default FieldSaveWhenDefault = false. }

  if (not ValueFromIsClause) and (not EqualsDefaultValue) then
    Result := SaveToXmlValue else
    Result := sxNone;
end;

function TX3DField.EqualsDefaultValue: boolean;
begin
  Result := false;
end;

function TX3DField.Equals(SecondValue: TX3DField): boolean;
begin
  Result := SecondValue.X3DName = X3DName;
end;

function TX3DField.FastEqualsValue(SecondValue: TX3DField): boolean;
begin
  Result := false;
end;

procedure TX3DField.Parse(Lexer: TX3DLexer; Reader: TX3DReader; IsClauseAllowed: boolean);
begin
  if IsClauseAllowed and Lexer.TokenIsKeyword(vkIS) then
    ParseIsClause(Lexer) else
    ParseValue(Lexer, Reader);
end;

procedure TX3DField.ParseXMLAttributeLexer(Lexer: TX3DLexer; Reader: TX3DReader);
begin
  ParseValue(Lexer, Reader);
end;

procedure TX3DField.ParseXMLAttribute(const AttributeValue: string; Reader: TX3DReader);
var
  Lexer: TX3DLexer;
begin
  Lexer := TX3DLexer.CreateForPartialStream(AttributeValue, Reader.Version);
  try
    try
      ParseXMLAttributeLexer(Lexer, Reader);
    except
      on E: EX3DClassicReadError do
        WritelnWarning('VRML/X3D', 'Error when reading field "' + X3DName + '" value: ' + E.Message);
    end;
  finally FreeAndNil(Lexer) end;
end;

procedure TX3DField.ParseXMLElement(Element: TDOMElement; Reader: TX3DReader);
var
  I: TXMLElementIterator;
begin
  I := Element.ChildrenIterator;
  try
    if I.GetNext then
      WritelnWarning('VRML/X3D', Format('X3D field "%s" is not SFNode or MFNode, but a node value (XML element "%s") is specified',
        [X3DName, I.Current.TagName]));
  finally FreeAndNil(I) end;
end;

procedure TX3DField.VRMLFieldAssignCommon(Source: TX3DField);
var
  NameChanges, ExposedChanges: boolean;
  I: Integer;
begin
  NameChanges := X3DName <> Source.X3DName;
  ExposedChanges := Exposed <> Source.Exposed;

  FieldOrEventAssignCommon(Source);

  ValueFromIsClause := Source.ValueFromIsClause;

  Exposed := Source.Exposed;
  Assert(Exposed = (ExposedEvents[false] <> nil));
  Assert(Exposed = (ExposedEvents[true] <> nil));

  { This is a little tricky: we copied Exposed value by SetExposed,
    to actually create or destroy exposed events.

    But note that events in
    ExposedEvents have names dependent on our name. So we have to eventually
    change their names too. This is not needed if exposed
    changes from true->false (then events will be destroyed),
    changes from false->true (then events will be created with already new names),
    stays as false->false (then events don't exist).
    So it's needed only when exposed was true, and stays true, but name changed.
  }
  if NameChanges and Exposed and (not ExposedChanges) then
  begin
    FExposedEvents[false].FX3DName := X3DName + ChangedSuffix;
    FExposedEvents[true].FX3DName := SetPrefix + X3DName;
  end;

  Assert((not Exposed) or (FExposedEvents[false].FX3DName = X3DName + ChangedSuffix));
  Assert((not Exposed) or (FExposedEvents[true].FX3DName = SetPrefix + X3DName));

  { Once again an issue with dependency of ExposedEvents on our name:
    potentially alternative names changed,
    so we have to redo this in exposed events. }
  if Exposed then
  begin
    for I := Low(FAlternativeNames) to High(FAlternativeNames) do
      if FAlternativeNames[I] <> '' then
      begin
        FExposedEvents[false].AddAlternativeName(FAlternativeNames[I] + ChangedSuffix, I);
        FExposedEvents[true].AddAlternativeName(SetPrefix + FAlternativeNames[I], I);
      end else
      begin
        FExposedEvents[false].RemoveAlternativeName(I);
        FExposedEvents[true].RemoveAlternativeName(I);
      end;
  end;
end;

procedure TX3DField.AssignValueRaiseInvalidClass(Source: TX3DField);
begin
  raise EX3DFieldAssignInvalidClass.CreateFmt('Cannot assign VRML/X3D field ' +
    '%s (%s) from %s (%s)',
    [        X3DName,        X3DType,
      Source.X3DName, Source.X3DType]);
end;

procedure TX3DField.AssignValue(Source: TX3DField);
begin
  ValueFromIsClause := false;
end;

procedure TX3DField.AssignDefaultValueFromValue;
begin
  { do nothing in this class }
end;

procedure TX3DField.AssignLerp(const A: Double; Value1, Value2: TX3DField);
begin
  { do nothing, CanAssignLerp is false }
end;

function TX3DField.CanAssignLerp: boolean;
begin
  Result := false;
end;

procedure TX3DField.AddAlternativeName(const AlternativeName: string;
  const X3DMajorVersion: Integer);
begin
  inherited;

  if Exposed then
  begin
    Assert(FExposedEvents[false] <> nil);
    Assert(FExposedEvents[true] <> nil);

    FExposedEvents[false].AddAlternativeName(
      AlternativeName + ChangedSuffix, X3DMajorVersion);
    FExposedEvents[true].AddAlternativeName(
      SetPrefix + AlternativeName, X3DMajorVersion);
  end;
end;

{ Note that TX3DField.X3DType cannot be abstract:
  it may be used if source event is of XFAny type in warning message
  in TX3DRoute.SetEndingInternal }
class function TX3DField.X3DType: string;
begin
  Result := 'XFAny';
end;

class function TX3DField.TypeName: string;
begin
  Result := X3DType;
end;

procedure TX3DField.AddNotification(const Notification: TX3DEventReceive);
begin
  Assert(Exposed, 'Use TX3DField.AddNotification only on Exposed fields');
  FExposedEvents[false].AddNotification(Notification);
end;

procedure TX3DField.RemoveNotification(const Notification: TX3DEventReceive);
begin
  Assert(Exposed, 'Use TX3DField.RemoveNotification only on Exposed fields');
  FExposedEvents[false].RemoveNotification(Notification);
end;

{ TX3DFieldList ------------------------------------------------------------- }

function TX3DFieldList.IndexOfName(const AName: string): integer;
begin
  for Result := 0 to Count-1 do
    if Items[Result].IsName(AName) then
      Exit;
  Result := -1;
end;

function TX3DFieldList.GetByName(const AName: string): TX3DField;
var
  I: integer;
begin
  I := IndexOfName(AName);
  if I <> -1 then
    Result := Items[I] else
    raise EX3DNotFound.CreateFmt('Field name "%s" not found', [AName]);
end;

function TX3DFieldList.IndexOfExposedEvent(const EventName: string;
  out Event: TX3DEvent): Integer;
var
  InEvent: boolean;
begin
  { This implementation is quite optimized.
    Instead of browsing all fields and their ExposedEvents,
    looking for EventName event, instead we examine EventName
    to look whether this has any chance of being set_xxx or xxx_changed
    event. So we utilize the fact that exposed events have consistent
    naming. }

  if IsPrefix(SetPrefix, EventName, false) then
  begin
    InEvent := true;
    Result := IndexOfName(SEnding(EventName, Length(SetPrefix) + 1));
  end else
  if IsSuffix(ChangedSuffix, EventName, false) then
  begin
    InEvent := false;
    Result := IndexOfName(Copy(EventName, 1,
      Length(EventName) - Length(ChangedSuffix)));
  end else
    Result := -1;

  { check is field really exposed now }
  if (Result <> -1) and (not Items[Result].Exposed) then
  begin
    Result := -1;
  end;

  if Result <> -1 then
  begin
    Event := Items[Result].ExposedEvents[InEvent];
  end;
end;

{$endif read_implementation}
