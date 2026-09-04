# Secret scanning reutilizável

> 🇺🇸 [Read in English](secret-scanning.md)

O workflow [`reusable-secret-scan.yml`](../.github/workflows/reusable-secret-scan.yml) fornece uma política central de detecção de secrets para os repositórios mantidos nesta conta.

Ele é deliberadamente independente de linguagem e framework. A análise ocorre sobre o histórico Git e não depende de build, restore, instalação de dependências ou execução do código do repositório. Isso permite aplicar a mesma política a projetos .NET, Node.js, React, Java, Python, Go, Terraform e outras stacks futuras.

## Objetivos de segurança

A implementação segue estes princípios:

- **menor privilégio** — o `GITHUB_TOKEN` recebe apenas `contents: read`;
- **nenhum secret do repositório é necessário** para executar o scanner;
- **sem `pull_request_target`** — PRs utilizam o contexto não privilegiado normal do GitHub Actions;
- **código do repositório não é executado** — não há `dotnet build`, `npm install`, Maven, Gradle, scripts de projeto ou hooks;
- **histórico Git completo disponível** — `fetch-depth: 0` permite analisar ranges de commits corretamente;
- **credenciais do checkout não persistem** — `persist-credentials: false`;
- **actions fixadas por commit SHA imutável** para reduzir risco de alteração de tags;
- **Infisical CLI fixado em uma versão específica** e baixado diretamente do release oficial;
- **SHA-256 do binário é validado antes da execução**;
- **saída é redigida** com `--redact`, evitando imprimir o valor detectado do secret;
- **falha fechada** — tanto findings quanto falha da ferramenta tornam o check inválido;
- **artifacts de curta duração** — o relatório SARIF redigido fica disponível por apenas 3 dias.

O workflow complementa, e não substitui, o Secret Scanning e o Push Protection nativos do GitHub. A proteção nativa também consegue analisar superfícies que um job de CI não cobre, como conteúdo de issues, Pull Requests, Discussions e wikis.

## Escopo da análise

O workflow escolhe automaticamente o menor escopo seguro para cada evento:

| Evento | Escopo |
| --- | --- |
| `pull_request` | commits introduzidos pelo PR (`base..head`) |
| `push` | commits introduzidos pelo push (`before..after`) |
| `workflow_dispatch`, `schedule` ou contexto sem range confiável | histórico completo (`--all`) |

Isso evita repetir um full scan em cada PR sem perder a capacidade de fazer auditorias completas periódicas ou manuais.

Se o range esperado não estiver disponível localmente, o comportamento degrada para **full-history**, nunca para um scan mais fraco.

## Proteção contra alteração da própria política

Dois arquivos podem alterar o comportamento local do Infisical:

- `.infisical-scan.toml`;
- `.infisicalignore`.

Em um Pull Request, esses arquivos são tratados como **dados de segurança privilegiados**. Se o PR alterá-los, o workflow:

1. emite um warning visível;
2. restaura temporariamente a versão existente na branch base;
3. executa o scan usando essa política confiável.

Assim, um PR não consegue adicionar um secret e, no mesmo diff, adicionar uma regra de ignore para esconder o finding.

Depois que uma mudança legítima de política for revisada e mergeada, ela passa a valer normalmente nos próximos scans.

## Uso em outro repositório

Crie um caller pequeno no repositório consumidor, por exemplo `.github/workflows/secret-scan.yml`:

```yaml
name: Secret scan

on:
  pull_request:
  push:
    branches:
      - main
  schedule:
    - cron: "17 11 * * 3"
  workflow_dispatch:

permissions:
  contents: read

jobs:
  secrets:
    uses: rodri-oliveira-dev/.github/.github/workflows/reusable-secret-scan.yml@main
```

Para maior isolamento de supply chain, consumidores externos ou repositórios com exigência mais rígida podem substituir `@main` por um commit SHA imutável do workflow central. Nos repositórios mantidos pela própria conta, usar `@main` permite receber correções da política central sem duplicar YAML.

## Cobertura por stack

O scanner não depende de uma lista de extensões. Arquivos versionados são analisados pelos padrões e heurísticas do Infisical, incluindo casos comuns como:

### .NET

- `appsettings.json` e `appsettings.*.json`;
- `launchSettings.json`;
- `NuGet.Config`;
- connection strings;
- NuGet API keys;
- JWT signing keys;
- Azure, AWS e GCP credentials;
- certificados e private keys.

### Node.js / React / front-end

- `.env`, `.env.*` e arquivos equivalentes;
- `.npmrc`;
- npm tokens;
- API keys usadas em scripts de build;
- credenciais de serviços externos;
- chaves privadas ou certificados.

Variáveis destinadas ao bundle do navegador — por exemplo variáveis explicitamente públicas de frameworks front-end — **não devem ser tratadas como mecanismo de armazenamento de secrets**. Se o valor chega ao cliente, deve ser considerado público por arquitetura.

### Java / JVM

- `application.properties`;
- `application.yml` / `application.yaml`;
- `settings.xml`;
- `gradle.properties`;
- credenciais de registries e artifact repositories;
- keystores, private keys e tokens de cloud providers.

### Python, Go e outras linguagens

A mesma política cobre `.env`, arquivos de configuração, tokens hardcoded, connection strings, credenciais cloud, private keys e outros padrões detectáveis, independentemente da linguagem do código.

### Infraestrutura e CI/CD

Também são relevantes:

- `*.tfvars` e Terraform configuration;
- Kubernetes manifests e kubeconfig;
- Docker / Compose configuration;
- GitHub Actions workflows;
- arquivos de configuração de deploy;
- service-account keys;
- scripts Shell e PowerShell.

## Falsos positivos

Um finding só deve ser ignorado depois de verificar que o valor **não concede acesso real**.

Prefira fingerprints específicos em `.infisicalignore` a exclusões amplas por diretório ou extensão. Evite ignorar genericamente arquivos como `appsettings*.json`, `.env*`, `application*.yml` ou arquivos de CI/CD, pois eles são justamente superfícies frequentes de exposição.

Mudanças em `.infisicalignore` ou `.infisical-scan.toml` devem receber o mesmo nível de revisão que uma alteração em configuração de segurança.

Nunca use uma regra de ignore para "resolver" uma credencial real exposta.

## Resposta a um secret real

Quando o scanner detectar uma credencial verdadeira:

1. **revogue ou rotacione a credencial imediatamente**;
2. remova o valor do código e mova-o para o mecanismo apropriado de secret management;
3. revise logs e uso do serviço para procurar utilização indevida;
4. determine se é necessário remover o valor do histórico Git;
5. somente depois trate eventuais regras de prevenção ou documentação.

Reescrever o histórico sem revogar a credencial não torna uma credencial exposta novamente segura.

## Configuração local opcional

Repositórios podem adicionar `.infisical-scan.toml` quando precisarem de regras ou ajustes específicos. Também podem utilizar `.infisicalignore` para fingerprints de falsos positivos conhecidos.

A configuração local deve permanecer excepcional e restritiva: a política central busca funcionar sem configuração específica por linguagem.

Referências:

- [Infisical CLI secret scanning](https://infisical.com/docs/cli/commands/scan)
- [Infisical secret scanning overview](https://infisical.com/docs/documentation/platform/secret-scanning/overview)
- [GitHub Secret Scanning](https://docs.github.com/en/code-security/concepts/secret-security/secret-scanning)
- [GitHub Actions secure use](https://docs.github.com/en/actions/reference/security/secure-use)
