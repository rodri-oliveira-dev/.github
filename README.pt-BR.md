# .github

[![Sincronizar versões do .NET SDK](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-sdk-sync.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-sdk-sync.yml)

Repositório central para padrões compartilhados de comunidade e automações de manutenção dos repositórios mantidos na conta `rodri-oliveira-dev`.

> 🇺🇸 [Read in English](README.md)

## Objetivo

Este repositório fornece uma base consistente para contribuição, segurança, financiamento e algumas políticas de manutenção, evitando duplicar a mesma configuração em vários projetos.

Arquivos específicos de cada repositório sempre têm prioridade quando um projeto precisa de regras, workflows, requisitos de compatibilidade ou políticas de suporte diferentes.

## O que é centralizado aqui

| Arquivo / workflow | Finalidade |
| --- | --- |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Diretrizes padrão para contribuição, fluxo de desenvolvimento, expectativas para Pull Requests, princípios de qualidade de código e orientações comuns de validação em .NET. |
| [`SECURITY.md`](SECURITY.md) | Política padrão de segurança, reporte responsável de vulnerabilidades, expectativas de divulgação e escopo. |
| [`.github/FUNDING.yml`](.github/FUNDING.yml) | Configuração do GitHub Sponsors. |
| [`.github/workflows/dotnet-sdk-sync.yml`](.github/workflows/dotnet-sdk-sync.yml) | Automação central que verifica arquivos `global.json` na raiz dos repositórios e abre Pull Requests de atualização do SDK quando aplicável. |

## Como o GitHub utiliza este repositório

O GitHub permite definir arquivos padrão de comunidade através de um repositório público chamado `.github`.

Quando um dos meus repositórios públicos não possui sua própria versão de um arquivo de comunidade suportado, o GitHub pode utilizar o arquivo correspondente deste repositório.

A versão local de um arquivo continua sendo a referência para aquele projeto. Assim, os padrões compartilhados convivem com requisitos específicos de cada repositório.

Exemplos de regras que podem ser sobrescritas localmente:

- fluxo de contribuição;
- política de suporte de segurança;
- templates de issues e Pull Requests;
- política de suporte;
- código de conduta;
- requisitos de build, testes, release ou compatibilidade.

## Sincronização central do .NET SDK

O workflow [`dotnet-sdk-sync.yml`](.github/workflows/dotnet-sdk-sync.yml) fornece manutenção centralizada de SDK para os repositórios acessíveis à GitHub App configurada.

A política atual é deliberadamente conservadora:

- verifica somente o `global.json` localizado na raiz do repositório;
- ignora repositórios arquivados e forks;
- ignora SDKs preview;
- mantém as atualizações dentro do mesmo canal `major.minor`;
- considera apenas canais .NET suportados nas fases active ou maintenance;
- utiliza os metadados oficiais de releases do .NET fornecidos pela Microsoft;
- abre Pull Request em vez de alterar diretamente a branch padrão;
- não faz merge automático dos Pull Requests gerados;
- oferece modo manual `dry_run` para validar o resultado antes de aplicar alterações.

A execução agendada ocorre toda segunda-feira às 09:00 em `America/Sao_Paulo` (12:00 UTC).

Esse workflow é uma automação de manutenção e não um arquivo de comunidade herdado automaticamente pelos demais repositórios. Ele consulta ativamente os repositórios através da instalação da GitHub App e cria Pull Requests individuais quando encontra uma atualização elegível do SDK.

## Estrutura do repositório

```text
.
├── .github/
│   ├── FUNDING.yml
│   └── workflows/
│       └── dotnet-sdk-sync.yml
├── CONTRIBUTING.md
├── SECURITY.md
├── README.md
└── README.pt-BR.md
```

## Princípios de governança

Este repositório segue alguns princípios simples:

- **padrões compartilhados, autoridade local** — configurações específicas do repositório têm prioridade;
- **menor privilégio** — automações entre repositórios usam uma GitHub App com permissões restritas;
- **revisão antes da alteração** — automações de manutenção abrem Pull Requests em vez de fazer merge direto;
- **padrões seguros** — a automação de versões não realiza migrações implícitas de major/minor;
- **automação observável** — os resultados dos workflows são registrados nos logs e summaries do GitHub Actions.

## Contribuição

Antes de enviar uma alteração, consulte [`CONTRIBUTING.md`](CONTRIBUTING.md).

Mudanças nos padrões compartilhados devem ser amplamente aplicáveis. Comportamentos específicos de um projeto normalmente devem permanecer no próprio repositório de destino.

## Segurança

Para reporte de vulnerabilidades e expectativas de divulgação, consulte [`SECURITY.md`](SECURITY.md).

Não reporte vulnerabilidades sensíveis por meio de issues públicas do GitHub.

## Escopo

Esses padrões atendem principalmente aos repositórios e pacotes open source que mantenho, com ênfase especial no ecossistema .NET.

Cada repositório pode definir requisitos adicionais de arquitetura, CI/CD, testes, empacotamento, compatibilidade, release ou operação.
