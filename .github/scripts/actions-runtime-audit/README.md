# GitHub Actions runtime audit

Auditoria somente de leitura dos **repositórios públicos ativos** acessíveis à instalação da GitHub App. Analisa workflows, Actions locais, manifestos de Actions externas fixadas por tag/SHA, dependências de Actions compostas e workflows reutilizáveis. Não executa código dos repositórios auditados.

**Confidencialidade:** o repositório central .github é público. Por isso, os repositórios privados ficam fora do escopo e apenas sua quantidade é exibida. Para um relatório acionável de repositórios privados, publique este mesmo scanner em um repositório central privado, com token e artefatos privados. Este workflow público não revela nomes, caminhos nem conteúdo de repositórios privados.

## Execução e relatório

Disponível em Actions → GitHub Actions runtime audit → Run workflow. Executa diariamente às 10:15 UTC (07:15 em São Paulo, UTC−03), usando a GitHub App já configurada por DOTNET_SDK_SYNC_APP_CLIENT_ID e DOTNET_SDK_SYNC_APP_PRIVATE_KEY, com permissões contents:read e metadata:read. A instalação deve ter acesso aos repositórios auditados.

O workflow publica report.md e report.json como artefato por 7 dias e adiciona o relatório à página da execução. legacy_runtime indica manifesto que **declara** runtime antigo, não prova de falha no runner. unverified registra dependências inacessíveis, contêineres, referências dinâmicas e inspeções incompletas separadamente; ausência de achados não constitui garantia de compatibilidade. A política em policy.json contém sugestões de migração para Actions conhecidas, sem inferir que qualquer versão antiga seja vulnerável ou que qualquer SHA corresponda a uma tag específica.

Para executar os testes locais:

    python -m pip install -r .github/scripts/actions-runtime-audit/requirements.txt
    python -m unittest discover -s .github/scripts/actions-runtime-audit -p 'test_*.py'

A auditoria não substitui testes de execução de CI, análise de vulnerabilidades, verificação de runners self-hosted ou revisão de imagens Docker.


## Correção automática opcional

Na execução manual, marque a opção booleana **apply_fixes** para criar um PR em modo rascunho por repositório público elegível. Sem a opção, inclusive na execução agendada, a auditoria continua exclusivamente de leitura. O job de correção é separado do job de auditoria e só recebe credenciais de escrita após o opt-in explícito.

A GitHub App deve ter, na instalação, as permissões de repositório Contents: write, Pull requests: write e Workflows: write, além de Metadata: read. **Workflows: write é necessário para modificar .github/workflows**. Se a instalação ainda não tiver essa permissão, um administrador precisa concedê-la/aprovar o novo conjunto de permissões; o workflow sinalizará a impossibilidade de criar os PRs. O GITHUB_TOKEN deste repositório permanece somente de leitura.

O processo usa uma allowlist explícita em policy.json com tags e SHAs completos de Actions oficiais, verifica os manifestos de origem (runtime legado) e de destino (node24), altera somente referências remotas diretas dentro de steps ou jobs de workflows e Actions compostas próprias, e mantém os demais campos e comentários existentes. Referências dinâmicas, Actions de terceiros, Actions JavaScript próprias e dependências indiretas continuam para revisão manual. O relatório não garante compatibilidade comportamental das versões novas; cada PR deve passar por revisão e CI antes do merge.

Para cada repositório, a automação prepara uma única alteração atômica na branch estável `automation/actions-node24`. Se já houver PR aberto para essa branch, a execução não cria outro PR nem adiciona commits. Quando a branch existe sem PR aberto, ela só é reutilizada se o commit no topo tiver a mensagem exata produzida por esta automação e um único pai. O novo tree e o novo commit são preparados primeiro e, somente depois, a referência existente é atualizada com compare-and-swap (`beforeOid`/`afterOid`) usando o SHA previamente inspecionado. Se a branch mudar nesse intervalo, a atualização é rejeitada e registrada como erro, sem sobrescrever o novo tip. Se a branch não puder ser atribuída com segurança à automação, ela não é alterada e o repositório fica marcado para revisão manual. Erros por repositório constam do artefato remediation.json e fazem o job falhar, sem desfazer PRs criados em outros repositórios. A automação não inclui privados, forks ou arquivados, não aprova nem integra PRs e não executa código de repositórios consumidores.
