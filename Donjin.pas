unit Donjin;

interface

uses
  Windows, Forms, SysUtils;

function  DJInitCard: Integer;
procedure DJFreeCard;
function  DJCallPhone(const ID: Integer; const PhoneNum: string): Boolean;
procedure DJProcessPhone;
function  DJCheckPhone(const ID: Integer): Integer;
procedure DJHangUpPhone(const ID: Integer);
function  DJPhoneRecord(const ID: Integer; const PhoneNum: string): string;
function  DJPhoneBusy(const ID: Integer): Boolean;
function  DJSwitchOn(const ID: Integer): Boolean;
function  DJSendDial(const ID: Integer): Boolean;
function  DJPlayFile(const ID: Integer; const FileName: string): Boolean;
function  DJCheckType(const ID: Integer): Integer;
function  DJKeyCode(const ID: Integer): Char;
procedure DJLoadSayRes(const ID: Integer);
procedure DJPlaySayRes(const ID: Integer; const Say: string);

implementation

//{$R SAYTIME.RES}

uses
  CoTypes, CoWinUtils, CoUtils;

const
  S_NORESULT = $10;
  S_BUSY     = $11;
  S_NOBODY   = $13;
  S_CONNECT  = $14;
  S_NOSIGNAL = $15;
  S_DIALSIG  = $30;

var
  GSayFiles: TStringArray;

{$IFDEF DJ_LIB_LOAD}

var
  LoadApiSuccess: Boolean = False;

type
  TSig_Init = function(Param: word): integer; stdcall;
  TSig_CheckBusy = function(wChNo: word): integer; stdcall;
  TSig_StartDial = function(wChNo: word; DialNum: pchar; PreDialNum: pchar; wMode: word): integer; stdcall;
  TSig_CheckDial = function(wChNo: word): integer; stdcall;
  TSig_ResetCheck = procedure(wChNo: word); stdcall;
  TSig_GetCadenceCount = function(wChNo: word; nCadenceType: integer): integer; stdcall;
  TSig_CheckDial_New = function(wChNo: word; plConnectReason: PInteger): integer; stdcall;
  TLoadDRV = function(): LongInt; stdcall;
  TFreeDRV = procedure(); stdcall;
  TGetSysInfo = procedure(TmpIni: pointer); stdcall;
  TCheckValidCh = function(): WORD; stdcall;
  TCheckChType = function(wChnlNo: WORD): WORD; stdcall;
  TCheckChTypeNew = function(wChnlNo: word): integer; stdcall;
  TDRec_OffHookDetect = function(wChnlNo: word): boolean; stdcall;
  TIsSupportCallerID = function(): boolean; stdcall;
  TEnableCard = function(wUsedCh: WORD; wFileBufLen: WORD): LONGINT; stdcall;
  TDisableCard = procedure(); stdcall;
  TSetPackRate = function(pack: integer): Integer; stdcall;
  TPush_Play = procedure(); stdcall;
  TRingDetect = function(wChnlNo: WORD): BOOLEAN; stdcall;
  TCheckPolarity = function(chanelNo: integer): Integer; stdcall;
  TOffHook = function(chanelNo: integer): Integer; stdcall;
  THangUp = function(chanelNo: integer): Integer; stdcall;
  TInitDtmfBuf = procedure(wChnlNo: WORD); stdcall;
  TGetDtmfCode = function(wChnlNo: WORD): Shortint; stdcall;
  TDtmfHit = function(wChnlNo: WORD): boolean; stdcall;
  TStopPlay = function(chanelNo: integer): Integer; stdcall;
  TCheckPlayEnd = function(wChnlNo: WORD): BOOLEAN; stdcall;
  TReadStatus = procedure(wChnlNo: WORD; TmpRead: pointer); stdcall;
  TStartPlayFile = function(wChnlNo: WORD; FileName: PCHAR; StartPos: LONGINT): BOOLEAN; stdcall;
  TStopPlayFile = procedure(wChnlNo: WORD); stdcall;
  TStopRecord = function(chanelNo: integer): Integer; stdcall;
  TStartRecordFile = function(wChnlNo: WORD; FileName: PCHAR; dwRecordLen: LONGINT): BOOLEAN; stdcall;
  TCheckRecordEnd = function(wChnlNo: WORD): BOOLEAN; stdcall;
  TStopRecordFile = procedure(wChnlNo: WORD); stdcall;
  TFeedSigFunc = function(): Integer; stdcall;
  TStartTimer = procedure(wChnlNo: WORD; ClockType: WORD); stdcall;
  TElapseTime = function(wChnlNo: WORD; ClockType: WORD): LongInt; stdcall;
  TStartPlaySignal = function(chanelNo: integer; sigtype: integer): Integer; stdcall;
  TStartHangUpDetect = function(chanelNo: integer): Integer; stdcall;
  THangUpDetect = function(chanelNo: integer): Integer; stdcall;
  TFeedRing = procedure(wChnlNo: WORD); stdcall;
  TFeedRealRing = function(chanelNo: integer): Integer; stdcall;
  TFeedPower = function(chanelNo: integer): Integer; stdcall;
  TOffHookDetect = function(chanelNo: integer): Integer; stdcall;
  TReadGenerateSigBuf = function(lpfilename: Pchar): Integer; stdcall;
  TSendDtmfBuf = function(chanelNo: integer; dialNum: Pchar): Integer; stdcall;
  TCheckSendEnd = function(chanelNo: integer): Integer; stdcall;
  TStartSigCheck = function(chanelNo: integer): Integer; stdcall;
  TStopSigCheck = function(chanelNo: integer): Integer; stdcall;
  TReadCheckResult = function(chanelNo: integer; checkMode: integer): Integer; stdcall;
  TReadBusyCount = function(): Integer; stdcall;
  
var
  HTc08a32, HNewSig: THandle;
  DJApiLoadCount: Integer = 0;
  Sig_Init: TSig_Init;
  Sig_CheckBusy: TSig_CheckBusy;
  Sig_StartDial: TSig_StartDial;
  Sig_CheckDial: TSig_CheckDial;
  Sig_ResetCheck: TSig_ResetCheck;
  Sig_GetCadenceCount: TSig_GetCadenceCount;
  Sig_CheckDial_New: TSig_CheckDial_New;
  LoadDRV: TLoadDRV;
  FreeDRV: TFreeDRV;
  GetSysInfo: TGetSysInfo;
  CheckValidCh: TCheckValidCh;
  CheckChType: TCheckChType;
  CheckChTypeNew: TCheckChTypeNew;
  DRec_OffHookDetect: TDRec_OffHookDetect;
  IsSupportCallerID: TIsSupportCallerID;
  EnableCard: TEnableCard;
  DisableCard: TDisableCard;
  SetPackRate: TSetPackRate;
  Push_Play: TPush_Play;
  RingDetect: TRingDetect;
  CheckPolarity: TCheckPolarity;
  OffHook: TOffHook;
  HangUp: THangUp;
  InitDtmfBuf: TInitDtmfBuf;
  GetDtmfCode: TGetDtmfCode;
  DtmfHit: TDtmfHit;
  StopPlay: TStopPlay;
  CheckPlayEnd: TCheckPlayEnd;
  ReadStatus: TReadStatus;
  StartPlayFile: TStartPlayFile;
  StopPlayFile: TStopPlayFile;
  StopRecord: TStopRecord;
  StartRecordFile: TStartRecordFile;
  CheckRecordEnd: TCheckRecordEnd;
  StopRecordFile: TStopRecordFile;
  FeedSigFunc: TFeedSigFunc;
  StartTimer: TStartTimer;
  ElapseTime: TElapseTime;
  StartPlaySignal: TStartPlaySignal;
  StartHangUpDetect: TStartHangUpDetect;
  HangUpDetect: THangUpDetect;
  FeedRing: TFeedRing;
  FeedRealRing: TFeedRealRing;
  FeedPower: TFeedPower;
  OffHookDetect: TOffHookDetect;
  ReadGenerateSigBuf: TReadGenerateSigBuf;
  SendDtmfBuf: TSendDtmfBuf;
  CheckSendEnd: TCheckSendEnd;
  StartSigCheck: TStartSigCheck;
  StopSigCheck: TStopSigCheck;
  ReadCheckResult: TReadCheckResult;
  ReadBusyCount: TReadBusyCount;

function LoadDJApi: Boolean;
begin
  Result := False;
  Inc(DJApiLoadCount);
  if DJApiLoadCount > 1 then
    Exit;

  HTc08a32 := LoadLibrary('Tc08a32.dll');
  if HTc08a32 <> 0 then
  begin
    @LoadDRV := GetProcAddress(HTc08a32, 'LoadDRV');
    @FreeDRV := GetProcAddress(HTc08a32, 'FreeDRV');
    @GetSysInfo := GetProcAddress(HTc08a32, 'GetSysInfo');
    @CheckValidCh := GetProcAddress(HTc08a32, 'CheckValidCh');
    @CheckChType := GetProcAddress(HTc08a32, 'CheckChType');
    @CheckChTypeNew := GetProcAddress(HTc08a32, 'CheckChTypeNew');
    @DRec_OffHookDetect := GetProcAddress(HTc08a32, 'DRec_OffHookDetect');
    @IsSupportCallerID := GetProcAddress(HTc08a32, 'IsSupportCallerID');
    @EnableCard := GetProcAddress(HTc08a32, 'EnableCard');
    @DisableCard := GetProcAddress(HTc08a32, 'DisableCard');
    @SetPackRate := GetProcAddress(HTc08a32, 'SetPackRate');
    @Push_Play := GetProcAddress(HTc08a32, 'PUSH_PLAY');
    @RingDetect := GetProcAddress(HTc08a32, 'RingDetect');
    @CheckPolarity := GetProcAddress(HTc08a32, 'CheckPolarity');
    @OffHook := GetProcAddress(HTc08a32, 'OffHook');
    @HangUp := GetProcAddress(HTc08a32, 'HangUp');
    @InitDtmfBuf := GetProcAddress(HTc08a32, 'InitDtmfBuf');
    @GetDtmfCode := GetProcAddress(HTc08a32, 'GetDtmfCode');
    @DtmfHit := GetProcAddress(HTc08a32, 'DtmfHit');
    @StopPlay := GetProcAddress(HTc08a32, 'StopPlay');
    @CheckPlayEnd := GetProcAddress(HTc08a32, 'CheckPlayEnd');
    @ReadStatus := GetProcAddress(HTc08a32, 'ReadStatus');
    @StartPlayFile := GetProcAddress(HTc08a32, 'StartPlayFile');
    @StopPlayFile := GetProcAddress(HTc08a32, 'StopPlayFile');
    @StopRecord := GetProcAddress(HTc08a32, 'StopRecord');
    @StartRecordFile := GetProcAddress(HTc08a32, 'StartRecordFile');
    @CheckRecordEnd := GetProcAddress(HTc08a32, 'CheckRecordEnd');
    @StopRecordFile := GetProcAddress(HTc08a32, 'StopRecordFile');
    @FeedSigFunc := GetProcAddress(HTc08a32, 'FeedSigFunc');
    @StartTimer := GetProcAddress(HTc08a32, 'StartTimer');
    @ElapseTime := GetProcAddress(HTc08a32, 'ElapseTime');
    @StartPlaySignal := GetProcAddress(HTc08a32, 'StartPlaySignal');
    @StartHangUpDetect := GetProcAddress(HTc08a32, 'StartHangUpDetect');
    @HangUpDetect := GetProcAddress(HTc08a32, 'HangUpDetect');
    @FeedRing := GetProcAddress(HTc08a32, 'FeedRing');
    @FeedRealRing := GetProcAddress(HTc08a32, 'FeedRealRing');
    @FeedPower := GetProcAddress(HTc08a32, 'FeedPower');
    @OffHookDetect := GetProcAddress(HTc08a32, 'OffHookDetect');
    @ReadGenerateSigBuf := GetProcAddress(HTc08a32, 'ReadGenerateSigBuf');
    @SendDtmfBuf := GetProcAddress(HTc08a32, 'SendDtmfBuf');
    @CheckSendEnd := GetProcAddress(HTc08a32, 'CheckSendEnd');
    @StartSigCheck := GetProcAddress(HTc08a32, 'StartSigCheck');
    @StopSigCheck := GetProcAddress(HTc08a32, 'StopSigCheck');
    @ReadCheckResult := GetProcAddress(HTc08a32, 'ReadCheckResult');
    @ReadBusyCount := GetProcAddress(HTc08a32, 'ReadBusyCount');
  end;
  HNewSig := LoadLibrary('NewSig.dll');
  if HNewSig <> 0 then
  begin
    @Sig_Init := GetProcAddress(HNewSig, 'Sig_Init');
    @Sig_CheckBusy := GetProcAddress(HNewSig, 'Sig_CheckBusy');
    @Sig_StartDial := GetProcAddress(HNewSig, 'Sig_StartDial');
    @Sig_CheckDial := GetProcAddress(HNewSig, 'Sig_CheckDial');
    @Sig_ResetCheck := GetProcAddress(HNewSig, 'Sig_ResetCheck');
    @Sig_GetCadenceCount := GetProcAddress(HNewSig, 'Sig_GetCadenceCount');
    @Sig_CheckDial_New := GetProcAddress(HNewSig, 'Sig_CheckDial_New');
  end;
  Result := (HTc08a32 <> 0) and (HNewSig <> 0);
end;

procedure UnloadDJApi;
begin
  Dec(DJApiLoadCount);
  if DJApiLoadCount > 0 then
    Exit;
  FreeLibrary(HTc08a32);
  FreeLibrary(HNewSig);
  Sig_Init := nil;
  Sig_CheckBusy := nil;
  Sig_StartDial := nil;
  Sig_CheckDial := nil;
  Sig_ResetCheck := nil;
  Sig_GetCadenceCount := nil;
  Sig_CheckDial_New := nil;
  LoadDRV := nil;
  FreeDRV := nil;
  GetSysInfo := nil;
  CheckValidCh := nil;
  CheckChType := nil;
  CheckChTypeNew := nil;
  DRec_OffHookDetect := nil;
  IsSupportCallerID := nil;
  EnableCard := nil;
  DisableCard := nil;
  SetPackRate := nil;
  Push_Play := nil;
  RingDetect := nil;
  CheckPolarity := nil;
  OffHook := nil;
  HangUp := nil;
  InitDtmfBuf := nil;
  GetDtmfCode := nil;
  DtmfHit := nil;
  StopPlay := nil;
  CheckPlayEnd := nil;
  ReadStatus := nil;
  StartPlayFile := nil;
  StopPlayFile := nil;
  StopRecord := nil;
  StartRecordFile := nil;
  CheckRecordEnd := nil;
  StopRecordFile := nil;
  FeedSigFunc := nil;
  StartTimer := nil;
  ElapseTime := nil;
  StartPlaySignal := nil;
  StartHangUpDetect := nil;
  HangUpDetect := nil;
  FeedRing := nil;
  FeedRealRing := nil;
  FeedPower := nil;
  OffHookDetect := nil;
  ReadGenerateSigBuf := nil;
  SendDtmfBuf := nil;
  CheckSendEnd := nil;
  StartSigCheck := nil;
  StopSigCheck := nil;
  ReadCheckResult := nil;
  ReadBusyCount := nil;
end;

{$ELSE}

var
  LoadApiSuccess: Boolean = True;

function LoadDRV() : LongInt; stdcall; far  external 'Tc08a32.dll';
procedure FreeDRV();  stdcall; far external 'Tc08a32.dll';
procedure GetSysInfo(TmpIni:pointer); stdcall; far external 'Tc08a32.dll';
function CheckValidCh() : WORD; stdcall; far external 'Tc08a32.dll';
function CheckChType(wChnlNo : WORD): WORD; stdcall; far external 'Tc08a32.dll';
function CheckChTypeNew(wChnlNo:word):integer;stdcall; far external 'Tc08a32.dll';
function DRec_OffHookDetect(wChnlNo:word):boolean;stdcall; far external 'Tc08a32.dll';
function IsSupportCallerID():boolean; stdcall; far external 'Tc08a32.dll';
function EnableCard(wUsedCh : WORD; wFileBufLen:WORD) : LONGINT; stdcall; far  external 'Tc08a32.dll';
procedure DisableCard(); stdcall; far external 'Tc08a32.dll';
function SetPackRate( pack:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
procedure PUSH_PLAY(); stdcall; far external 'Tc08a32.dll';
function RingDetect(wChnlNo:WORD) : BOOLEAN; stdcall; far external 'Tc08a32.dll';
function CheckPolarity( chanelNo:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
function OffHook(chanelNo:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
function HangUp(chanelNo:integer) :Integer;  stdcall; far  external 'Tc08a32.dll';

function Sig_Init(Param:word):integer; stdcall; external 'Newsig.dll';
function Sig_CheckBusy(wChNo:word):integer;stdcall; external 'Newsig.dll';
function Sig_StartDial(wChNo:word;DialNum:pchar;PreDialNum:pchar;wMode:word):integer;stdcall; external 'Newsig.dll';
function Sig_CheckDial(wChNo:word):integer;stdcall; external 'Newsig.dll';
procedure Sig_ResetCheck(wChNo:word);stdcall; external 'Newsig.dll';
function Sig_GetCadenceCount(wChNo:word;nCadenceType:integer):integer;stdcall; external 'Newsig.dll';
function Sig_CheckDial_New(wChNo:word; plConnectReason: PInteger):integer;stdcall; external 'Newsig.dll';

function SetLink( one:integer;another:integer):Integer; stdcall; far  external 'Tc08a32.dll';
function ClearLink( one:integer;another:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
function LinkOneToAnother (wOne:WORD; wAnother:WORD ):LongInt;stdcall; far  external 'Tc08a32.dll';
function ClearOneFromAnother ( wOne:WORD; wAnother:WORD ):LongInt;stdcall; far  external 'Tc08a32.dll';
function LinkThree(wOne:WORD;wTwo:WORD;wThree:WORD):LongInt;stdcall; far  external 'Tc08a32.dll';
function ClearThree(wOne:WORD;wTwo:WORD;wThree:WORD):LongInt;stdcall; far  external 'Tc08a32.dll';

procedure InitDtmfBuf(wChnlNo: WORD); stdcall; far external 'Tc08a32.dll';
function GetDtmfCode(wChnlNo : WORD) :Shortint; stdcall; far  external 'Tc08a32.dll';
function DtmfHit(wChnlNo:WORD ):boolean; stdcall; far  external 'Tc08a32.dll';

function StartSigCheck( chanelNo:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
function StopSigCheck( chanelNo:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
function ReadCheckResult( chanelNo:integer;checkMode:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
function ReadBusyCount :Integer; stdcall;  far  external 'Tc08a32.dll';

function SetBusyPara( busylen:integer):Integer; stdcall;  far  external 'Tc08a32.dll';
function SetDialPara( ringBack1:integer;ringBack0:integer;busyLen:integer;ringTimes:integer):Integer; stdcall; far  external 'Tc08a32.dll';
procedure ReadSigBuf (wChnlNo:WORD;pwStartPoint:pointer;pwCount:pointer;SigBuf:array of byte); stdcall; far  external 'Tc08a32.dll';

function StopPlay(chanelNo:integer):Integer;  stdcall; far  external 'Tc08a32.dll';
function CheckPlayEnd (wChnlNo : WORD ) : BOOLEAN; stdcall; far  external 'Tc08a32.dll';
procedure ReadStatus (wChnlNo: WORD;TmpRead:pointer); stdcall; far  external 'Tc08a32.dll';

function StartPlayFile (wChnlNo : WORD;FileName: PCHAR; StartPos: LONGINT ) : BOOLEAN; stdcall; far external 'Tc08a32.dll';
procedure StopPlayFile (wChnlNo : WORD); stdcall; external 'Tc08a32.dll';

procedure RsetIndexPlayFile( chanelNo:integer); stdcall; far  external 'Tc08a32.dll';
function AddIndexPlayFile( chanelNo:integer;filename:Pchar) :Integer; stdcall; far  external 'Tc08a32.dll';
function StartIndexPlayFile( chanelNo:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
function CheckIndexPlayFile( chanelNo:integer) :integer; stdcall;  far  external 'Tc08a32.dll';
procedure StopIndexPlayFile( chanelNo:integer); stdcall; far  external 'Tc08a32.dll';

procedure ResetIndex(); stdcall; far  external 'Tc08a32.dll';
function SetIndex(VocBuf:PChar;dwVocLen:WORD):boolean;  stdcall; far  external 'Tc08a32.dll';
procedure StartPlayIndex(wChnlNo: WORD ;pIndexTable:array of WORD;wIndexLen:WORD ); stdcall; far  external 'Tc08a32.dll';

function SendDtmfBuf( chanelNo:integer;dialNum:Pchar) :Integer;  stdcall; far  external 'Tc08a32.dll';
function CheckSendEnd( chanelNo:integer) :Integer;  stdcall; far  external 'Tc08a32.dll';

function StopRecord( chanelNo:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
function StartRecordFile (wChnlNo:WORD; FileName : PCHAR;dwRecordLen:LONGINT ):BOOLEAN; stdcall; external 'Tc08a32.dll';
function CheckRecordEnd ( wChnlNo:WORD ):BOOLEAN; stdcall; external 'Tc08a32.dll';
procedure StopRecordFile (wChnlNo:WORD); stdcall; external 'Tc08a32.dll';

function FeedSigFunc:Integer; stdcall; far  external 'Tc08a32.dll';
procedure StartTimer(wChnlNo:WORD;ClockType:WORD ); stdcall; far  external 'Tc08a32.dll';
function ElapseTime (wChnlNo: WORD ;ClockType:WORD  ):LongInt; stdcall; far  external 'Tc08a32.dll';
function StartPlaySignal( chanelNo:integer;sigtype:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
function StartHangUpDetect( chanelNo:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
function HangUpDetect( chanelNo:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
procedure FeedRing(wChnlNo:WORD );stdcall; far  external 'Tc08a32.dll';
function FeedRealRing( chanelNo:integer) :Integer; stdcall;  far  external 'Tc08a32.dll';
function FeedPower( chanelNo:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
function OffHookDetect( chanelNo:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
function ReadGenerateSigBuf( lpfilename:Pchar) :Integer; stdcall;  far  external 'Tc08a32.dll';

procedure ResetCallerIDBuffer(wChnlNo:WORD);stdcall;  far  external 'Tc08a32.dll';
function GetCallerIDRawStr (wChnlNo:WORD ;IDRawStr:PChar):WORD; stdcall;  far  external 'Tc08a32.dll';
function GetCallerIDStr (wChnlNo:WORD;IDStr:PChar):WORD;stdcall;  far  external 'Tc08a32.dll';


function StartRecordFileNew(wChnlNo: WORD;FileName:PChar;dwRecordLen:DWORD;dwRecordStartPos:DWORD):boolean;stdcall;  far  external 'Tc08a32.dll';
function NewReadPass(wCardNo: WORD ):LongInt;stdcall;  far  external 'Tc08a32.dll';
function CheckSilence( chanelNo:integer) :Integer; stdcall; far  external 'Tc08a32.dll';

function SetSendPara (ToneLen:Integer;SilenceLen:Integer ):Integer;stdcall; far  external 'Tc08a32.dll';
procedure NewSendDtmfBuf(ChannelNo:Integer;DialNum:PChar);stdcall; far  external 'Tc08a32.dll';
function NewCheckSendEnd(ChannelNo:Integer):Integer;stdcall; far  external 'Tc08a32.dll';

function SetSigPara( AlNo:integer;clNo:integer) :Integer; stdcall; far  external 'Tc08a32.dll';
procedure StartPlay(wChnlNo:WORD;PlayBuf:PChar;dwStartPos:WORD;dwPlayLen:DWORD);stdcall; far  external 'Tc08a32.dll';

{$ENDIF}

function WavToPcm(const FileName: string): string;
begin
  if FileExists(FileName) then
  begin
    //
    SysUtils.DeleteFile(FileName);
  end;
end;

function ConvStr(const Value: Integer): Char;
begin
  Result := #0;
  case Value of
    10:   Result := '0';
    11:   Result := '*';
    12:   Result := '#';
    13:   Result := 'A';
    14:   Result := 'B';
    15:   Result := 'C';
    0:    Result := 'D';
    1..9: Result := PChar(IntToStr(Value))[0];
  end;
end;

function DJInitCard: Integer;
begin
  Result := 0;
  if LoadApiSuccess then
  begin
    try
      LoadDRV;
      Result := CheckValidCh;
      EnableCard(Result, 1024 * 59);
      SetPackRate(0);
      Sig_Init(0);
    except
      Application.MessageBox('语音卡加载不成功!', PChar(Application.Title), MB_ICONERROR);
    end;
  end;
end;

procedure DJFreeCard;
begin
  if LoadApiSuccess then
  begin
    DisableCard;
    FreeDRV;
  end;
end;

function DJCallPhone(const ID: Integer; const PhoneNum: string): Boolean;
begin
  OffHook(ID);
  InitDTMFBuf(ID);
  Result := Sig_StartDial(ID, PChar(PhoneNum), '', 0) = 1;
end;

procedure DJProcessPhone;
begin
  Push_Play;
  FeedSigFunc;
end;

function DJCheckPhone(const ID: Integer): Integer;
var
  LState: Integer;
begin
  Result := 0;
  LState := Sig_CheckDial(ID);
  case LState of
    S_CONNECT:  Result := 1;
    S_BUSY:     Result := -1;
    S_NOBODY:   Result := -2;
    S_NOSIGNAL: Result := -3;
    S_NORESULT: Result := -4;
  end;
end;

procedure DJHangUpPhone(const ID: Integer);
begin
  HangUp(ID);
  StartSigCheck(ID);
  StopRecordFile(ID);
  Sig_ResetCheck(ID);
  StopIndexPlayFile(ID);
end;

function DJPhoneRecord(const ID: Integer; const PhoneNum: string): string;
begin
  if CheckPlayEnd(ID) then
  begin
    Result := ExtractFilePath(Application.ExeName) + FormatDateTime('yyyy-MM-dd', Now) + '\' + PhoneNum + '.pcm';
    ForceDirectories(ExtractFilePath(Result));
    StopPlayFile(ID);
    StartRecordFile(ID, PChar(Result), 8000 * 60);
    InitDtmfBuf(ID);
  end;
end;

function DJPhoneBusy(const ID: Integer): Boolean;
begin
  Result := False;
  if (Sig_CheckBusy(ID) = 1) then
  begin
    StopPlayFile(ID);
    Result := True;
  end;
end;

function DJSwitchOn(const ID: Integer): Boolean;
begin
  OffHook(ID);
  InitDTMFBuf(ID);
  StartSigCheck(ID);
end;

function DJSendDial(const ID: Integer): Boolean;
begin
  Result := False;
  if (CheckSendEnd(ID) = 1) then
  begin
    StartSigCheck(ID);
    Result := True;
  end;
end;

function DJPlayFile(const ID: Integer; const FileName: string): Boolean;
begin
  Result := False;
  if FileExists(FileName) then
  begin
    InitDtmfBuf(ID);
    Result := StartPlayFile(ID, PChar(FileName), 0);
    StartTimer(ID, 4);
  end;
end;

function DJCheckType(const ID: Integer): Integer;
begin
  Result := Integer(CheckChType(ID));
end;

function DJKeyCode(const ID: Integer): Char;
begin
  Result := #0;
  if (DtmfHit(ID)) then
  begin
    StopPlayFile(ID);
    Result := ConvStr(GetDtmfCode(ID));
  end;
end;

procedure DJLoadSayRes(const ID: Integer);
begin

  //
end;

procedure DJPlaySayRes(const ID: Integer; const Say: string);
begin
  //
end;  


{$IFDEF DJ_LIB_LOAD}
initialization
  LoadApiSuccess := LoadDJApi;
finalization
  UnloadDJApi;
{$ENDIF}

end.

