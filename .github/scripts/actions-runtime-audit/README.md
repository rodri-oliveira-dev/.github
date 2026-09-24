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
