unit Voices;

interface

uses
  SysUtils, Classes, Contnrs, Messages, Dialogs, Windows, Forms, Consts, CoTypes;
  
type
  TCallRec = packed record
    CallPm: Integer;
    PhoneNum, Code: string;
    DateTime: TDateTime;
  end;
  PCallRec = ^TCallRec;
  TPhoneBook = class(TObject)
  private
    FList: TList;
  public
    constructor Create;
    destructor Destroy; override;
  public
    function Insert(const PhoneNum, Code: string): Integer;
    function Add(const PhoneNum, Code: string): Integer;
    function Read(var CallRec: TCallRec): Boolean;
    function IndexOf(const PhoneNum: string): Integer;
  end;
  TChannelState = (csFree, csCallIning, csCallInSuccess, csCheckSendDial, csDialing, csDialSuccess, csHangOff);
  TChannelType = (ctUser, ctTrunk, ctEmpty);
  TChannelOperate = (coError, coPlay, coKey, coRecord, coConverse, coSay, coOther);
  TOnReceiveKey = procedure(Sender: TObject; const PhoneNum, Keys: string; var Step: Integer) of object;
  TOnProcessStep = procedure(Sender: TObject; const ChennelID: Integer; const Name, Value: string; var Step: Integer) of object;
  TOnHandlUp = procedure(Sender: TObject; const PhoneNum: string; const PhoneState: Integer) of object;
  TVoiceCard = class;
  TChannel = class(TThread)
  private
    FVoiceCard: TVoiceCard;
    FHandle: THandle;
    FChannelState: TChannelState;
    FChannelType: TChannelType;
    FPhoneNum, FPhoneKey, FPhoneOp: string;
    FChannelID, FPhoneState, FStep: Integer;
    FStartTime: DWORD;
    FTimeOut: Cardinal;
    FBusy: Boolean;
    FSteps: TStrings;
    FPhoneBook: TPhoneBook;
    FOnHandlUp: TOnHandlUp;
    FOnChannelState: TChannelState;
    FOnReceiveKey: TOnReceiveKey;
    FOnProcessStep: TOnProcessStep;
    function Operate(const OpCode: string; var Name, Value: string): TChannelOperate;
    procedure ProcessDialSuccess;
    procedure ChannelHangUp;
    procedure ProcessCheckDialSend;
    procedure ProcessCallInSuccess;
    function CheckSigHangUp: Boolean;
    procedure SwitchOnCallIn;
    procedure FindPhoneBook;
    procedure ClearStatus;
    procedure ProcessStep(const OpCode: string; var Step: Integer);
    procedure DoTiming(var Message: TMessage);
  protected
    procedure Execute; override;
    procedure ChannelProcessor;
  public
    constructor Create(VoiceCard: TVoiceCard);
    destructor Destroy; override;
  public
    procedure CreateChannel(const ChennelID: Integer);
    function GetChannelType: TChannelType;
    function GetChannelStatus: TChannelState;
    function GetChannelID: Integer;
    function CallPhone(const PhoneNum: string): Boolean;
  public
    property OnHandlUp: TOnHandlUp read FOnHandlUp write FOnHandlUp;
    property OnChannelState: TChannelState read FOnChannelState write FOnChannelState;
    property OnReceiveKey: TOnReceiveKey read FOnReceiveKey write FOnReceiveKey;
    property OnProcessStep: TOnProcessStep read FOnProcessStep write FOnProcessStep;
    property Steps: TStrings read FSteps write FSteps;
  end;
  TVoiceCard = class(TObject)
  private
    FLock: TRTLCriticalSection;
    FPhoneBook: TPhoneBook;
    FChannels: array of TChannel;
    FChannelNum: Integer;
    FTimeOut: Cardinal;
    FItems: TStrings;
    FOnReceiveKey: TOnReceiveKey;
    FOnHandlUp: TOnHandlUp;
    FOnProcessStep: TOnProcessStep;
    FOnError: TNotifyEvent;
    FCheckPolarity: Boolean;
    function GetCount: Integer;
    procedure SetItems(const Value: TStrings);
    procedure Clear;
    procedure Enter;
    procedure Leave;
  public
    constructor Create(const OpCode: string);
    destructor Destroy; override;
  public
    function PhoneHangUp(const ChannelID: Integer): Boolean;
    function GetChannel(const ChannelID: Integer): Integer;
    procedure CallPhone(const PhoneNum, Code: string);
    procedure Stop;
    function Startup: Boolean;
    function GetAFreeChannel: Integer;
  public
    property Count: Integer read GetCount;
  published
    property CheckPolarity: Boolean read FCheckPolarity write FCheckPolarity;
    property Items: TStrings read FItems write SetItems;
    property OnHandlUp: TOnHandlUp read FOnHandlUp write FOnHandlUp;
    property OnReceiveKey: TOnReceiveKey read FOnReceiveKey write FOnReceiveKey;
    property OnProcessStep: TOnProcessStep read FOnProcessStep write FOnProcessStep;
    property OnError: TNotifyEvent read FOnError write FOnError;
  end;
implementation
uses
  CoStrings, Donjin;
{ TVoiceCard }

procedure TVoiceCard.CallPhone(const PhoneNum, Code: string);
begin
  FPhoneBook.Add(PhoneNum, Code);
end;

constructor TVoiceCard.Create(const OpCode: string);
var
  I: Integer;
begin
  InitializeCriticalSection(FLock);
  FCheckPolarity := False;
  FTimeOut := 60000;
  FItems := TStringList.Create;
  FPhoneBook := TPhoneBook.Create;
  try
    FChannelNum := DJInitCard;
    SetLength(FChannels, FChannelNum);
    for I := 0 to FChannelNum - 1 do
    begin
      if (TChannelType(DJCheckType(I)) <> ctEmpty) then
      begin
        FChannels[I] := TChannel.Create(Self);
        FChannels[I].CreateChannel(I);
      end;
    end;
  except
    if Assigned(FOnError) then FOnError(Self);
  end;
end;

destructor TVoiceCard.Destroy;
var
  I: Integer;
begin
  Clear;
  DJFreeCard;
  FreeAndNil(FPhoneBook);
  FreeAndNil(FItems);
  DeleteCriticalSection(FLock);
  inherited Destroy;
end;

function TVoiceCard.GetAFreeChannel: Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := Low(FChannels) to High(FChannels) do
  begin
    if (FChannels[I].GetChannelType() = ctEmpty) then continue;
    if (FChannels[I].GetChannelStatus() = csFree) then
    begin
      Result := FChannels[I].GetChannelID();
      break;
    end;
  end;
end;

function TVoiceCard.GetChannel(const ChannelID: Integer): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := Low(FChannels) to High(FChannels) do
  begin
    if (FChannels[I].GetChannelID = ChannelID) then
    begin
      Result := I;
      break;
    end;
  end;
end;

function TVoiceCard.GetCount: Integer;
begin
  Result := FChannelNum;
end;

procedure TVoiceCard.Stop;
var
  I: Integer;
begin
  for I := 0 to FChannelNum - 1 do
    if Assigned(FChannels[I]) then
      FChannels[I].Suspend;
end;

function TVoiceCard.PhoneHangUp(const ChannelID: Integer): Boolean;
var
  K: Integer;
begin
  Result := False;
  K := GetChannel(ChannelID);
  if (K <> -1) and (Assigned(FChannels[K])) then
  begin
    FChannels[K].ChannelHangUp;
    Result := True;
  end;
end;

function TVoiceCard.Startup: Boolean;
var
  I: Integer;
begin
  for I := 0 to FChannelNum - 1 do
    if Assigned(FChannels[I]) then
      FChannels[I].Resume;
  Result := True;
end;

procedure TVoiceCard.SetItems(const Value: TStrings);
begin
  if Assigned(FItems) then
    FItems.Assign(Value)
  else
    FItems := Value;
end;

procedure TVoiceCard.Clear;
var
  I: Integer;
begin
  for I := 0 to FChannelNum - 1 do
  begin
    if Assigned(FChannels[I]) then
    begin
      FChannels[I].Terminate;
      FChannels[I] := nil;
    end;
  end;
end;

procedure TVoiceCard.Enter;
begin
  EnterCriticalSection(FLock);
end;

procedure TVoiceCard.Leave;
begin
  LeaveCriticalSection(FLock);
end;

{ TChannel }

function TChannel.CallPhone(const PhoneNum: string): Boolean;
begin
  FPhoneNum := PhoneNum;
  Result := DJCallPhone(FChannelID, FPhoneNum);
  FChannelState := csCheckSendDial;
end;

procedure TChannel.ChannelProcessor;
begin
  DJProcessPhone(FChannelID);
  case FChannelState of
    csFree:
      FindPhoneBook;
    csCallIning:
      SwitchOnCallIn;
    csCallInSuccess:
      if not CheckSigHangUp then
        ProcessCallInSuccess;
    csCheckSendDial:
      ProcessCheckDialSend;
    csDialing:
      begin
        FPhoneState := DJCheckPhone(FChannelID);
        if FPhoneState > 0 then
          FChannelState := csDialSuccess
        else
          FChannelState := csHangOff;
      end;
    csDialSuccess:
      if not CheckSigHangUp then
        ProcessDialSuccess;
    csHangOff:
      ChannelHangUp;
  end;
end;

function TChannel.CheckSigHangUp: Boolean;
begin
  Result := DJPhoneBusy(FChannelID);
  if Result then
    FChannelState := csHangOff;
end;

function TChannel.Operate(const OpCode: string; var Name, Value: string): TChannelOperate;
var
  I: Integer;
begin
  Result := coError;
  //
  I := Pos('=', OpCode);
  if I <> 0 then
  begin

    Name := UpperCase(Copy(OpCode, 1, I - 1));
    Value := Copy(OpCode, Length(Name) + 2, MaxInt);
    if (Name <> '') and (Value <> '') then
    begin
      if Name = 'PLAY' then Result := coPlay
      else if Name = 'KEY' then Result := coKey
      else if Name = 'RECORD' then Result := coRecord
      else if Name = 'CONVERSE' then Result := coConverse
      else if Name = 'SAY' then Result := coSay
      else Result := coOther;
    end;
  end;
end;

constructor TChannel.Create(VoiceCard: TVoiceCard);
begin
  FVoiceCard := VoiceCard;
  FOnHandlUp := FVoiceCard.FOnHandlUp;
  FOnReceiveKey := FVoiceCard.FOnReceiveKey;
  FOnProcessStep := FVoiceCard.FOnProcessStep;
  FSteps := FVoiceCard.FItems;
  FPhoneBook := FVoiceCard.FPhoneBook;
  FHandle := Classes.AllocateHWnd(DoTiming);
  FreeOnTerminate := True;
  inherited Create(True);
end;

destructor TChannel.Destroy;
begin
  ChannelHangUp;
  Classes.DeallocateHWnd(FHandle);
  inherited Destroy;
end;

procedure TChannel.Execute;
begin
  while not Terminated do
  begin
    FVoiceCard.Enter;
    try
      Synchronize(ChannelProcessor);
      Sleep(10);
    finally
      FVoiceCard.Leave;
    end;
  end;
end;

function TChannel.GetChannelID: Integer;
begin
  Result := FChannelID;
end;

function TChannel.GetChannelStatus: TChannelState;
begin
  Result := FChannelState;
end;

procedure TChannel.ChannelHangUp;
begin
  if Assigned(FOnHandlUp) then
    FOnHandlUp(Self, FPhoneNum, FPhoneState);
  DJHangUpPhone(FChannelID);
  ClearStatus;
end;

procedure TChannel.ProcessDialSuccess;
begin
  FStep := 0;
  FStartTime := 0;
  while (FStep < Steps.Count) do
  begin
    if FStartTime = 0 then
    begin
      KillTimer(FHandle, 1);
      if SetTimer(FHandle, 1, 100, nil) = 0 then
        FStep := -1
      else
        FStartTime := GetTickCount;
    end;

    ProcessStep(Steps[FStep], FStep);
    if (FStep < Steps.Count) and (FStep > -1) then
    begin
      Inc(FStep);
      KillTimer(FHandle, 1);
      FStartTime := 0;
    end else
      Break;
  end;
  FChannelState := csHangOff;
end;

procedure TChannel.ProcessCheckDialSend;
begin
  if DJSendDial(FChannelID) then
    FChannelState := csDialing;
end;

procedure TChannel.ClearStatus;
begin
  FPhoneOp := '';
  FPhoneNum := '';
  FPhoneKey := '';
  FPhoneState := 0;
  FStep := 0;
  FChannelState := csFree;
end;

function TChannel.GetChannelType: TChannelType;
begin
  Result := TChannelType(DJCheckType(FChannelID));
end;

procedure TChannel.ProcessCallInSuccess;
begin
  FChannelState := csCheckSendDial;
end;

procedure TChannel.CreateChannel(const ChennelID: Integer);
begin
  FChannelID := ChennelID;
  FChannelType := TChannelType(DJCheckType(FChannelID));
  ClearStatus;
end;

procedure TChannel.ProcessStep(const OpCode: string; var Step: Integer);
var
  LKey: Char;
  LName, LValue: string;
begin
  case Operate(OpCode, LName, LValue) of
    coError:
      Step := -1;
    coPlay:
      if not DJPlayFile(FChannelID, LValue) then
        Step := -1;
    coRecord:
      DJPhoneRecord(FChannelID, FPhoneNum);
    coOther:
      if Assigned(FOnProcessStep) then
        FOnProcessStep(Self, FChannelID, LName, LValue, Step);
    coKey:
      if StrIsPhoneKey(LValue) then
      begin
        LKey := DJKeyCode(FChannelID);
        if LKey in StrToPhoneKey(LValue) then
        begin
          FPhoneKey := '';
          if Assigned(FOnReceiveKey) then
            FOnReceiveKey(Self, FPhoneNum, FPhoneKey, Step);
        end else
          FPhoneKey := FPhoneKey + LKey;
      end else Step := -1;
  end;
end;

procedure TChannel.SwitchOnCallIn;
begin
  DJSwitchOn(FChannelID);
  FChannelState := csCallInSuccess;
end;

procedure TChannel.FindPhoneBook;
var
  LIsCall: Boolean;
  LCallRec: TCallRec;
begin
  if Assigned(FPhoneBook) then
  begin
    LIsCall := FPhoneBook.Read(LCallRec);
    if LIsCall then
    begin
      FPhoneOp := LCallRec.Code;
      CallPhone(LCallRec.PhoneNum);
    end;
  end;
end;

procedure TChannel.DoTiming(var Message: TMessage);
begin
  with Message do
    if Msg = WM_TIMER then
    begin
      if (GetTickCount - FStartTime) / 1000.0 > FTimeOut then
      begin
        FPhoneState := -5;
        ChannelHangUp;
      end;
    end else
      Result := DefWindowProc(FHandle, Msg, wParam, lParam);
end;
{ TPhoneBook }

function TPhoneBook.Add(const PhoneNum, Code: string): Integer;
var
  L: Integer;
begin
  Result := FList.Count;
  L := IndexOf(PhoneNum);
  if L = -1 then
    Result := Insert(PhoneNum, Code)
  else begin
    if PCallRec(FList[L]).DateTime <> Date then
      Result := Insert(PhoneNum, Code);
  end;
end;

constructor TPhoneBook.Create;
begin
  FList := TList.Create;
end;

destructor TPhoneBook.Destroy;
var
  I: Integer;
begin
  for I := FList.Count - 1 downto 0 do
    Dispose(FList[I]);
  FList.Free;
  inherited Destroy;
end;

function TPhoneBook.IndexOf(const PhoneNum: string): Integer;
var
  I: Integer;
begin
  Result := -1;
  for I := 0 to FList.Count - 1 do
  begin
    if (PCallRec(FList[I])^.PhoneNum = PhoneNum) then
    begin
      Result := I;
      break;
    end;
  end;
end;

function TPhoneBook.Insert(const PhoneNum, Code: string): Integer;
var
  LCallRec: PCallRec;
begin
  New(LCallRec);
  LCallRec^.PhoneNum := PhoneNum;
  LCallRec^.Code := Code;
  LCallRec^.DateTime := Date;
  Result := FList.Add(LCallRec);
end;

function TPhoneBook.Read(var CallRec: TCallRec): Boolean;
var
  P: Pointer;
begin
  Result := False;
  if (FList.Count > 0) then
  begin
    P := FList.First;
    if Assigned(P) then
    begin
      CallRec.PhoneNum := PCallRec(P)^.PhoneNum;
      CallRec.Code := PCallRec(P)^.Code;
      CallRec.DateTime := PCallRec(P)^.DateTime;
      FList.Delete(0);
      Result := True;
    end;
  end;
end;
end.
.
