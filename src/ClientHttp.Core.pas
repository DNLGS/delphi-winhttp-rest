unit ClientHttp.Core;

interface

uses clientHttp.wrapper, Windows, ClientHttp.Utils, SysUtils,
  ClientHttp.Constantes, ClientHttp.Cert.Aux, Classes;

type
  TClientHttpCore = class
    private
      FHost : String;
      FSessao: HINTERNET;
      FConnect: HINTERNET;
      FRequest: HINTERNET;
      PBuffer: Pointer;
      FBufferSize: DWORD;
      FBuffer: TArray<Byte>;
      PBufferCert : Pointer;
      FStatus : Integer;
      FResponse : TStream;
      FBufferSizeRead : DWORD;
      FBufferRead : array of Byte;
      FHeaders : TStringList;
      procedure Reset(const AHost: PChar);
      function GetResponseText: String;
      procedure SetBufferRead(const Value: DWORD);
      procedure GetHeaders;
      procedure GetStatusCode;
      procedure ReadData;
    public
      procedure Open(AHost, AURI, AMethod: PwChar; APort: WORD; AFlags : DWORD);
      procedure Send(AAdditionalHeaders : PwChar);
      procedure AddPayload(const APayload : String);
      procedure AddCertificadoByCN(const ACNCertificado: String);
      procedure SetOptionsReq(dwOption: DWORD; dwFlags : DWORD);
      procedure SetOptionsSession(dwOption: DWORD; dwFlags : DWORD);
      procedure AddHeaders(pwHeader: PwChar; dwFlags: DWORD);
      property Headers: TStringList read FHeaders;
      property Status: Integer read FStatus;
      property Response: TStream read FResponse;
      property ResponseText: String read GetResponseText;
      property BufferSizeRead: DWORD read FBufferSizeRead write SetBufferRead;
      constructor Create;

      destructor Destroy;override;
  end;

implementation

{ TClientHttpCore }

procedure TClientHttpCore.AddCertificadoByCN(const ACNCertificado: String);
var
  LLastError : DWORD;
begin
  if ACNCertificado.Trim = '' then
    Exit;

  PBufferCert := FindValidCertContext(ACNCertificado);
  if PBufferCert = nil then
    raise Exception.Create('Certificado não encontrado: ' + ACNCertificado);

  if not WinHttpSetOption(FRequest, WINHTTP_OPTION_CLIENT_CERT_CONTEXT,
    pBufferCert, SizeOf(TCertContext)) then
  begin
    LLastError := GetLastError;
    raise Exception.CreateFmt('Erro: %s Codigo: %d', [TClientHTTPUtils.GetErrorMessage(LLastError), LLastError]);
  end;
end;

procedure TClientHttpCore.AddHeaders(pwHeader: PwChar; dwFlags: DWORD);
begin
  WinHttpAddRequestHeaders(FRequest, pwHeader, DWORD(-1), dwFlags);
end;

procedure TClientHttpCore.AddPayload(const APayload: String);
begin
  if APayload.Trim = '' then
    Exit;

  FBuffer := TEncoding.UTF8.GetBytes(APayload);
  FBufferSize := Length(FBuffer);
end;

constructor TClientHttpCore.Create;
begin
  FSessao := nil;
  FConnect := nil;
  FRequest := nil;
  FBufferSize := 0;
  PBuffer := nil;
  PBufferCert := nil;
  FResponse := TMemoryStream.Create;
  FBufferSizeRead := 4096;
  SetLength(FBufferRead, FBufferSizeRead);
  FHeaders := TStringList.Create;
  FHeaders.NameValueSeparator := ':';
end;

destructor TClientHttpCore.Destroy;
begin
  if FRequest <> nil then WinHttpCloseHandle(FRequest);
  if FConnect <> nil then WinHttpCloseHandle(FConnect);
  if FSessao <> nil then WinHttpCloseHandle(FSessao);
  if PBufferCert <> nil then CertFreeCertificateContext(PBufferCert);
  FResponse.Free;
  inherited;
end;

procedure TClientHttpCore.GetHeaders;
var
  LSize     : DWORD;
  LLastError: DWORD;
  LIndex    : DWORD;
  LRawHeaders : String;
begin
  LSize  := 0;
  LIndex := 0;

  WinHttpQueryHeaders(FRequest,
    WINHTTP_QUERY_RAW_HEADERS_CRLF,
    WINHTTP_HEADER_NAME_BY_INDEX,
    nil,
    @LSize,
    @LIndex);

  LLastError := GetLastError;
  if LLastError <> ERROR_INSUFFICIENT_BUFFER then
    raise Exception.CreateFmt('Erro: %s Codigo: %d',
      [TClientHTTPUtils.GetErrorMessage(LLastError), LLastError]);

  SetLength(LRawHeaders, LSize div SizeOf(WChar));

  LIndex := 0;
  if not WinHttpQueryHeaders(FRequest,
    WINHTTP_QUERY_RAW_HEADERS_CRLF,
    WINHTTP_HEADER_NAME_BY_INDEX,
    PWChar(LRawHeaders),
    @LSize,
    @LIndex) then
  begin
    LLastError := GetLastError;
    raise Exception.CreateFmt('Erro: %s Codigo: %d',
      [TClientHTTPUtils.GetErrorMessage(LLastError), LLastError]);
  end;

  FHeaders.Text := LRawHeaders;
end;

function TClientHttpCore.GetResponseText: String;
var
  Bytes: TBytes;
  Encoding: TEncoding;
begin
  if FResponse.Size = 0 then
    Exit('');

  FResponse.Position := 0;

  SetLength(Bytes, FResponse.Size);
  FResponse.ReadBuffer(Bytes[0], FResponse.Size);

  Encoding := TEncoding.UTF8;
  Result := Encoding.GetString(Bytes);
end;

procedure TClientHttpCore.GetStatusCode;
var
lstatuscode : DWORD;
lsize : DWORD;
begin
  lstatuscode := 0;
  lsize := SizeOf(lstatuscode);
  if not WinHttpQueryHeaders(FRequest,
    WINHTTP_QUERY_STATUS_CODE or WINHTTP_QUERY_FLAG_NUMBER,
    WINHTTP_HEADER_NAME_BY_INDEX,
    @lstatuscode, @lsize, WINHTTP_NO_HEADER_INDEX) then
    FStatus := 0
  else
    FStatus := lstatuscode;
end;

procedure TClientHttpCore.Open(AHost, AURI, AMethod: PwChar; APort: WORD; AFlags : DWORD);
var
  LLastError : DWORD;
begin
  Reset(AHost);
  if FSessao = nil then
  begin
    FSessao := WinHttpOpen('Sistema 1.0', WINHTTP_ACCESS_TYPE_NO_PROXY,
        WINHTTP_NO_PROXY_NAME, WINHTTP_NO_PROXY_BYPASS, 0);

    if FSessao = nil then
    begin
      LLastError := GetLastError;
      raise Exception.CreateFmt('Erro: %s Codigo: %d', [TClientHTTPUtils.GetErrorMessage(LLastError), LLastError]);
    end;
  end;

  if FConnect = nil then
  begin
    FConnect := WinHttpConnect(FSessao, AHost, APort, 0);
    if FConnect = nil then
    begin
      LLastError := GetLastError;
      raise Exception.CreateFmt('Erro: %s Codigo: %d', [TClientHTTPUtils.GetErrorMessage(LLastError), LLastError]);
    end;
  end;

  if FRequest = nil then
  begin
    FRequest := WinHttpOpenRequest(FConnect, AMethod,
      AURI, nil, WINHTTP_NO_REFERER,
      WINHTTP_DEFAULT_ACCEPT_TYPES, AFlags);

    if FRequest = nil then
    begin
      LLastError := GetLastError;
      raise Exception.CreateFmt('Erro: %s Codigo: %d', [TClientHTTPUtils.GetErrorMessage(LLastError), LLastError]);
    end;
  end;
end;

procedure TClientHttpCore.ReadData;
var
  LBytesDisponiveis: DWORD;
  LBytesLidos      : DWORD;
  LBufferToRead    : DWORD;
  LLastError       : DWORD;
begin
  repeat
    LBytesLidos := 0;

    if not WinHttpQueryDataAvailable(FRequest, @LBytesDisponiveis) then
    begin
      LLastError := GetLastError;
      raise Exception.CreateFmt('Erro Query: %s Codigo: %d',
        [TClientHTTPUtils.GetErrorMessage(LLastError), LLastError]);
    end;

    if LBytesDisponiveis = 0 then
      Break;

    if LBytesDisponiveis < DWORD(Length(FBufferRead)) then
      LBufferToRead := LBytesDisponiveis
    else
      LBufferToRead := Length(FBufferRead);

    if not WinHttpReadData(FRequest, @FBufferRead[0], LBufferToRead, @LBytesLidos) then
    begin
      LLastError := GetLastError;
      raise Exception.CreateFmt('Erro Read: %s Codigo: %d',
        [TClientHTTPUtils.GetErrorMessage(LLastError), LLastError]);
    end;

    if LBytesLidos > 0 then
      FResponse.WriteBuffer(FBufferRead[0], LBytesLidos);

  until LBytesDisponiveis = 0;  // condição mais confiável
end;

procedure TClientHttpCore.Reset(const AHost: PChar);
begin
  FBuffer := nil;
  FBufferSize := 0;
  PBuffer := nil;
  FResponse.Size := 0;
  FStatus := 0;

  if PBufferCert <> nil then
  begin
    CertFreeCertificateContext(PBufferCert);
    PBufferCert := nil;
  end;

  if FHost <> string(AHost) then
  begin
    WinHttpCloseHandle(FSessao);
    FSessao := nil;
  end;
  FHost := string(AHost);

  if FRequest <> nil then
  begin
    WinHttpCloseHandle(FRequest);
    FRequest := nil;
  end;

  if FConnect <> nil then
  begin
    WinHttpCloseHandle(FConnect);
    FConnect := nil;
  end;
end;

procedure TClientHttpCore.Send(AAdditionalHeaders : PwChar);
var
  LLastError : DWORD;
begin
  if FBufferSize > 0 then
    PBuffer := @FBuffer[0];

  if not WinHttpSendRequest(FRequest, AAdditionalHeaders , 0,
    pBuffer, FBufferSize, FBufferSize, 0) then
  begin
    LLastError := GetLastError;
    raise Exception.CreateFmt('Erro: %s Codigo: %d', [TClientHTTPUtils.GetErrorMessage(LLastError), LLastError]);
  end;

  if not WinHttpReceiveResponse(FRequest, nil) then
  begin
    LLastError := GetLastError;
    raise Exception.CreateFmt('Erro: %s Codigo: %d', [TClientHTTPUtils.GetErrorMessage(LLastError), LLastError]);
  end;

  GetStatusCode;
  GetHeaders;
  ReadData;
end;

procedure TClientHttpCore.SetBufferRead(const Value: DWORD);
begin
  FBufferSizeRead := Value;
  SetLength(FBufferRead, FBufferSizeRead);
end;

procedure TClientHttpCore.SetOptionsReq(dwOption,
  dwFlags: DWORD);
begin
  WinHttpSetOption(FRequest,dwOption,@dwFlags,sizeOf(dwFlags));
end;

procedure TClientHttpCore.SetOptionsSession(dwOption, dwFlags: DWORD);
begin
  WinHttpSetOption(FSessao,dwOption,@dwFlags,sizeOf(dwFlags));
end;

end.
