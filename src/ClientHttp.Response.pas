unit ClientHttp.Response;

interface

uses
  Classes, SysUtils;

type
  TClientHttpResponse = class
  private
    FResponseText: String;
    FStatusCode: Integer;
    FResponseStream : TMemoryStream;
    FHeaders : TStringList;
  protected
    procedure ParseHeader(const AValue: String);
    procedure AddStatus(AValue : Integer);
    procedure GetResponse(const AValue: TStream);
  public
    property Headers: TStringList read FHeaders;
    property ResponseText: String read FResponseText;
    property ResponseStream: TMemoryStream read FResponseStream;
    property StatusCode: Integer read FStatusCode;
    procedure Clear;

    constructor Create;
    destructor Destroy;override;
  end;

implementation

{ TClientHttpResponse }

procedure TClientHttpResponse.AddStatus(AValue: Integer);
begin
  FStatusCode := AValue;
end;

procedure TClientHttpResponse.Clear;
begin
  FResponseStream.Clear;
  FHeaders.Clear;
  FResponseText := '';
  FStatusCode := 0;
end;

constructor TClientHttpResponse.Create;
begin
  FResponseStream := TMemoryStream.Create;
  FHeaders := TStringList.Create;
  FHeaders.NameValueSeparator := ':';
  FResponseText := '';
  FStatusCode := 0;
end;

destructor TClientHttpResponse.Destroy;
begin
  FResponseStream.Free;
  FHeaders.Free;
  inherited;
end;

procedure TClientHttpResponse.GetResponse(const AValue: TStream);
var
  LContentType: string;
  LStringStream: TStringStream;
begin
  FResponseStream.Clear;
  FResponseStream.LoadFromStream(AValue);

  FResponseText := '';

  LContentType := FHeaders.Values['Content-Type'].ToLower.Trim;

  if LContentType.Contains('text') or
     LContentType.Contains('json') or
     LContentType.Contains('xml') or
     LContentType.Contains('javascript') then
  begin
    if FResponseStream.Size > 0 then
    begin
      LStringStream := TStringStream.Create('', TEncoding.UTF8);
      try
        FResponseStream.Position := 0;
        LStringStream.CopyFrom(FResponseStream, FResponseStream.Size);
        FResponseText := LStringStream.DataString;
      finally
        LStringStream.Free;
      end;
    end;
  end;
end;

procedure TClientHttpResponse.ParseHeader(const AValue: String);
begin
  FHeaders.Text := AValue;
end;

end.
