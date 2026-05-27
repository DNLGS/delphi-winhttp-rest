# ClientHttp

Mais um cliente HTTP para Delphi. Feito porque toda vez que eu usava o Indy me dava trabalho pra usar certificado ou acessar um endpoint com HTTPS(Possivelmente eu nao saiba usar ele direito).
Usa a WinHTTP nativa do Windows — sem dependências externas, sem instalação de componentes, sem surpresa.

> ⚠️ **Projeto em construção.** Funciona para o meu propósito atual, mas ainda está simples e incompleto. Use com essa expectativa.

## Requisitos

- Delphi XE7 ou superior
- Windows (e só Windows, WinHTTP não negocia)

## O que já funciona

- Requisições HTTP/REST (GET, POST, PUT, DELETE, etc.)
- HTTPS
- Autenticação por certificado digital — busca pelo CN no repositório do Windows
- Headers customizados
- Payload em UTF-8
- Reaproveitamento de sessão para o mesmo host
- Resposta como `TStream` ou `String`

## O que ainda vem por aí

- [ ] Leitura dos headers de resposta
- [ ] Métodos assíncronos (async/callback)

## Instalação

Adicione as units da pasta `Source/` ao seu projeto ou ao library path do Delphi. Só isso.

## Uso básico

```delphi
var
  Http: TClientHttp;
begin
  Http := TClientHttp.Create;
  try
    Http.AddHeaders('Content-Type', 'application/json');
    Http.Post('URL', JSON);
    // ou Http.Get('URL');

    Writeln('Status: ', Http.Status);
    Writeln('Resposta: ', Http.Response);
  finally
    Http.Free;
  end;
end;
```

## Certificado digital

```delphi
Http.AddCertificadoByCN('NOME DO CERTIFICADO');
Http.Post('URL', JSON);
```

O certificado é buscado pelo Common Name (CN) no repositório do Windows.

> Certificado A3 — não testei ainda, não sei se funciona.

## Comportamento da sessão

A sessão WinHTTP é reutilizada entre requisições para o mesmo host. Trocou de host, a sessão é encerrada e uma nova é criada automaticamente.

## Estrutura do projeto

```
/
├── Source/
│   ├── ClientHttp.pas
│   ├── ClientHttp.Core.pas
│   ├── ClientHttp.Wrapper.pas
│   ├── ClientHttp.Utils.pas
│   ├── ClientHttp.Constantes.pas
│   └── ClientHttp.Cert.Aux.pas
├── Samples/
│   └── BasicRequest/
├── README.md
└── LICENSE
```

## Licença

MIT
