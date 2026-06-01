unit ClientHttp;

interface

uses
  clientHttp.wrapper, Generics.Collections, SysUtils, Windows, Classes,
  StrUtils, ClientHttp.Utils, ClientHttp.Constantes,
  ClientHttp.Core, ClientHttp.Cert.Aux, ClientHttp.Request, ClientHttp.Response;

type
  TClientHTTP = class
  private
    FCore : TClientHttpCore;
    FRequest: TClientHttpRequest;
    FResponse: TClientHttpResponse;
    FCertSubject: String;

    function EnviarReq(Metodo: TMetodo; const APayload: String; AURL: String): Boolean;
  public
    function Get(const URL: String): Boolean;
    function Post(const URL, Payload: String): Boolean;
    function Put(const URL, Payload: String): Boolean;
    function Patch(const URL, Payload: String): Boolean;
    function Delete(const URL : String): Boolean;

    property CNCertificado: String read FCertSubject write FCertSubject;
    property Request: TClientHttpRequest read FRequest write FRequest;
    property Response: TClientHttpResponse read FResponse write FResponse;
    procedure Clear;

    constructor Create;
    destructor Destroy; override;
  end;

implementation

type
  TResponseAux = class(TClientHttpResponse);


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
end;

function TClientHTTP.Delete(const URL: String): Boolean;
begin
  Result := EnviarReq(mDelete,'',URL);
end;

destructor TClientHTTP.Destroy;
begin
  FCore.Free;
  FRequest.Free;
  FResponse.Free;
  inherited;
end;

function TClientHTTP.EnviarReq(Metodo: TMetodo; const APayload: String; AURL: String): Boolean;
const
  MethodStr: array[TMetodo] of PwChar = ('GET', 'POST', 'PUT', 'PATCH', 'DELETE');
var
  dwFlags : DWORD;
  lPort : DWORD;
  lURI : PwChar;
  lHost : PwChar;
begin
  dwFlags := 0;

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
    FCore.SetOptionsSession(WINHTTP_OPTION_SECURE_PROTOCOLS, FRequest.GetWinHttpProtocolsMask);
    // Add Timeouts
    FCore.SetOptionsSession(WINHTTP_OPTION_CONNECT_TIMEOUT,FRequest.ConnectTimeOut);
    FCore.SetOptionsSession(WINHTTP_OPTION_SEND_TIMEOUT,FRequest.SendTimeOut);
    FCore.SetOptionsSession(WINHTTP_OPTION_RECEIVE_TIMEOUT,FRequest.ReceiveTimeOut);

    // Headers
    FCore.AddHeaders(PwChar(FRequest.GetFormattedHeaders), 0);

    // Envio
    FCore.Send('');
    Result := True;
  except
    on E: Exception do
      raise Exception.Create(E.Message);
  end;

  TResponseAux(FResponse).ParseHeader(FCore.GetHeaders);
  TResponseAux(FResponse).AddStatus(FCore.GetStatusCode);
  TResponseAux(FResponse).GetResponse(FCore.GetDataResponse);
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

end.
