unit ClientHttp.Utils;

interface

uses
  StrUtils, SysUtils, Windows;

type
  TClientHTTPUtils = class
    class function GetHost(const AURL: String): String;
    class function GetURI(const AURL: String): String;
    class function GetPort(const AURL: String): WORD;
    class function GetErrorMessage(ErrorCode: DWORD): string;
    class function IsHttps(const AURL: String): Boolean; inline;
  end;

implementation

{ TClientHTTPUtils }

class function TClientHTTPUtils.IsHttps(const AURL: String): Boolean;
begin
  Result := AURL.ToLower.StartsWith('https://');
end;

class function TClientHTTPUtils.GetErrorMessage(ErrorCode: DWORD): string;
begin
  case ErrorCode of
    12001: Result := 'Sem identificadores disponíveis (Obsoleto)';
    12002: Result := 'Tempo limite da solicitação atingido';
    12004: Result := 'Erro interno';
    12005: Result := 'URL inválida';
    12006: Result := 'Esquema não reconhecido (use http:// ou https://)';
    12007: Result := 'Nome do servidor não pôde ser resolvido';
    12009: Result := 'Valor de opção inválido';
    12011: Result := 'Opção não pode ser definida, apenas consultada';
    12012: Result := 'Suporte WinHTTP sendo desligado';
    12015: Result := 'Falha na tentativa de logon. Feche e recrie o handle.';
    12017: Result := 'Operação cancelada';
    12018: Result := 'Tipo de handle incorreto para esta operação';
    12019: Result := 'Handle não está no estado correto';
    12029: Result := 'Falha na conexão com o servidor';
    12030: Result := 'Erro de conexão (conexão redefinida ou protocolo SSL incompatível)';
    12032: Result := 'Falha na função. Repita a operação no mesmo handle.';
    12037: Result := 'Certificado SSL fora do período de validade';
    12038: Result := 'Nome CN do certificado SSL não corresponde';
    12044: Result := 'Servidor requer autenticação de cliente SSL';
    12045: Result := 'Cadeia de certificados terminou em raiz não confiável';
    12057: Result := 'Falha na verificação de revogação (servidor offline)';
    12100: Result := 'Operação não pode ser executada antes de chamar Open';
    12101: Result := 'Operação não pode ser executada antes de chamar Send';
    12102: Result := 'Operação não pode ser executada depois de chamar Send';
    12103: Result := 'Opção não pode ser solicitada depois de chamar Open';
    12150: Result := 'Cabeçalho solicitado não encontrado';
    12152: Result := 'Resposta do servidor não pôde ser analisada';
    12154: Result := 'Solicitação de consulta inválida (Obsoleto)';
    12155: Result := 'Cabeçalho já existe (Obsoleto)';
    12156: Result := 'Falha no redirecionamento';
    12157: Result := 'Erro no canal seguro SSL';
    12166: Result := 'Erro ao executar script PAC do proxy';
    12167: Result := 'Arquivo PAC do proxy não pôde ser baixado';
    12169: Result := 'Certificado SSL inválido';
    12170: Result := 'Certificado SSL revogado';
    12172: Result := 'WinHTTP não inicializado (Obsoleto)';
    12175: Result := 'Falha SSL (um ou mais erros no certificado)';
    12176: Result := 'Tipo de script não suportado';
    12177: Result := 'Erro durante execução de script';
    12178: Result := 'Proxy não encontrado para a URL especificada';
    12179: Result := 'Certificado não é válido para o uso solicitado';
    12180: Result := 'Falha na autodetecção da URL do arquivo PAC';
    12181: Result := 'Número excessivo de cabeçalhos na resposta';
    12182: Result := 'Tamanho dos cabeçalhos excede o limite';
    12183: Result := 'Estouro na análise da codificação em partes';
    12184: Result := 'Resposta excede limite interno de tamanho';
    8: Result := 'Memória insuficiente para completar a operação';
    122: Result := 'Buffer insuficiente para conter os dados retornados';
    6: Result := 'Handle inválido ou fechado';
    18: Result := 'Não há mais arquivos';
    259: Result := 'Não há mais itens';
  else
    Result := 'Erro WinHTTP desconhecido: ' + IntToStr(ErrorCode);
  end;
end;

class function TClientHTTPUtils.GetHost(const AURL: String): String;
var
  PortPos: Integer;
begin
  Result := AURL;

  if Pos('https://', Result) = 1 then
    Delete(Result, 1, 8)
  else if Pos('http://', Result) = 1 then
    Delete(Result, 1, 7);

  PortPos := Pos(':', Result);
  if PortPos > 0 then
    Result := Copy(Result, 1, PortPos - 1);

  PortPos := Pos('/', Result);
  if PortPos > 0 then
    Result := Copy(Result, 1, PortPos - 1);
end;

class function TClientHTTPUtils.GetPort(const AURL: String): WORD;
var
  Temp: String;
  PortPos, SlashPos: Integer;
begin
  Result := 80;
  Temp := AURL;

  if Pos('https://', Temp) = 1 then
  begin
    Delete(Temp, 1, 8);
    Result := 443;
  end
  else if Pos('http://', Temp) = 1 then
    Delete(Temp, 1, 7);

  PortPos := Pos(':', Temp);
  if PortPos > 0 then
  begin
    SlashPos := Pos('/', Temp);
    if SlashPos = 0 then
      SlashPos := Length(Temp) + 1;

    if PortPos < SlashPos then
      Result := StrToIntDef(Copy(Temp, PortPos + 1, SlashPos - PortPos - 1), Result);
  end;
end;

class function TClientHTTPUtils.GetURI(const AURL: String): String;
var
  StartPos: Integer;
  SlashPos: Integer;
begin
  Result := AURL;

  StartPos := Pos('://', Result);
  if StartPos > 0 then
  begin
    SlashPos := PosEx('/', Result, StartPos + 3);
    if SlashPos > 0 then
      Result := Copy(Result, SlashPos, Length(Result) - SlashPos + 1)
    else
      Result := '/';
  end
  else
  begin
    SlashPos := Pos('/', Result);
    if SlashPos > 0 then
      Result := Copy(Result, SlashPos, Length(Result) - SlashPos + 1)
    else
      Result := '/';
  end;
end;

end.
