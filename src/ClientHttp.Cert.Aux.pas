unit ClientHttp.Cert.Aux;

interface

uses
  Windows, SysUtils, ActiveX, DateUtils;

type
  PCertContext = ^TCertContext;
  TCertContext = record
    dwCertEncodingType : DWORD;
    pbCertEncoded      : PByte;
    cbCertEncoded      : DWORD;
    pCertInfo          : Pointer;
    hCertStore         : THandle;
  end;

  PCertInfo = ^TCertInfo;
  TCertInfo = record
    dwVersion          : DWORD;
    SerialNumber       : record cbData: DWORD; pbData: PByte; end;
    SignatureAlgorithm : record
                           pszObjId   : PAnsiChar;
                           Parameters : record cbData: DWORD; pbData: PByte; end;
                         end;
    Issuer             : record cbData: DWORD; pbData: PByte; end;
    NotBefore          : FILETIME;
    NotAfter           : FILETIME;
    Subject            : record cbData: DWORD; pbData: PByte; end;
    SubjectPublicKeyInfo: record
                           Algorithm  : record
                                          pszObjId  : PAnsiChar;
                                          Parameters: record cbData: DWORD; pbData: PByte; end;
                                        end;
                           PublicKey  : record cbData: DWORD; pbData: PByte; cUnusedBits: DWORD; end;
                         end;
    IssuerUniqueId     : record cbData: DWORD; pbData: PByte; cUnusedBits: DWORD; end;
    SubjectUniqueId    : record cbData: DWORD; pbData: PByte; cUnusedBits: DWORD; end;
    cExtension         : DWORD;
    rgExtension        : Pointer;
  end;

// --- imports crypt32.dll ---

function CertOpenStore(lpszStoreProvider: LPCSTR; dwEncodingType: DWORD;
  hCryptProv: THandle; dwFlags: DWORD; pvPara: Pointer): THandle; stdcall;
  external 'crypt32.dll';

function CertFindCertificateInStore(hCertStore: THandle; dwCertEncodingType: DWORD;
  dwFindFlags: DWORD; dwFindType: DWORD; pvFindPara: Pointer;
  pPrevCertContext: PCertContext): PCertContext; stdcall;
  external 'crypt32.dll';

function CertDuplicateCertificateContext(pCertContext: PCertContext): PCertContext; stdcall;
  external 'crypt32.dll';

function CertGetCertificateContextProperty(pCertContext: PCertContext;
  dwPropId: DWORD; pvData: Pointer; var pcbData: DWORD): BOOL; stdcall;
  external 'crypt32.dll';

function CertFreeCertificateContext(pCertContext: PCertContext): BOOL; stdcall;
  external 'crypt32.dll';

function CertCloseStore(hCertStore: THandle; dwFlags: DWORD): BOOL; stdcall;
  external 'crypt32.dll';

// --- import kernel32.dll ---

function FileTimeToSystemTime(const lpFileTime: TFileTime;
  var lpSystemTime: TSystemTime): BOOL; stdcall;
  external 'kernel32.dll';

// --- API pública ---

// Retorna o caminho (thumbprint) do primeiro certificado válido com o CN
// informado. Retorna string vazia se não encontrar nenhum.
// AStore: nome da store Windows ('MY', 'ROOT', 'CA', etc.)
function FindValidCertPath(const ACN: string; AStore: string = 'MY'): string;
function FindValidCertContext(const ACN:String; AStore: string = 'MY'): PCertContext;

implementation

// ---------------------------------------------------------------------------
// Retorna o PCertContext do primeiro certificado não-expirado com o CN dado.
// O caller é responsável por chamar CertFreeCertificateContext no resultado.
// ---------------------------------------------------------------------------
function FindValidCertContext(const ACN: String; AStore: string): PCertContext;
const
  CERT_STORE_PROV_SYSTEM_W  = LPCSTR(10);
  CERT_SYSTEM_STORE_CURRENT_USER = $00010000;
  X509_ASN_ENCODING           = $00000001;
  PKCS_7_ASN_ENCODING         = $00010000;
  ENCODING = X509_ASN_ENCODING or PKCS_7_ASN_ENCODING;
  CERT_FIND_SUBJECT_STR_W     = $00080007;
var
  hStore : THandle;
  pCert  : PCertContext;
  pInfo  : PCertInfo;
  FT     : FILETIME;
  ST     : TSystemTime;
  NowUTC : TDateTime;
  Expiry : TDateTime;
  WStore : WideString;
  WCN    : WideString;
begin
  Result := nil;
  WStore := AStore;
  WCN    := ACN;

  hStore := CertOpenStore(CERT_STORE_PROV_SYSTEM_W, 0, 0,
                          CERT_SYSTEM_STORE_CURRENT_USER,
                          PWideChar(WStore));
  if hStore = 0 then
    RaiseLastOSError;

  try
    NowUTC := TTimeZone.Local.ToUniversalTime(SysUtils.Now);
    pCert  := nil;

    repeat
      pCert := CertFindCertificateInStore(hStore, ENCODING, 0,
                 CERT_FIND_SUBJECT_STR_W, PWideChar(WCN), pCert);
      if pCert = nil then
        Break;

      pInfo  := PCertInfo(pCert^.pCertInfo);
      FT     := pInfo^.NotAfter;
      FileTimeToSystemTime(FT, ST);
      Expiry := EncodeDate(ST.wYear, ST.wMonth, ST.wDay)
              + EncodeTime(ST.wHour, ST.wMinute, ST.wSecond, 0);

      if Expiry > NowUTC then
      begin
        // Incrementa ref-count para que o contexto sobreviva ao CertCloseStore
        Result := CertDuplicateCertificateContext(pCert);
        Break;
      end;
    until False;

  finally
    CertCloseStore(hStore, 0);
  end;
end;

// ---------------------------------------------------------------------------
// Converte os bytes do SerialNumber em string hexadecimal (thumbprint simples).
// Para thumbprint SHA-1 real seria necessário CERT_SHA1_HASH_PROP_ID +
// CertGetCertificateContextProperty — isso fica como extensão futura.
// ---------------------------------------------------------------------------
function SerialToHex(const pInfo: PCertInfo): string;
var
  i    : Integer;
  lByte: PByte;
begin
  Result := '';
  if pInfo^.SerialNumber.cbData = 0 then
    Exit;
  lByte := pInfo^.SerialNumber.pbData;
  // O Windows armazena o serial em little-endian; percorremos de trás pra frente
  for i := Integer(pInfo^.SerialNumber.cbData) - 1 downto 0 do
  begin
    Result := Result + IntToHex(PByte(NativeUInt(lByte) + NativeUInt(i))^, 2);
  end;
end;

// ---------------------------------------------------------------------------
// Retorna o número de série (em hex) do certificado encontrado, ou '' se não
// houver certificado válido com o CN informado na store especificada.
// ---------------------------------------------------------------------------
function FindValidCertPath(const ACN: string; AStore: string = 'MY'): string;
var
  pCert: PCertContext;
  pInfo: PCertInfo;
begin
  Result := '';
  pCert  := FindValidCertContext(ACN, AStore);
  if pCert = nil then
    Exit;
  try
    pInfo  := PCertInfo(pCert^.pCertInfo);
    Result := SerialToHex(pInfo);
  finally
    CertFreeCertificateContext(pCert);
  end;
end;

end.
