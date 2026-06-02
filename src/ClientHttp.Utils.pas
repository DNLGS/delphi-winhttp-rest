unit ClientHttp.Utils;

interface

uses
  StrUtils, SysUtils, Windows, ClientHttp.wrapper, ClientHttp.Constantes;

type
  TClientHTTPUtils = class
    class function GetErrorMessage(ErrorCode: DWORD): string;
    class function CrackURL(const AURL: String): URL_COMPONENTS;
    class procedure CheckWinHttpResult(Success: Boolean; const Context: string);
  end;

implementation

{ TClientHTTPUtils }


class procedure TClientHTTPUtils.CheckWinHttpResult(Success: Boolean;
  const Context: string);
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

class function TClientHTTPUtils.CrackURL(const AURL: String): URL_COMPONENTS;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.dwStructSize := SizeOf(Result);
  Result.dwHostNameLength   := 1;
  Result.dwUserNameLength   := 1;
  Result.dwPasswordLength   := 1;
  Result.dwUrlPathLength    := 1;
  Result.dwExtraInfoLength  := 1;
  Result.dwSchemeLength     := 1;

  if not WinHttpCrackUrl(PWideChar(AURL), Length(AURL), ICU_REJECT_USERPWD, @Result) then
    CheckWinHttpResult(False, 'WinHttpCrackUrl');
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

end.
