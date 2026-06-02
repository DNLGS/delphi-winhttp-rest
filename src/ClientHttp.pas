unit ClientHttp;

interface

uses
  clientHttp.wrapper, Generics.Collections, SysUtils, Windows, Classes,
  StrUtils, ClientHttp.Utils, ClientHttp.Constantes,
  ClientHttp.Core, ClientHttp.Request, ClientHttp.Response;

type
  TClientHTTP = class
  private
    FCore : TClientHttpCore;
    FRequest: TClientHttpRequest;
    FResponse: TClientHttpResponse;
    FCertSubject: String;
    FBufferReadSize: Cardinal;

    function EnviarReq(Metodo: TMetodo; const APayload: TStream; const AURL: String): Boolean;
  public
    procedure Execute(AMethod: TMetodo; const AURL: String; const APayload: TStream);
    property CNCertificado: String read FCertSubject write FCertSubject;
    property BufferReadSize: Cardinal read FBufferReadSize write FBufferReadSize;
    property Request: TClientHttpRequest read FRequest write FRequest;
    property Response: TClientHttpResponse read FResponse write FResponse;
    procedure Clear;

    constructor Create;
    destructor Destroy; override;
  end;

implementation

procedure TClientHTTP.Clear;
begin
  FRequest.ClearHeaders;
  FResponse.Clear;
end;

constructor TClientHTTP.Create;
begin
  FCore := TClientHttpCore.Create;
  FRequest := TClientHttpRequest.Create;
  FResponse := TClientHttpResponse.Create;
  FBufferReadSize := 4096;
end;

destructor TClientHTTP.Destroy;
begin
  FCore.Free;
  FRequest.Free;
  FResponse.Free;
  inherited;
end;

function TClientHTTP.EnviarReq(Metodo: TMetodo; const APayload: TStream; const AURL: String): Boolean;
const
  MethodStr: array[TMetodo] of PwChar = ('GET', 'POST', 'PUT', 'PATCH', 'DELETE');
var
  dwFlags : DWORD;
  LCompURL : URL_COMPONENTS;
  LConfig: TClientHttpCoreConfig;
begin
  dwFlags := 0;
  FillChar(LConfig, SizeOf(LConfig), 0);

  LCompURL := TClientHTTPUtils.CrackURL(AURL);

  if LCompURL.nScheme = 2 then // HTTPS
    dwFlags := WINHTTP_FLAG_SECURE;

  LConfig.Request := FRequest;
  LConfig.Host := Copy(LCompUrl.lpszHostName, 1, LCompUrl.dwHostNameLength);
  LConfig.Port := LCompUrl.nPort;
  LConfig.URI := LCompUrl.lpszUrlPath;
  LConfig.Method := MethodStr[Metodo];
  LConfig.BufferSizeRead := FBufferReadSize;
  LConfig.CNCert := FCertSubject;

  if (APayload <> nil) and (APayload.Size > 0) then
  begin
    APayload.Position := 0;
    SetLength(LConfig.Payload, APayload.Size);
    APayload.ReadBuffer(LConfig.Payload[0], APayload.Size);
  end;

  FCore.Open(LConfig, dwFlags);
  FCore.Send('', FResponse);
  Result := True;
end;

procedure TClientHTTP.Execute(AMethod: TMetodo; const AURL: String; const APayload: TStream);
begin
  EnviarReq(AMethod, APayload, AURL);
end;

end.
