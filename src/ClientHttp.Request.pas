unit ClientHttp.Request;

interface

uses
  ClientHttp.Constantes, Generics.Collections, SysUtils;

type
  TClientHttpRequest = class
  private
    FHeaders: TDictionary<string, string>;
    FReceiveTimeOut: Cardinal;
    FConnectTimeOut: Cardinal;
    FSendTimeOut: Cardinal;
    FProtocols: TProtocols;

    function GetReceiveTimeOut: Cardinal; inline;
    procedure SetReceiveTimeOut(const Value: Cardinal); inline;
    function GetConnectTimeOut: Cardinal; inline;
    procedure SetConnectTimeOut(const Value: Cardinal); inline;
    function GetSendTimeOut: Cardinal; inline;
    procedure SetSendTimeOut(const Value: Cardinal); inline;
    procedure SetProtocols(const Value: TProtocols); inline;
    function GetProtocols: TProtocols; inline;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddHeader(const AKey, AValue: string);
    procedure ClearHeaders;
    function GetFormattedHeaders: string;
    function GetWinHttpProtocolsMask: Cardinal;

    property ReceiveTimeOut: Cardinal read GetReceiveTimeOut write SetReceiveTimeOut;
    property ConnectTimeOut: Cardinal read GetConnectTimeOut write SetConnectTimeOut;
    property SendTimeOut: Cardinal read GetSendTimeOut write SetSendTimeOut;
    property Protocols: TProtocols read GetProtocols write SetProtocols;
  end;

implementation

{ TClientHttpRequest }

constructor TClientHttpRequest.Create;
begin
  inherited Create;
  FHeaders := TDictionary<string, string>.Create;
  FReceiveTimeOut := 30000;
  FConnectTimeOut := 30000;
  FSendTimeOut := 30000;
  FProtocols := [pTLS1_1, pTLS1_2];
end;

destructor TClientHttpRequest.Destroy;
begin
  FHeaders.Free;
  inherited;
end;

procedure TClientHttpRequest.AddHeader(const AKey, AValue: string);
begin
  if AKey.Trim.IsEmpty then Exit;
  FHeaders.AddOrSetValue(AKey.Trim, AValue.Trim);
end;

procedure TClientHttpRequest.ClearHeaders;
begin
  FHeaders.Clear;
end;

function TClientHttpRequest.GetFormattedHeaders: string;
var
  LPair: TPair<string, string>;
  LBuilder: TStringBuilder;
begin
  if FHeaders.Count = 0 then
    Exit('');

  LBuilder := TStringBuilder.Create;
  try
    for LPair in FHeaders do
    begin
      LBuilder.Append(LPair.Key)
              .Append(': ')
              .Append(LPair.Value)
              .Append(#13#10);
    end;
    Result := LBuilder.ToString;
  finally
    LBuilder.Free;
  end;
end;

function TClientHttpRequest.GetWinHttpProtocolsMask: Cardinal;
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

function TClientHttpRequest.GetConnectTimeOut: Cardinal;
begin
  Result := FConnectTimeOut;
end;

function TClientHttpRequest.GetProtocols: TProtocols;
begin
  Result := FProtocols;
end;

function TClientHttpRequest.GetReceiveTimeOut: Cardinal;
begin
  Result := FReceiveTimeOut;
end;

function TClientHttpRequest.GetSendTimeOut: Cardinal;
begin
  Result := FSendTimeOut;
end;

procedure TClientHttpRequest.SetConnectTimeOut(const Value: Cardinal);
begin
  FConnectTimeOut := Value;
end;

procedure TClientHttpRequest.SetProtocols(const Value: TProtocols);
begin
  FProtocols := Value;
end;

procedure TClientHttpRequest.SetReceiveTimeOut(const Value: Cardinal);
begin
  FReceiveTimeOut := Value;
end;

procedure TClientHttpRequest.SetSendTimeOut(const Value: Cardinal);
begin
  FSendTimeOut := Value;
end;

end.
