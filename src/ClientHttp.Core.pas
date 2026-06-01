unit ClientHttp.Core;

interface

uses
  Windows, SysUtils, Classes,
  clientHttp.wrapper, ClientHttp.Utils, ClientHttp.Constantes, ClientHttp.Cert.Aux;

type
  TClientHttpCore = class
  private
    FSessao: HINTERNET;
    FConnect: HINTERNET;
    FRequest: HINTERNET;
    FHost: string;
    FPayLoadBuffer: TArray<Byte>;
    PBufferCert: Pointer;
    FResponse: TMemoryStream;
    FBufferSizeRead: Cardinal;
    FBufferRead: TArray<Byte>;

    procedure Reset(const AHost: string);
    procedure SetBufferRead(const Value: Cardinal);
    procedure ReadData;
    procedure CheckWinHttpResult(Success: Boolean; const Context: string);
  public
    constructor Create;
    destructor Destroy; override;

    procedure Open(const AHost, AURI, AMethod: string; APort: Word; AFlags: Cardinal = 0);
    procedure Send(const AAdditionalHeaders: string = '');
    procedure AddPayload(const APayload: string); overload;
    procedure AddPayload(APayload: TStream); overload;
    procedure AddCertificadoByCN(const ACNCertificado: string);
    procedure SetOptionsReq(dwOption: Cardinal; dwFlags: Cardinal);
    procedure SetOptionsSession(dwOption: Cardinal; dwFlags: Cardinal);
    procedure AddHeaders(const AHeader: string; dwFlags: Cardinal);

    function GetHeaders: string;
    function GetStatusCode: Integer;
    function GetDataResponse: TStream;

    property BufferSizeRead: Cardinal read FBufferSizeRead write SetBufferRead;
  end;

implementation

{ TClientHttpCore }

constructor TClientHttpCore.Create;
begin
  inherited Create;
  FSessao := nil;
  FConnect := nil;
  FRequest := nil;
  PBufferCert := nil;
  FResponse := TMemoryStream.Create;
  BufferSizeRead := 4096;
end;

destructor TClientHttpCore.Destroy;
begin
  // Ordem correta de fechamento de handles da WinHTTP
  if FRequest <> nil then WinHttpCloseHandle(FRequest);
  if FConnect <> nil then WinHttpCloseHandle(FConnect);
  if FSessao <> nil then WinHttpCloseHandle(FSessao);

  if PBufferCert <> nil then CertFreeCertificateContext(PBufferCert);
  FResponse.Free;
  inherited;
end;

procedure TClientHttpCore.CheckWinHttpResult(Success: Boolean; const Context: string);
var
  LLastError: DWORD;
begin
  if not Success then
  begin
    LLastError := GetLastError;
    raise Exception.CreateFmt('Erro em %s: %s (Código: %d)',
      [Context, TClientHTTPUtils.GetErrorMessage(LLastError), LLastError]);
  end;
end;

procedure TClientHttpCore.Reset(const AHost: string);
begin
  FResponse.Clear;
  FPayLoadBuffer := nil;

  if PBufferCert <> nil then
  begin
    CertFreeCertificateContext(PBufferCert);
    PBufferCert := nil;
  end;

  if FRequest <> nil then
  begin
    WinHttpCloseHandle(FRequest);
    FRequest := nil;
  end;

  if (FHost <> AHost) and (FConnect <> nil) then
  begin
    WinHttpCloseHandle(FConnect);
    FConnect := nil;

    if FSessao <> nil then
    begin
      WinHttpCloseHandle(FSessao);
      FSessao := nil;
    end;
  end;

  FHost := AHost;
end;

procedure TClientHttpCore.Open(const AHost, AURI, AMethod: string; APort: Word; AFlags: Cardinal);
begin
  Reset(AHost);

  if FSessao = nil then
  begin
    FSessao := WinHttpOpen('Sistema 1.0', WINHTTP_ACCESS_TYPE_NO_PROXY,
      WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);
    CheckWinHttpResult(FSessao <> nil, 'WinHttpOpen');
  end;

  if FConnect = nil then
  begin
    FConnect := WinHttpConnect(FSessao, PChar(AHost), APort, 0);
    CheckWinHttpResult(FConnect <> nil, 'WinHttpConnect');
  end;

  if FRequest = nil then
  begin
    FRequest := WinHttpOpenRequest(FConnect, PChar(AMethod), PChar(AURI),
      nil, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, AFlags);
    CheckWinHttpResult(FRequest <> nil, 'WinHttpOpenRequest');
  end;
end;

procedure TClientHttpCore.AddPayload(const APayload: string);
begin
  if APayload.Trim.IsEmpty then Exit;
  FPayLoadBuffer := TEncoding.UTF8.GetBytes(APayload);
end;

procedure TClientHttpCore.AddPayload(APayload: TStream);
begin
  if (APayload = nil) or (APayload.Size = 0) then Exit;

  SetLength(FPayLoadBuffer, APayload.Size);
  APayload.Position := 0;
  APayload.ReadBuffer(FPayLoadBuffer[0], APayload.Size);
end;

procedure TClientHttpCore.AddCertificadoByCN(const ACNCertificado: string);
begin
  if ACNCertificado.Trim.IsEmpty then Exit;

  PBufferCert := FindValidCertContext(ACNCertificado);
  if PBufferCert = nil then
    raise Exception.Create('Certificado não encontrado: ' + ACNCertificado);

  CheckWinHttpResult(
    WinHttpSetOption(FRequest, WINHTTP_OPTION_CLIENT_CERT_CONTEXT, PBufferCert, SizeOf(TCertContext)),
    'WinHttpSetOption (Certificado)'
  );
end;

procedure TClientHttpCore.AddHeaders(const AHeader: string; dwFlags: Cardinal);
begin
  if AHeader.IsEmpty then Exit;
  CheckWinHttpResult(
    WinHttpAddRequestHeaders(FRequest, PChar(AHeader), Length(AHeader), dwFlags),
    'WinHttpAddRequestHeaders'
  );
end;

procedure TClientHttpCore.Send(const AAdditionalHeaders: string);
var
  PBuffer: Pointer;
  LPayLoadBufferSize: Cardinal;
  PHeaders: PChar;
begin
  PBuffer := nil;
  LPayLoadBufferSize := 0;

  if Length(FPayLoadBuffer) > 0 then
  begin
    PBuffer := @FPayLoadBuffer[0];
    LPayLoadBufferSize := Length(FPayLoadBuffer);
  end;

  if AAdditionalHeaders.IsEmpty then
    PHeaders := nil
  else
    PHeaders := PChar(AAdditionalHeaders);

  CheckWinHttpResult(
    WinHttpSendRequest(FRequest, PHeaders, Length(AAdditionalHeaders), PBuffer, LPayLoadBufferSize, LPayLoadBufferSize, 0),
    'WinHttpSendRequest'
  );

  CheckWinHttpResult(WinHttpReceiveResponse(FRequest, nil), 'WinHttpReceiveResponse');

  ReadData;
end;

procedure TClientHttpCore.ReadData;
var
  LBytesDisponiveis: Cardinal;
  LBytesLidos: Cardinal;
  LBufferToRead: Cardinal;
begin
  repeat
    LBytesLidos := 0;
    CheckWinHttpResult(WinHttpQueryDataAvailable(FRequest, @LBytesDisponiveis), 'WinHttpQueryDataAvailable');

    if LBytesDisponiveis = 0 then Break;

    if LBytesDisponiveis < Cardinal(Length(FBufferRead)) then
      LBufferToRead := LBytesDisponiveis
    else
      LBufferToRead := Length(FBufferRead);

    CheckWinHttpResult(
      WinHttpReadData(FRequest, @FBufferRead[0], LBufferToRead, @LBytesLidos),
      'WinHttpReadData'
    );

    if LBytesLidos > 0 then
      FResponse.WriteBuffer(FBufferRead[0], LBytesLidos);

  until LBytesDisponiveis = 0;

  FResponse.Position := 0; // Facilita a leitura posterior externa
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

  // Primeira chamada descobre o tamanho necessário
  if not WinHttpQueryHeaders(FRequest, WINHTTP_QUERY_RAW_HEADERS_CRLF, WINHTTP_HEADER_NAME_BY_INDEX, nil, @LSize, @LIndex) then
  begin
    if GetLastError <> ERROR_INSUFFICIENT_BUFFER then
      CheckWinHttpResult(False, 'WinHttpQueryHeaders (Size)');
  end;

  SetLength(LRawHeaders, LSize div SizeOf(WChar));
  LIndex := WINHTTP_NO_HEADER_INDEX;

  CheckWinHttpResult(
    WinHttpQueryHeaders(FRequest, WINHTTP_QUERY_RAW_HEADERS_CRLF, WINHTTP_HEADER_NAME_BY_INDEX, PChar(LRawHeaders), @LSize, @LIndex),
    'WinHttpQueryHeaders (Data)'
  );

  Result := LRawHeaders;
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

function TClientHttpCore.GetDataResponse: TStream;
begin
  Result := FResponse;
end;

procedure TClientHttpCore.SetBufferRead(const Value: Cardinal);
begin
  if FBufferSizeRead <> Value then
  begin
    FBufferSizeRead := Value;
    SetLength(FBufferRead, FBufferSizeRead);
  end;
end;

procedure TClientHttpCore.SetOptionsReq(dwOption, dwFlags: Cardinal);
begin
  CheckWinHttpResult(
    WinHttpSetOption(FRequest, dwOption, @dwFlags, SizeOf(dwFlags)),
    'WinHttpSetOption (Request)'
  );
end;

procedure TClientHttpCore.SetOptionsSession(dwOption, dwFlags: Cardinal);
begin
  CheckWinHttpResult(
    WinHttpSetOption(FSessao, dwOption, @dwFlags, SizeOf(dwFlags)),
    'WinHttpSetOption (Session)'
  );
end;

end.
