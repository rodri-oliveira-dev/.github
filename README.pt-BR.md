# .github

[![Sincronizar versões do .NET SDK](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-sdk-sync.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-sdk-sync.yml)
[![Inventariar repositórios .NET](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-repository-inventory.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-repository-inventory.yml)

Repositório central para padrões compartilhados de comunidade e automações de manutenção dos repositórios mantidos na conta `rodri-oliveira-dev`.

> 🇺🇸 [Read in English](README.md)

## Objetivo

Este repositório fornece uma base consistente para contribuição, segurança, financiamento e algumas políticas de manutenção, evitando duplicar a mesma configuração em vários projetos.

Arquivos específicos de cada repositório sempre têm prioridade quando um projeto precisa de regras, workflows, requisitos de compatibilidade ou políticas de suporte diferentes.

## O que é centralizado aqui

| Arquivo / workflow | Finalidade |
| --- | --- |
| [`.gitattributes`](.gitattributes) | Normalização local de quebras de linha e diff para documentação, JSON e workflows do GitHub Actions. |
| [`.gitignore`](.gitignore) | Regras locais de ignore para artifacts gerados, arquivos temporários de validação, checkouts locais de ferramentas e arquivos de editor/SO. |
| [`.github.code-workspace`](.github.code-workspace) | Configurações de workspace do VS Code e recomendações de extensões para edição consistente de Markdown, YAML e GitHub Actions. |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Diretrizes padrão para contribuição, fluxo de desenvolvimento, expectativas para Pull Requests, princípios de qualidade de código e orientações comuns de validação em .NET. |
| [`SECURITY.md`](SECURITY.md) | Política padrão de segurança, reporte responsável de vulnerabilidades, expectativas de divulgação e escopo. |
| [`.github/FUNDING.yml`](.github/FUNDING.yml) | Configuração do GitHub Sponsors. |
| [`.github/workflows/dotnet-sdk-sync.yml`](.github/workflows/dotnet-sdk-sync.yml) | Automação central que verifica arquivos `global.json` na raiz dos repositórios e abre Pull Requests de atualização do SDK quando aplicável. |
| [`.github/workflows/dotnet-repository-inventory.yml`](.github/workflows/dotnet-repository-inventory.yml) | Automação central somente leitura que inventaria projetos .NET nos repositórios acessíveis à GitHub App configurada. |

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

## Automações centrais de .NET

### Sincronização central do .NET SDK

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

### Inventário central de repositórios .NET

O workflow [`dotnet-repository-inventory.yml`](.github/workflows/dotnet-repository-inventory.yml) gera um inventário consolidado, somente leitura, dos projetos .NET existentes nos repositórios acessíveis à GitHub App configurada.

Como este repositório é público, o workflow publica somente metadados de repositórios públicos no GitHub Actions Summary e nos artifacts baixáveis. Repositórios não públicos acessíveis à GitHub App são ignorados antes de clone ou relatório para que nomes de repositórios privados, caminhos, frameworks e versões de SDK não sejam expostos em execuções públicas. Se o mesmo workflow for movido para um repositório privado, ele pode incluir repositórios não públicos porque a saída da execução e os artifacts herdam a visibilidade restrita desse repositório.

Ele usa [`rodri-oliveira-dev/DotNetRepoInspector`](https://github.com/rodri-oliveira-dev/DotNetRepoInspector) como fonte de verdade para inspeção dos projetos. A classificação é baseada em metadados MSBuild efetivos obtidos pelo Inspector, não em heurísticas Bash nem parsing direto de `.csproj`.

O inventário identifica estes tipos de projeto:

- `web`;
- `worker`;
- `console`;
- `library`;
- `test`;
- `unknown`.

O workflow mantém Target Framework e .NET SDK como conceitos separados. Um Target Framework como `net10.0` descreve o alvo de compilação/execução do projeto, enquanto um SDK configurado ou resolvido como `10.0.100` descreve o SDK usado pela avaliação/build tooling do repositório.

O inventário pode ser executado manualmente por `workflow_dispatch` e também roda semanalmente às quartas-feiras, às 09:30 em `America/Sao_Paulo` (12:30 UTC), sem sobrepor o agendamento de segunda-feira da sincronização de SDK. A configuração de concorrência impede execuções simultâneas do inventário.

O GitHub Actions Summary é o relatório visual principal. Ele mostra uma tabela Markdown com uma linha por `.csproj`, incluindo repositório, caminho do projeto, tipo, Target Framework e SDK, seguida por contagens de repositórios verificados, repositórios com e sem projetos .NET, total de projetos, totais por classificação e warnings/erros de inspeção.

O workflow também exporta:

- `artifacts/dotnet-repository-inventory.csv`;
- `artifacts/dotnet-repository-inventory.json`.

Os dois arquivos são enviados como artifact `dotnet-repository-inventory` com `retention-days: 3`, permanecendo disponíveis para download na execução do workflow por 3 dias.

Repositórios sem arquivos `.csproj` são contabilizados e não fazem a execução falhar. Problemas de clone ou inspeção em repositórios individuais reportados são registrados como warnings/status, e o relatório consolidado continua sendo produzido. O workflow reutiliza as credenciais existentes da GitHub App, solicita apenas permissões de leitura no GitHub Actions, ignora forks e repositórios arquivados, inspeciona somente a branch padrão, remove diretórios temporários de cada repositório após a inspeção e não escreve nos repositórios analisados.

## Estrutura do repositório

```text
.
├── .gitattributes
├── .github/
│   ├── FUNDING.yml
│   └── workflows/
│       ├── dotnet-repository-inventory.yml
│       └── dotnet-sdk-sync.yml
├── .github.code-workspace
├── .gitignore
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
- **automação observável** — os resultados dos workflows são registrados nos logs, summaries e artifacts de curta duração quando dados estruturados são úteis.

## Contribuição

Antes de enviar uma alteração, consulte [`CONTRIBUTING.md`](CONTRIBUTING.md).

Mudanças nos padrões compartilhados devem ser amplamente aplicáveis. Comportamentos específicos de um projeto normalmente devem permanecer no próprio repositório de destino.

## Segurança

Para reporte de vulnerabilidades e expectativas de divulgação, consulte [`SECURITY.md`](SECURITY.md).

Não reporte vulnerabilidades sensíveis por meio de issues públicas do GitHub.

## Escopo

Esses padrões atendem principalmente aos repositórios e pacotes open source que mantenho, com ênfase especial no ecossistema .NET.

Cada repositório pode definir requisitos adicionais de arquitetura, CI/CD, testes, empacotamento, compatibilidade, release ou operação.
