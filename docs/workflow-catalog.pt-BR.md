# Catálogo de workflows

> [English](workflow-catalog.md) · [Arquitetura](architecture.pt-BR.md) · [Fluxos](automation-flows.pt-BR.md) · [Operação](operations.pt-BR.md)

Este catálogo cobre os **13 arquivos** em `.github/workflows/`, conforme a branch `main` de 29/10/2026. Horários em São Paulo (UTC−03): o cron real é expresso em UTC, não acompanha mudanças sazonais de fuso. A tabela descreve configuração, não comprova execução bem-sucedida.

## Inventário completo

| Workflow | Responsabilidade | Agendamento e gatilho |
| --- | --- | --- |
| [`actions-runtime-audit.yml`](../.github/workflows/actions-runtime-audit.yml) | Audita runtimes das Actions em repositórios públicos; PRs draft opcionais | Diário 07h15; manual |
| [`agent-governance-validation.yml`](../.github/workflows/agent-governance-validation.yml) | Valida manifesto, semântica, versões e contratos de sincronização | Todo PR; pushes selecionados na `main` |
| [`control-plane-secret-scan.yml`](../.github/workflows/control-plane-secret-scan.yml) | Aplica scanner reutilizável de secrets ao próprio `.github` | Todo PR, push `main`; quinta 10h17; manual |
| [`distribute-agent-skills.yml`](../.github/workflows/distribute-agent-skills.yml) | Propõe atualizações de quatro skills gerenciadas já instaladas | Push selecionado na `main`; manual |
| [`distribute-coderabbit-config.yml`](../.github/workflows/distribute-coderabbit-config.yml) | Distribui ponteiros remotos `.coderabbit.yaml` por perfil mapeado | A cada 15 dias; manual `force`/`dry_run` |
| [`dotnet-repository-inventory.yml`](../.github/workflows/dotnet-repository-inventory.yml) | Inventário somente leitura via DotNetRepoInspector fixado por SHA | Quarta 09h30; manual |
| [`dotnet-sdk-sync-privacy-validation.yml`](../.github/workflows/dotnet-sdk-sync-privacy-validation.yml) | Verifica privacidade da sincronização de SDK | PR / push `main` selecionados; manual |
| [`dotnet-sdk-sync.yml`](../.github/workflows/dotnet-sdk-sync.yml) | Atualiza apenas patch de SDK no `global.json` da raiz e no mesmo canal | Segunda 09h; manual |
| [`reusable-secret-scan.yml`](../.github/workflows/reusable-secret-scan.yml) | Scanner reutilizável e independente de linguagem para histórico Git | `workflow_call`; manual |
| [`reusable-workflow-release.yml`](../.github/workflows/reusable-workflow-release.yml) | Publicação manual de tags SemVer, release e alias major | Manual somente na `main` |
| [`sonar-project-sync.yml`](../.github/workflows/sonar-project-sync.yml) | Adiciona issues abertas rotuladas Sonar Quality Issues no Project #1 | Diário 06h; pushes selecionados na `main`; manual |
| [`sync-agent-skills.yml`](../.github/workflows/sync-agent-skills.yml) | Espelha quatro skills upstream na governança central | Segunda 09h20; manual |
| [`workflow-shell-quality.yml`](../.github/workflows/workflow-shell-quality.yml) | Valida YAML de workflows e scripts Bash | Todo PR, push `main`; manual |

## Credenciais, resultados e efeitos

| Workflow | Fronteira de permissão | Saída / efeito |
| --- | --- | --- |
| [`actions-runtime-audit.yml`](../.github/workflows/actions-runtime-audit.yml) | App leitura; token de escrita somente com `apply_fixes=true` manual | Artefato MD/JSON por 7 dias; PR draft opcional por repositório público elegível |
| [`agent-governance-validation.yml`](../.github/workflows/agent-governance-validation.yml) | `contents: read` | Check `Validate governance source` |
| [`control-plane-secret-scan.yml`](../.github/workflows/control-plane-secret-scan.yml) | `contents: read`; scanner fixado por SHA completo | Check `Protect control plane`; SARIF redigido por 3 dias |
| [`distribute-agent-skills.yml`](../.github/workflows/distribute-agent-skills.yml) | GitHub App Contents/PRs write | Um PR consumidor por repositório com drift; `dry_run=true` padrão manual |
| [`distribute-coderabbit-config.yml`](../.github/workflows/distribute-coderabbit-config.yml) | GitHub App Contents/PRs write | PR para configuração divergente; perfil remoto fica na `main` central |
| [`dotnet-repository-inventory.yml`](../.github/workflows/dotnet-repository-inventory.yml) | Descoberta com App leitura; inspeção separada sem credenciais | Summary e JSON/CSV, artefato por 3 dias |
| [`dotnet-sdk-sync-privacy-validation.yml`](../.github/workflows/dotnet-sdk-sync-privacy-validation.yml) | `contents: read` | Check `Validate SDK sync privacy` |
| [`dotnet-sdk-sync.yml`](../.github/workflows/dotnet-sdk-sync.yml) | GitHub App Contents/PRs write | Summary por repositório; PR sem merge; `dry_run=false` padrão manual |
| [`reusable-secret-scan.yml`](../.github/workflows/reusable-secret-scan.yml) | Caller `contents: read`, não requer secret do consumidor | Clean/findings/coverage-failure/tool-failure e SARIF redigido |
| [`reusable-workflow-release.yml`](../.github/workflows/reusable-workflow-release.yml) | Job `contents: write` | Tag imutável de versão e alias major móvel compatível |
| [`sonar-project-sync.yml`](../.github/workflows/sonar-project-sync.yml) | PAT clássico `PROJECTS_TOKEN`, escopo `project` | Visão filtrada e inclusão de issues ausentes |
| [`sync-agent-skills.yml`](../.github/workflows/sync-agent-skills.yml) | Token GitHub App; PR central | Um PR revisável; inputs `source_ref`/`dry_run` |
| [`workflow-shell-quality.yml`](../.github/workflows/workflow-shell-quality.yml) | `contents: read`, ferramentas sem privilégio | Check `Validate workflows and shell` |

## O que as automações não fazem

- **Sync .NET SDK:** altera apenas patch elegível no `global.json` da raiz, dentro de `major.minor`. Não atualiza TFM, pacotes NuGet, imagens, major ou minor. Uma [política de recomendação major](dotnet-major-migration-policy.pt-BR.md) existe, mas a implementação de recomendações ainda é proposta.
- **Inventário:** descobre projetos e propriedades avaliadas via MSBuild e DotNetRepoInspector v1.7.0, fixado por SHA. Não executa uma suíte completa de testes nem certifica compatibilidade.
- **Agent skills:** só distribui quatro skills marcadas `pull-request-existing` no [manifesto](../agent-governance/manifest.json), e somente quando o arquivo de destino já existe no consumidor. As outras cinco skills e o perfil `AGENTS.md` permanecem manuais.
- **CodeRabbit:** gerencia `.coderabbit.yaml` para as 20 entradas definidas em [cinco perfis](../coderabbit-templates/repositories.json). O `remote_config` aponta para a `main` central; alterar o template remoto pode afetar consumidores sem novo PR.
- **Auditoria de Actions:** execução agendada somente leitura; apenas `workflow_dispatch` com `apply_fixes=true` habilita PRs draft de correção por allowlist. Sinais de runtime legado não provam falha em execução.
- **Sonar:** sincroniza **issues do GitHub** já rotuladas; não consulta diretamente o SonarCloud para gerar problemas.
- **Secret scan:** o consumidor precisa de um workflow caller local; `clean` significa ausência de achados no escopo verificado, não cobertura universal.
- **Releases:** o arquivo `.github/reusable-workflows/VERSION` declara `v1.1.0`. Publicação exige workflow manual, não ocorre a cada merge.
- **Dependabot:** não é um destes 13 workflows. Sua [configuração](../.github/dependabot.yml) executa terça às 10h, propõe PRs de GitHub Actions e não faz merge.

## Gatilhos e autoridade

Os workflows mutáveis usam branches de automação e PRs revisáveis; não devem aplicar force-push em trabalho humano não comprovado. A recuperação de colisões depende de cada implementação: SDK/skills usam o seletor compartilhado, CodeRabbit e auditoria de Actions usam validações próprias. Checks de CI não devem ser confundidos com regras de merge efetivamente ativadas no GitHub. Repositórios privados ficam fora das rotinas centrais públicas; não exponha seus metadados em logs.

Leia os [diagramas de decisão](automation-flows.pt-BR.md) e o [guia operacional](operations.pt-BR.md).
