# ClientHttp

Biblioteca Delphi para requisições HTTP/REST utilizando a API nativa WinHTTP do Windows. Sem dependências externas além das já presentes no sistema operacional.

## Requisitos

- Delphi XE7 ou superior
- Windows (a lib é exclusivamente para Windows por depender da WinHTTP)

## Funcionalidades

- Requisições HTTP/REST (GET, POST, PUT, DELETE, etc.)
- Suporte a HTTPS
- Autenticação por certificado digital (busca por CN no repositório do Windows)
- Adição de headers customizados
- Envio de payload (body) em UTF-8
- Reaproveitamento de sessão para o mesmo host
- Leitura da resposta como `TStream` ou `String`

## Roadmap

- [ ] Métodos para leitura dos headers de resposta
- [ ] Métodos assíncronos (async/callback)

## Instalação

Adicione as units do diretório `Source/` ao seu projeto ou ao library path do Delphi.

## Uso básico

```delphi
var
  Http: TClientHttp;
begin
  Http := TClientHttp.Create;
  try
    Http.AddHeaders('Content-Type: application/json');
    Http.Post('URL', JSON);
    Http.Get('URL', JSON);
    .
    .
    .

    Writeln('Status: ', Http.Status);
    Writeln('Resposta: ', Http.Response);
  finally
    Http.Free;
  end;
end;
```
## Exemplo com certificado digital

```delphi
Http.AddCertificadoByCN('NOME DO CERTIFICADO');
Http.Post('URL', JSON);
```

O certificado é buscado automaticamente no repositório do Windows pelo Common Name (CN).
Nao tenho certeza se funciona com certificado A3. Nao testei ainda.

## Comportamento da sessão

A sessão WinHTTP é reutilizada entre requisições para o mesmo host, melhorando a performance. Ao trocar de host, a sessão é encerrada e uma nova é criada automaticamente.

## Estrutura do projeto

```
/
├── Source/
|   ├── ClientHttp.pas
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
