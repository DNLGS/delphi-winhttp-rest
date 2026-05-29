unit ClientHttp;

interface

uses
  clientHttp.wrapper, Generics.Collections, SysUtils, Windows, Classes,
  StrUtils, ClientHttp.Utils, ClientHttp.Constantes,
  ClientHttp.Core, ClientHttp.Cert.Aux;

type
  TClientHTTP = class
  private
    FCore : TClientHttpCore;
    FHeaders: TDictionary<String, String>;
    FCertSubject: String;
    FResponse: String;
    FStatus: Integer;
    FReceiveTimeOut : DWORD;
    FConnectTimeOut : DWORD;
    FSendTimeOut : DWORD;
    FProtocols: TProtocols;
    FProtocol: DWORD;
    FResponseStream : TStream;
    FHeadersReq : TStringList;

    function EnviarReq(Metodo: TMetodo; const APayload: String; AURL: String): Boolean;
    function GetReceiveT: Integer; inline;
    procedure SetReceiveT(const Value: Integer); inline;
    function GetConnectT: Integer; inline;
    function GetSendT: Integer; inline;
    procedure SetConnectT(const Value: Integer); inline;
    procedure SetSendT(const Value: Integer); inline;
    function SetProtocol : DWORD;
  public
    function Get(const URL: String): Boolean;
    function Post(const URL, Payload: String): Boolean;
    function Put(const URL, Payload: String): Boolean;
    function Patch(const URL, Payload: String): Boolean;
    function Delete(const URL : String): Boolean;

    property Response: String read FResponse;
    property ResponseStream: TStream read FResponseStream;
    property Status: Integer read FStatus;
    property CNCertificado: String read FCertSubject write FCertSubject;
    property ReceiveTimeOut: Integer read GetReceiveT write SetReceiveT;
    property ConnectTimeOut: Integer read GetConnectT write SetConnectT;
    property Protocolos: TProtocols read FProtocols write FProtocols;
    property SendTimeOut: Integer read GetSendT write SetSendT;
    procedure AddHeaders(const AKey, AValue: String);
    property Headers: TStringList read FHeadersReq;
    procedure Clear;

    constructor Create;
    destructor Destroy; override;
  end;

implementation

procedure TClientHTTP.AddHeaders(const AKey, AValue: String);
begin
  FHeaders.AddOrSetValue(AKey, AValue);
end;

procedure TClientHTTP.Clear;
begin
  FHeaders.Clear;
  FCertSubject := '';
  FResponse := '';
  FStatus := 0;
  TMemoryStream(FResponseStream).Clear;
end;

constructor TClientHTTP.Create;
begin
  FCore := TClientHttpCore.Create;
  FHeaders := TDictionary<String, String>.Create;
  FStatus := 0;
  FReceiveTimeOut := 30000;
  FConnectTimeOut := 30000;
  FSendTimeOut := 30000;
  FProtocols := [pTLS1_1,pTLS1_2];
  FResponseStream := TMemoryStream.Create;
end;

function TClientHTTP.Delete(const URL: String): Boolean;
begin
  Result := EnviarReq(mDelete,'',URL);
end;

destructor TClientHTTP.Destroy;
begin
  FCore.Free;
  FHeaders.Free;
  FResponseStream.Free;
  inherited;
end;

function TClientHTTP.GetConnectT: Integer;
begin
  Result := Integer(FConnectTimeOut);
end;

function TClientHTTP.GetReceiveT: Integer;
begin
  Result := Integer(FReceiveTimeOut);
end;

function TClientHTTP.GetSendT: Integer;
begin
  Result := Integer(FSendTimeOut);
end;

function TClientHTTP.EnviarReq(Metodo: TMetodo; const APayload: String; AURL: String): Boolean;
const
  MethodStr: array[TMetodo] of PwChar = ('GET', 'POST', 'PUT', 'PATCH', 'DELETE');
var
  dwFlags : DWORD;
  Key : String;
  lPort : DWORD;
  lURI : PwChar;
  lHost : PwChar;
begin
  dwFlags := 0;
  FProtocol := SetProtocol;

  FStatus := 0;
  FResponse := '';
  TMemoryStream(FResponseStream).Clear;

  if TClientHTTPUtils.IsHttps(AURL) then
    dwFlags := WINHTTP_FLAG_SECURE;

  lPort := TClientHTTPUtils.GetPort(AURL);
  lHost := PwChar(TClientHTTPUtils.GetHost(AURL));
  lURI := PwChar(TClientHTTPUtils.GetURI(AURL));
  try
    FCore.Open(lHost,lURI,MethodStr[Metodo],lPort, dwFlags);
    FCore.AddPayload(APayload);
    // Add Certificado
    FCore.AddCertificadoByCN(FCertSubject);
    // Add Protocols
    FCore.SetOptionsSession(WINHTTP_OPTION_SECURE_PROTOCOLS, FProtocol);
    // Add Timeouts
    FCore.SetOptionsSession(WINHTTP_OPTION_CONNECT_TIMEOUT,FConnectTimeOut);
    FCore.SetOptionsSession(WINHTTP_OPTION_SEND_TIMEOUT,FSendTimeOut);
    FCore.SetOptionsSession(WINHTTP_OPTION_RECEIVE_TIMEOUT,FReceiveTimeOut);

    // Add Headers
    for Key in FHeaders.Keys do
    begin
      FCore.AddHeaders(PwChar(Format('%s:%s', [Key, FHeaders[Key]])),0);
    end;

    // Envio
    FCore.Send('');
    Result := True;
  except
    on E: Exception do
      raise Exception.Create(E.Message);
  end;

  FHeadersReq := FCore.Headers;
  FStatus := FCore.Status;
  FResponse := FCore.ResponseText;
  TMemoryStream(FResponseStream).LoadFromStream(FCore.Response);
end;

function TClientHTTP.Get(const URL: String): Boolean;
begin
  Result := EnviarReq(mGET,'', URL);
end;

function TClientHTTP.Patch(const URL, Payload: String): Boolean;
begin
  Result := EnviarReq(mPatch,'',URL);
end;

function TClientHTTP.Post(const URL, Payload: String): Boolean;
begin
  Result := EnviarReq(mPOST, Payload, URL);
end;

function TClientHTTP.Put(const URL, Payload: String): Boolean;
begin
  Result := EnviarReq(mPUT, Payload, URL);
end;

procedure TClientHTTP.SetConnectT(const Value: Integer);
begin
  FConnectTimeOut := DWORD(Value);
end;

function TClientHTTP.SetProtocol: DWORD;
begin
  Result := 0;

  if pSSL2 in FProtocols then
    Result := Result or WINHTTP_FLAG_SECURE_PROTOCOL_SSL2;

  if pSSL3 in FProtocols then
    Result := Result or WINHTTP_FLAG_SECURE_PROTOCOL_SSL3;

  if pTLS1_0 in FProtocols then
    Result := Result or WINHTTP_FLAG_SECURE_PROTOCOL_TLS1;

  if pTLS1_1 in FProtocols then
    Result := Result or WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_1;

  if pTLS1_2 in FProtocols then
    Result := Result or WINHTTP_FLAG_SECURE_PROTOCOL_TLS1_2;
end;

procedure TClientHTTP.SetReceiveT(const Value: Integer);
begin
  FReceiveTimeOut := DWORD(Value);
end;

procedure TClientHTTP.SetSendT(const Value: Integer);
begin
  FSendTimeOut := DWORD(Value);
end;

end.
