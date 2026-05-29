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
      FResponseText : String;
      procedure Reset(const AHost: PChar);
      function GetResponseText: String;
    public
      procedure Open(AHost, AURI, AMethod: PwChar; APort: WORD; AFlags : DWORD);
      procedure Send(AAdditionalHeaders : PwChar);
      procedure AddPayload(const APayload : String);
      procedure AddCertificadoByCN(const ACNCertificado: String);
      procedure SetOptionsReq(dwOption: DWORD; dwFlags : DWORD);
      procedure SetOptionsSession(dwOption: DWORD; dwFlags : DWORD);
      procedure AddHeaders(pwHeader: PwChar; dwFlags: DWORD);
      property Status: Integer read FStatus;
      property Response: TStream read FResponse;
      property ResponseText: String read GetResponseText;
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
  procedure GetStatus;
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

  procedure ReadData;
  var
    BufferLeitura: array[0..4095] of Byte;
    BytesLidos: DWORD;
  begin
    repeat
      BytesLidos := 0;
      if not WinHttpReadData(FRequest, @BufferLeitura[0],
        SizeOf(BufferLeitura), @BytesLidos) then
        begin
          LLastError := GetLastError;
          raise Exception.CreateFmt('Erro: %s Codigo: %d', [TClientHTTPUtils.GetErrorMessage(LLastError), LLastError]);
        end;
      if BytesLidos > 0 then
        FResponse.WriteBuffer(BufferLeitura[0], BytesLidos);
     until BytesLidos = 0;

     FResponse.Position := 0;
  end;
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

  GetStatus;
  ReadData;
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
