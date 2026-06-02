unit ClientHttp.Core;

interface

uses
  Windows, SysUtils, Classes,
  clientHttp.wrapper, ClientHttp.Utils, ClientHttp.Constantes, ClientHttp.Cert.Aux,
  ClientHttp.Request, ClientHttp.Response;

type
  TClientHttpCoreConfig = record
    Request: TClientHttpRequest;
    Payload: TArray<Byte>;
    BufferSizeRead: Cardinal;
    CNCert: String;
    Host: String;
    Port: Cardinal;
    URI: String;
    Method: String;
  end;

  TClientHttpCore = class
  private
    FSessao: HINTERNET;
    FConnect: HINTERNET;
    FRequest: HINTERNET;
    FCertContext: Pointer;
    FConfig: TClientHttpCoreConfig;

    procedure Reset(const AHost: string);
    procedure ReadData(const ABuffer : TStream);
    procedure AddHeaders(const AHeader: string; dwFlags: Cardinal);
    function GetHeaders: string;
    function GetStatusCode: Integer;
    procedure AddCertificadoByCN(const ACNCertificado: string);
    procedure SetOptions(APointer: HINTERNET; dwOption: Cardinal; dwFlags: Cardinal);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Open(const AConfig : TClientHttpCoreConfig; AFlags: Cardinal = 0);
    procedure Send(const AAdditionalHeaders: string; var AResponse : TClientHttpResponse);
  end;

implementation

type
  TResponseAux = class(TClientHttpResponse);

{ TClientHttpCore }

constructor TClientHttpCore.Create;
begin
  inherited Create;
  FSessao := nil;
  FConnect := nil;
  FRequest := nil;
  FCertContext := nil;
end;

destructor TClientHttpCore.Destroy;
begin
  if FRequest <> nil then WinHttpCloseHandle(FRequest);
  if FConnect <> nil then WinHttpCloseHandle(FConnect);
  if FSessao <> nil then WinHttpCloseHandle(FSessao);

  if FCertContext <> nil then CertFreeCertificateContext(FCertContext);
  inherited;
end;

procedure TClientHttpCore.Reset(const AHost: string);
begin
  if FCertContext <> nil then
  begin
    CertFreeCertificateContext(FCertContext);
    FCertContext := nil;
  end;

  if FRequest <> nil then
  begin
    WinHttpCloseHandle(FRequest);
    FRequest := nil;
  end;

  if (FConfig.Host <> AHost) and (FConnect <> nil) then
  begin
    WinHttpCloseHandle(FConnect);
    FConnect := nil;

    if FSessao <> nil then
    begin
      WinHttpCloseHandle(FSessao);
      FSessao := nil;
    end;
  end;

  FConfig.Host := AHost;
end;

procedure TClientHttpCore.Open(const AConfig : TClientHttpCoreConfig; AFlags: Cardinal = 0);
begin
  FConfig := AConfig;
  Reset(FConfig.Host);

  if FSessao = nil then
  begin
    FSessao := WinHttpOpen('Sistema 1.0', WINHTTP_ACCESS_TYPE_NO_PROXY,
      WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    TClientHTTPUtils.CheckWinHttpResult(FSessao <> nil, 'WinHttpOpen');
  end;

  if FConnect = nil then
  begin
    FConnect := WinHttpConnect(FSessao, PChar(FConfig.Host), FConfig.Port, 0);
    TClientHTTPUtils.CheckWinHttpResult(FConnect <> nil, 'WinHttpConnect');
  end;

  if FRequest = nil then
  begin
    FRequest := WinHttpOpenRequest(FConnect, PChar(FConfig.Method), PChar(FConfig.URI),
      nil, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, AFlags);
    TClientHTTPUtils.CheckWinHttpResult(FRequest <> nil, 'WinHttpOpenRequest');
  end;

  // Protocols
  SetOptions(FSessao, WINHTTP_OPTION_SECURE_PROTOCOLS, FConfig.Request.GetWinHttpProtocolsMask);

  // Timeouts
  SetOptions(FSessao, WINHTTP_OPTION_CONNECT_TIMEOUT, FConfig.Request.ConnectTimeOut);
  SetOptions(FSessao, WINHTTP_OPTION_SEND_TIMEOUT, FConfig.Request.SendTimeOut);
  SetOptions(FSessao, WINHTTP_OPTION_RECEIVE_TIMEOUT, FConfig.Request.ReceiveTimeOut);

  // Headers
  AddHeaders(FConfig.Request.GetFormattedHeaders, 0);

  // Certificado
  AddCertificadoByCN(FConfig.CNCert);
end;

procedure TClientHttpCore.AddCertificadoByCN(const ACNCertificado: string);
begin
  if ACNCertificado.Trim.IsEmpty then Exit;

  FCertContext := FindValidCertContext(ACNCertificado);
  if FCertContext = nil then
    raise Exception.Create('Certificado não encontrado: ' + ACNCertificado);

  TClientHTTPUtils.CheckWinHttpResult(
    WinHttpSetOption(FRequest, WINHTTP_OPTION_CLIENT_CERT_CONTEXT, FCertContext, SizeOf(TCertContext)),
    'WinHttpSetOption (Certificado)'
  );
end;

procedure TClientHttpCore.AddHeaders(const AHeader: string; dwFlags: Cardinal);
begin
  if AHeader.IsEmpty then Exit;
  TClientHTTPUtils.CheckWinHttpResult(
    WinHttpAddRequestHeaders(FRequest, PChar(AHeader), Length(AHeader), dwFlags),
    'WinHttpAddRequestHeaders'
  );
end;

procedure TClientHttpCore.Send(const AAdditionalHeaders: string; var AResponse : TClientHttpResponse);
var
  PBuffer: Pointer;
  LPayLoadBufferSize: Cardinal;
  PHeaders: PChar;
begin
  PBuffer := nil;
  LPayLoadBufferSize := 0;

  if Length(FConfig.Payload) > 0 then
  begin
    PBuffer := @FConfig.Payload[0];
    LPayLoadBufferSize := Length(FConfig.Payload);
  end;

  if AAdditionalHeaders.IsEmpty then
    PHeaders := nil
  else
    PHeaders := PChar(AAdditionalHeaders);

  TClientHTTPUtils.CheckWinHttpResult(
    WinHttpSendRequest(FRequest, PHeaders, Length(AAdditionalHeaders), PBuffer, LPayLoadBufferSize, LPayLoadBufferSize, 0),
    'WinHttpSendRequest'
  );

  TClientHTTPUtils.CheckWinHttpResult(WinHttpReceiveResponse(FRequest, nil), 'WinHttpReceiveResponse');
  ReadData(TResponseAux(AResponse).GetStream);
  TResponseAux(AResponse).ParseHeader(GetHeaders);
  TResponseAux(AResponse).AddStatus(GetStatusCode);
end;

procedure TClientHttpCore.ReadData(const ABuffer : TStream);
var
  LBytesDisponiveis: Cardinal;
  LBytesLidos: Cardinal;
  LBufferToRead: Cardinal;
  LBufferRead: TArray<Byte>;
begin
  SetLength(LBufferRead, FConfig.BufferSizeRead);
  repeat
    LBytesLidos := 0;
    TClientHTTPUtils.CheckWinHttpResult(WinHttpQueryDataAvailable(FRequest, @LBytesDisponiveis), 'WinHttpQueryDataAvailable');

    if LBytesDisponiveis = 0 then Break;

    if LBytesDisponiveis < Cardinal(Length(LBufferRead)) then
      LBufferToRead := LBytesDisponiveis
    else
      LBufferToRead := Length(LBufferRead);

    TClientHTTPUtils.CheckWinHttpResult(
      WinHttpReadData(FRequest, @LBufferRead[0], LBufferToRead, @LBytesLidos),
      'WinHttpReadData'
    );

    if LBytesLidos > 0 then
      ABuffer.WriteBuffer(LBufferRead[0], LBytesLidos);

  until LBytesDisponiveis = 0;

  ABuffer.Position := 0;
end;

function TClientHttpCore.GetHeaders: string;
var
  LSize: Cardinal;
  LIndex: Pointer;
  LRawHeaders: string;
begin
  Result := '';
  LSize := 0;
  LIndex := WINHTTP_NO_HEADER_INDEX;

  if not WinHttpQueryHeaders(FRequest, WINHTTP_QUERY_RAW_HEADERS_CRLF, WINHTTP_HEADER_NAME_BY_INDEX, nil, @LSize, @LIndex) then
  begin
    if GetLastError <> ERROR_INSUFFICIENT_BUFFER then
      TClientHTTPUtils.CheckWinHttpResult(False, 'WinHttpQueryHeaders (Size)');
  end;

  SetLength(LRawHeaders, LSize div SizeOf(WChar));
  LIndex := WINHTTP_NO_HEADER_INDEX;

  TClientHTTPUtils.CheckWinHttpResult(
    WinHttpQueryHeaders(FRequest, WINHTTP_QUERY_RAW_HEADERS_CRLF, WINHTTP_HEADER_NAME_BY_INDEX, PChar(LRawHeaders), @LSize, @LIndex),
    'WinHttpQueryHeaders (Data)'
  );

  Result := PChar(LRawHeaders);
end;

function TClientHttpCore.GetStatusCode: Integer;
var
  LStatusCode: Cardinal;
  LSize: Cardinal;
begin
  Result := 0;
  LStatusCode := 0;
  LSize := SizeOf(LStatusCode);

  if WinHttpQueryHeaders(FRequest, WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER,
    WINHTTP_HEADER_NAME_BY_INDEX, @LStatusCode, @LSize, WINHTTP_NO_HEADER_INDEX) then
  begin
    Result := LStatusCode;
  end;
end;

procedure TClientHttpCore.SetOptions(APointer: HINTERNET; dwOption, dwFlags: Cardinal);
begin
  TClientHTTPUtils.CheckWinHttpResult(
    WinHttpSetOption(APointer, dwOption, @dwFlags, SizeOf(dwFlags)),
    'WinHttpSetOption (Request)'
  );
end;

end.
