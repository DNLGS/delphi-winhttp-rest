unit clientHttp.wrapper;

interface

uses Windows, SysUtils;

type
  HINTERNET = Pointer;

  URL_COMPONENTS = record
    dwStructSize: DWORD;
    lpszScheme: PwChar;
    dwSchemeLength: DWORD;
    nScheme: DWORD;
    lpszHostName: PwChar;
    dwHostNameLength: DWORD;
    nPort: DWORD;
    lpszUserName: PwChar;
    dwUserNameLength: DWORD;
    lpszPassword: PwChar;
    dwPasswordLength: DWORD;
    lpszUrlPath: PwChar;
    dwUrlPathLength: DWORD;
    lpszExtraInfo: PwChar;
    dwExtraInfoLength: DWORD;
  end;

  PURL_COMPONENTS = ^URL_COMPONENTS;

function WinHttpOpen(
  pszAgentW: PWideChar;
  dwAccessType: DWORD;
  pszProxyW: PWideChar;
  pszProxyBypassW: PWideChar;
  dwFlags: DWORD): HINTERNET; stdcall;

function WinHttpConnect(
  hSession: HINTERNET;
  pswzServerName: PWideChar;
  nServerPort: Word;
  dwReserved: DWORD): HINTERNET; stdcall;

function WinHttpOpenRequest(
  hConnect: HINTERNET;
  pwszVerb: PWideChar;
  pwszObjectName: PWideChar;
  pwszVersion: PWideChar;
  pwszReferrer: PWideChar;
  ppwszAcceptTypes: PPWideChar;
  dwFlags: DWORD): HINTERNET; stdcall;

function WinHttpSendRequest(
  hRequest: HINTERNET;
  lpszHeaders: PWideChar;
  dwHeadersLength: DWORD;
  lpOptional: LPVOID;
  dwOptionalLength: DWORD;
  dwTotalLength: DWORD;
  dwContext: DWORD_PTR): BOOL; stdcall;

function WinHttpReceiveResponse(
  hRequest: HINTERNET;
  lpReserved: LPVOID): BOOL; stdcall;

function WinHttpQueryDataAvailable(
  hRequest: HINTERNET;
  lpdwNumberOfBytesAvailable: LPDWORD): BOOL; stdcall;

function WinHttpReadData(
  hRequest: HINTERNET;
  lpBuffer: LPVOID;
  dwNumberOfBytesToRead: DWORD;
  lpdwNumberOfBytesRead: LPDWORD): BOOL; stdcall;

function WinHttpCloseHandle(
  hInternet: HINTERNET): BOOL; stdcall;

function WinHttpAddRequestHeaders(
  hRequest: HINTERNET;
  lpszHeaders: LPCWSTR;
  dwHeadersLength: DWORD;
  dwModifiers: DWORD): BOOL; stdcall;

function WinHttpSetOption(
  hInternet: HINTERNET;
  dwOption: DWORD;
  lpBuffer: LPVOID;
  dwBufferLength: DWORD): BOOL; stdcall;

function WinHttpQueryHeaders(
  hRequest : HINTERNET;
  dwInfoLevel: DWORD;
  pwszName: PWChar;
  lpBuffer: LPVOID;
  lpdwBufferLength: PWORD;
  lpdwIndex: PWORD
) : BOOL; stdcall;

function WinHttpCrackUrl(
  pwszUrl: PwChar;
  dwUrlLength: DWORD;
  dwFlags: DWORD;
  LPURL_COMPONENTS: PURL_COMPONENTS): BOOL; stdcall;

implementation

function WinHttpOpen; external 'winhttp.dll' name 'WinHttpOpen';
function WinHttpConnect; external 'winhttp.dll' name 'WinHttpConnect';
function WinHttpOpenRequest; external 'winhttp.dll' name 'WinHttpOpenRequest';
function WinHttpSendRequest; external 'winhttp.dll' name 'WinHttpSendRequest';
function WinHttpReceiveResponse; external 'winhttp.dll' name 'WinHttpReceiveResponse';
function WinHttpQueryDataAvailable; external 'winhttp.dll' name 'WinHttpQueryDataAvailable';
function WinHttpReadData; external 'winhttp.dll' name 'WinHttpReadData';
function WinHttpCloseHandle; external 'winhttp.dll' name 'WinHttpCloseHandle';
function WinHttpAddRequestHeaders; external 'winhttp.dll' name 'WinHttpAddRequestHeaders';
function WinHttpSetOption; external 'winhttp.dll' name 'WinHttpSetOption';
function WinHttpQueryHeaders; external 'winhttp.dll' name 'WinHttpQueryHeaders';
function WinHttpCrackUrl; external 'winhttp.dll' name 'WinHttpCrackUrl';

end.
