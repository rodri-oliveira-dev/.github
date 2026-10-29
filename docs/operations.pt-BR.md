# Operação, validação e recuperação

> [English](operations.md) · [Catálogo](workflow-catalog.pt-BR.md) · [Fluxos Mermaid](automation-flows.pt-BR.md)

## Procedimento para diagnosticar uma execução

1. Abra [Actions](https://github.com/rodri-oliveira-dev/.github/actions) e identifique a **última execução pertinente** do workflow. Uma falha anterior a um merge pode já estar corrigida no código, sem uma nova execução validada.
2. Registre **run ID**, commit SHA, evento (`schedule`, `push` ou `workflow_dispatch`), branch, parâmetros, job e etapa com erro.
3. Consulte as anotações `::error`, o log, o **Step Summary** e os artefatos. Não exponha tokens ou metadados de repositórios privados em relatórios públicos.
4. Diferencie erro de configuração, bloqueio de segurança, erro agregado depois de progresso parcial, timeout e falha de scanner.
5. Antes de repetir uma mutação, confira quais PRs/branches a execução anterior criou. Uma falha do job não faz rollback das alterações já concluídas.

## Acionamentos manuais e efeitos

| Workflow | Modo seguro e impacto |
| --- | --- |
| [SDK sync](../.github/workflows/dotnet-sdk-sync.yml) | `dry_run=true` relata sem escrita; o padrão manual `false` pode criar PRs de patch |
| [Upstream skills](../.github/workflows/sync-agent-skills.yml) | `source_ref` opcional; `dry_run=true` não cria PR; padrão `false` pode criar PR central |
| [Managed skills](../.github/workflows/distribute-agent-skills.yml) | `dry_run=true` **é o padrão manual**; `false` pode criar PRs consumidores |
| [CodeRabbit](../.github/workflows/distribute-coderabbit-config.yml) | `dry_run=true` apenas detecta diferenças; `force=true` ignora a cadência de 15 dias |
| [Actions runtime audit](../.github/workflows/actions-runtime-audit.yml) | `apply_fixes=false` faz auditoria de leitura; `true` pede token de escrita e abre PRs draft elegíveis |
| [Inventory](../.github/workflows/dotnet-repository-inventory.yml) | Somente leitura; resumo e artefatos CSV/JSON, retenção de 3 dias |
| [Sonar Project](../.github/workflows/sonar-project-sync.yml) | Adiciona issues ao Project #1; exige secret `PROJECTS_TOKEN` |
| [Reusable release](../.github/workflows/reusable-workflow-release.yml) | Só manual na `main`, exige versão igual à declarada; cria tags/releases |

Os gatilhos agendados de distribuição CodeRabbit usam cron diário com gate interno para obter uma cadência exata de 15 dias. `force` afeta o gate, enquanto `dry_run` controla escrita.

## Falhas e respostas recomendadas

| Sintoma | Significado | Ação segura |
| --- | --- | --- |
| `ownership is unproven` | Branch reservada não tem PR aberto compatível ou evidência suficiente | Preserve branch; inspect prior PR and history before retry |
| `modified`, `unproven_open` | SHA, autor, base ou arquivos inesperados; possível trabalho humano | Não excluir nem forçar push; conferir proveniência |
| `coverage-failure` | Blob selecionado ultrapassa 20 MiB; inspeção incompleta | Remediar arquivo/histórico, nunca mascarar via ignore |
| `tool-failure` | Secret scanner não concluiu com confiança | Revisar CLI, hash, download e logs; não considerar `clean` |
| `clone_timeout`, `inspection_timeout` | Tempo limite do inventário excedido | Investigar repositório, MSBuild e limites configurados sem eliminar isolamento |
| `Missing PROJECTS_TOKEN` | PAT clássico exigido pelo Project ausente | Configurar secret no GitHub, jamais no código ou log |
| Erro agregado no final do lote | Outros repositórios podem ter PRs criados | Conferir Summary e PRs antes de repetir |

## Recuperação de branch e proveniência

O [contrato compartilhado](automation-branch-ownership.pt-BR.md) é aplicado pelos fluxos de sincronização do SDK e das skills. O script verifica proveniência, SHA remoto e allowlist de alterações antes de atualizar uma branch de automação. Se a branch reservada for histórica e insegura, o seletor pode usar uma branch determinística de recuperação; se ambas estiverem ocupadas, deve bloquear a mutação sem sobrescrever trabalho existente.

**Não confunda implementações:** o distribuidor CodeRabbit usa checagens próprias de branch/PR e pode reportar bloqueio em vez de recuperação; a remediação de runtimes utiliza a branch `automation/actions-node24` e compare-and-swap para garantir que o SHA não mudou.

Uma branch existente sem PR aberto não deve ser excluída somente por seu nome. Se um push teve sucesso, mas a criação do PR falhou, registre o SHA e verifique o estado remoto antes de qualquer tentativa manual. Nunca faça force-push ou exclusão cega como correção de primeira linha.

## Credenciais e privacidade

- O `GITHUB_TOKEN` do workflow geralmente usa `contents: read`. Tokens App temporários solicitam permissões apropriadas de Contents, Pull Requests ou Workflows apenas nos jobs necessários.
- As automações públicas principais ignoram repositórios não públicos e não devem registrar seus nomes em logs públicos.
- O job de inspeção MSBuild do inventário não pode receber token de escrita ou chave privada da App.
- A auditoria de runtimes só recebe escopo de escrita após opt-in manual `apply_fixes=true`, limitado aos repositórios elegíveis.
- `PROJECTS_TOKEN` é um PAT clássico com escopo `project`; não misture essa credencial com a GitHub App.

## Critérios de verificação após merge

- Para PRs de documentação: conferir pares PT-BR/EN, 13 entradas do catálogo, links relativos, renderização dos Mermaid e ausência de mudança de workflows.
- Para alterações de código: checks `Validate governance source`, `Validate workflows and shell`, `Protect control plane` e testes pertinentes; não confundir checks existentes com regras **obrigatórias** realmente configuradas.
- Após alterar uma automação de produção: executar ou observar um run relevante sobre o código **já incorporado na `main`**. Checks de PR não substituem uma execução operacional.
- Não executar scripts mutáveis localmente com credenciais de produção apenas para testar um PR.

Referências: [scripts e testes locais](automation-components.md), [regras de ownership](automation-branch-ownership.pt-BR.md), [secret scanning](secret-scanning.pt-BR.md), [quality gate](workflow-quality-gate.md) e [release de workflows](reusable-workflow-versioning.pt-BR.md).
