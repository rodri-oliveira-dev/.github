# Fluxos de execução e decisão

> [English](automation-flows.md) · [Arquitetura](architecture.pt-BR.md) · [Catálogo](workflow-catalog.pt-BR.md) · [Operação](operations.pt-BR.md)

Os diagramas Mermaid abaixo descrevem **contratos e decisões previstos pelo código**. Não representam resultados históricos nem comprovam que um agendamento foi executado. Os textos internos dos diagramas preservam os nomes técnicos dos workflows para facilitar investigação em logs.

## 1. Sincronização de patch do SDK

[`dotnet-sdk-sync.yml`](../.github/workflows/dotnet-sdk-sync.yml)

```mermaid
flowchart TD
  A["Discover repositories"] --> B{"Owned, public, non-archived and non-fork?"}
  B -->|No| Skip["Skip; anonymize non-public"]
  B -->|Yes| C{"Root global.json present?"}
  C -->|No| Skip
  C -->|Yes| D["Fetch official stable release metadata"]
  D --> E{"New eligible patch in same major.minor?"}
  E -->|No| Current["Current or ineligible"]
  E -->|Yes| Ownership["Check versions and branch/PR provenance"]
  Ownership --> Safe{"Owned branch or safe recovery available?"}
  Safe -->|No| Block["Security block, preserve existing work"]
  Safe -->|Yes| PR["Create or refresh reviewed PR; no auto-merge"]
  Block --> Summary["Aggregate Summary"]
  PR --> Summary
  Skip --> Summary
  Current --> Summary
```

Apenas `global.json` na raiz e atualizações estáveis suportadas no mesmo canal `major.minor` do SDK. Uma colisão pode selecionar branch alternativa determinística; se nenhuma for segura, aquele repositório é bloqueado e o lote continua.

## 2. Inventário .NET somente leitura

[`dotnet-repository-inventory.yml`](../.github/workflows/dotnet-repository-inventory.yml)

```mermaid
flowchart TD
  A["Read-only App discovery"] --> Filter["Filter public owned active non-fork repos"]
  Filter --> Artifact["Sanitized one-day handoff artifact"]
  Artifact --> Job["Separate inspection without App credentials"]
  Job --> Clone["Clone with timeout"]
  Clone --> Inspect["Pinned DotNetRepoInspector + MSBuild evaluation"]
  Inspect --> Outcome{"Evaluated?"}
  Outcome -->|Yes| Records["Project kind, TFM, SDK, publishing states"]
  Outcome -->|No| Problems["Record warning, error or timeout"]
  Records --> Output["Step Summary + JSON and CSV artifacts, three days"]
  Problems --> Output
```

A credencial App existe apenas na descoberta. A inspeção não recebe chaves da GitHub App, usa DotNetRepoInspector/MSBuild fixado por SHA e aplica timeout no clone e na avaliação; falhas não contam como inspeção bem-sucedida.

## 3. Skills upstream até revisão do consumidor

[`sync-agent-skills.yml`](../.github/workflows/sync-agent-skills.yml) · [`distribute-agent-skills.yml`](../.github/workflows/distribute-agent-skills.yml)

```mermaid
flowchart TD
  Up["dotnet-library-template main"] --> Diff["Compare four allowlisted skills byte-for-byte"]
  Diff --> Drift{"Central registry drift?"}
  Drift -->|No| Current["No change"]
  Drift -->|Yes| Central["Create or refresh central PR"]
  Central --> Review["Human review, validation, merge"]
  Review --> Push["Approved main push triggers distribution"]
  Push --> Eligible{"Public consumer with existing managed target?"}
  Eligible -->|No| Skip["Skip missing target or ineligible consumer"]
  Eligible -->|Yes| ConsumerDrift{"File differs from approved central content?"}
  ConsumerDrift -->|No| Current
  ConsumerDrift -->|Yes| ConsumerPR["One PR per repository for changed managed files"]
  ConsumerPR --> Gate["Consumer CI and human review; no auto-merge"]
```

Apenas quatro skills gerenciadas no manifesto são sincronizadas e distribuídas; o consumidor só é elegível se o alvo gerenciado já existir. Cinco skills e as instruções de perfil continuam manuais.

## 4. Distribuição de perfis CodeRabbit

[`distribute-coderabbit-config.yml`](../.github/workflows/distribute-coderabbit-config.yml)

```mermaid
flowchart TD
  Map["Five profiles / mapped repositories.json"] --> Cadence["Fifteen-day cadence or manual dispatch"]
  Cadence --> Repo{"Eligible mapped repo, active and not fork?"}
  Repo -->|No| Skip["Skip"]
  Repo -->|Yes| Pointer["Render remote_config pointer"]
  Pointer --> Compare{"Diff from default branch?"}
  Compare -->|No| Current["Already current"]
  Compare -->|Yes| Proven{"Expected branch and PR ownership proven?"}
  Proven -->|No| Block["Record error; do not overwrite"]
  Proven -->|Yes| PR["Propose config update in PR"]
  PR --> Remote["CodeRabbit reads central template on main"]
```

O workflow usa sua própria validação da branch reservada, que não equivale necessariamente à recuperação compartilhada de SDK/skills. O `.coderabbit.yaml` proposto aponta para um perfil central na `main`.

## 5. Auditoria de runtimes de Actions e remediação opcional

[`actions-runtime-audit.yml`](../.github/workflows/actions-runtime-audit.yml)

```mermaid
flowchart TD
  Run["Daily read-only audit"] --> Scan["Inspect workflow / Action manifests"]
  Scan --> Report["Classify legacy runtimes and unverified dependencies"]
  Report --> Artifact["Seven-day MD and JSON artifact"]
  Artifact --> Opt{"Manual apply_fixes=true?"}
  Opt -->|No| End["End without mutation"]
  Opt -->|Yes| Token["Create repository-scoped write token"]
  Token --> Allow{"Official Action and verified allowlisted fix?"}
  Allow -->|No| Manual["Manual investigation"]
  Allow -->|Yes| Draft["Open draft remediation PR"]
  Draft --> Review["Consumer review and CI"]
```

A auditoria agendada é somente leitura. Apenas `apply_fixes=true` acionado manualmente solicita permissões de escrita limitadas e cria PRs draft para Actions oficiais permitidas e verificadas.

## 6. Secret scanning reutilizável do histórico Git

[`reusable-secret-scan.yml`](../.github/workflows/reusable-secret-scan.yml)

```mermaid
flowchart TD
  Event["PR, push, schedule or workflow_call"] --> Scope["Select trustworthy commit range; else full history"]
  Scope --> Policy["Use base-branch scanner policy for PR policy edits"]
  Policy --> Size{"Every selected Git blob <= 20 MiB?"}
  Size -->|No| Coverage["coverage-failure"]
  Size -->|Yes| Install["Download and SHA256-verify pinned Infisical CLI"]
  Install --> Scan["Run redacted Git-history scan"]
  Scan --> Status{"Result?"}
  Status -->|No findings| Clean["clean"]
  Status -->|Possible secrets| Findings["findings"]
  Status -->|Tool error| Failure["tool-failure"]
  Clean --> SARIF["Redacted SARIF, 3 days"]
  Findings --> SARIF
  Failure --> SARIF
```

O scanner usa a política da branch base quando o PR altera suas exclusões; cobertura incompleta de blobs grandes e falhas da ferramenta bloqueiam o check. `clean` se limita ao escopo examinado.

## 7. Sincronização de issues GitHub com Project #1

[`sonar-project-sync.yml`](../.github/workflows/sonar-project-sync.yml)

```mermaid
flowchart LR
  Issues["Open GitHub issues labeled Sonar Quality Issues"] --> Query["GitHub issue search"]
  Query --> Presence{"Already in Project #1?"}
  Presence -->|No| Add["Add issue to Project"]
  Presence -->|Yes| Existing["Keep existing item"]
  Add --> View["Filtered Sonar Quality Issues view"]
  Existing --> View
```

O workflow busca **issues do GitHub** abertas e rotuladas, não consulta a API SonarCloud. Issues fechadas permanecem no histórico do Project e somem da visão filtrada.

## 8. Publicação explícita de workflow reutilizável

[`reusable-workflow-release.yml`](../.github/workflows/reusable-workflow-release.yml)

```mermaid
flowchart TD
  PR["Review version bump in reusable-workflows/VERSION"] --> Main["Merge into main"]
  Main --> Dispatch["Manual workflow_dispatch for declared version"]
  Dispatch --> Validate{"Canonical SemVer, main SHA and ancestry valid?"}
  Validate -->|No| Stop["Fail without retargeting immutable release"]
  Validate -->|Yes| Tag["Create immutable version tag and release"]
  Tag --> Alias["Promote compatible major alias"]
  Alias --> Consumer["Consumers pin major alias, patch tag or full SHA"]
```

O revisor incorpora primeiro o bump de versão. O mantenedor dispara manualmente a versão correspondente na `main`. Tags SemVer existentes são imutáveis; o alias major compatível pode avançar.

## Recursos adicionais

Para as fronteiras de confiança, veja [arquitetura](architecture.pt-BR.md). Para bloqueios, dry-run e recuperação segura, consulte [operações](operations.pt-BR.md) e o [contrato de ownership](automation-branch-ownership.pt-BR.md).
