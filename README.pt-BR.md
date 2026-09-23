# .github

[![Sincronizar versões do .NET SDK](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-sdk-sync.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-sdk-sync.yml)
[![Inventariar repositórios .NET](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-repository-inventory.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/dotnet-repository-inventory.yml)
[![Secret scan do control plane](https://github.com/rodri-oliveira-dev/.github/actions/workflows/control-plane-secret-scan.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/control-plane-secret-scan.yml)
[![Validar governança de agentes](https://github.com/rodri-oliveira-dev/.github/actions/workflows/agent-governance-validation.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/agent-governance-validation.yml)
[![Sincronizar skills upstream](https://github.com/rodri-oliveira-dev/.github/actions/workflows/sync-agent-skills.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/sync-agent-skills.yml)
[![Distribuir skills gerenciadas](https://github.com/rodri-oliveira-dev/.github/actions/workflows/distribute-agent-skills.yml/badge.svg)](https://github.com/rodri-oliveira-dev/.github/actions/workflows/distribute-agent-skills.yml)

Repositório central para padrões compartilhados de comunidade, automações de manutenção e governança de agentes dos repositórios mantidos na conta `rodri-oliveira-dev`.

> 🇺🇸 [Read in English](README.md)

## Objetivo

Este repositório fornece uma base consistente para contribuição, segurança, financiamento, políticas de manutenção e governança de agentes, evitando duplicar a mesma configuração em vários projetos.

Arquivos específicos de cada repositório sempre têm prioridade quando um projeto precisa de regras, workflows, requisitos de compatibilidade, políticas de suporte ou instruções locais de agentes diferentes.

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
| [`.github/workflows/reusable-secret-scan.yml`](.github/workflows/reusable-secret-scan.yml) | Política reutilizável e agnóstica de linguagem para análise de secrets no histórico Git, aplicável a .NET e também a stacks futuras como Node.js, React, Java, Python, Go, Terraform, Kubernetes e Docker. |
| [`.github/workflows/control-plane-secret-scan.yml`](.github/workflows/control-plane-secret-scan.yml) | Aplica a política reutilizável de secret scanning ao próprio control plane em todo Pull Request, pushes para `main`, auditorias agendadas e execuções manuais. |
| [`.github/workflows/agent-governance-validation.yml`](.github/workflows/agent-governance-validation.yml) | Validação determinística do registry central de governança, mappings do perfil, skills gerenciadas e contratos de sincronização/distribuição. |
| [`.github/workflows/sync-agent-skills.yml`](.github/workflows/sync-agent-skills.yml) | Sincronização semanal de quatro skills .NET em allowlist a partir do `dotnet-library-template`, sempre por Pull Request revisável no registry central. |
| [`.github/workflows/distribute-agent-skills.yml`](.github/workflows/distribute-agent-skills.yml) | Distribui skills gerenciadas aprovadas em `.github/main` para repositórios públicos consumidores que já utilizam essas skills, abrindo um Pull Request por repositório quando existe drift. |
| [`agent-governance/`](agent-governance/) | Registry canônico versionado para instruções, perfis e skills reutilizáveis de agentes. Esses arquivos são distribuídos explicitamente aos consumidores; não são herdados automaticamente. |

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
- requisitos de build, testes, release ou compatibilidade;
- instruções e skills específicas de agentes do repositório.

## Integração com a API do GitHub

Este repositório também atua como um control plane para integrações construídas sobre uma GitHub App e a GitHub REST API. Os workflows de manutenção se autenticam com tokens de instalação de curta duração e utilizam operações de API com escopo restrito para descobrir repositórios, ler metadados e conteúdos, criar ou atualizar branches e abrir Pull Requests revisáveis.

As integrações atuais baseadas na API incluem:

- sincronização do `.NET SDK`, que descobre repositórios, lê `global.json`, cria branches de atualização, grava alterações elegíveis de SDK e abre Pull Requests;
- distribuição de skills gerenciadas de agentes, que inspeciona repositórios consumidores e cria ou atualiza Pull Requests quando as skills centrais aprovadas apresentam drift;
- inventário de repositórios `.NET`, que usa a GitHub App como fronteira de descoberta somente leitura antes da inspeção dos projetos.

O modelo de integração segue o princípio de menor privilégio: as permissões da GitHub App são restritas às necessidades de cada workflow, alterações são controladas por revisão através de Pull Requests e workflows somente leitura não modificam os repositórios inspecionados.

Branches reservadas de automação usam um contrato explícito de provenance em vez de confiar no nome da branch. Uma branch existente só pode ser atualizada quando um Pull Request aberto correspondente, no mesmo repositório, contém o marker de ownership esperado e seu head SHA corresponde ao ref remoto atual; force-updates ainda usam `--force-with-lease` vinculado explicitamente ao SHA capturado. Consulte [ownership de branches de automação](docs/automation-branch-ownership.pt-BR.md) para o contrato completo e o procedimento de recuperação de branches órfãs.

## Implementação e testes locais das automações

Os workflows de manutenção são camadas finas de orquestração. Os componentes Bash versionados, as fronteiras de confiança preservadas e as suítes de regressão offline estão documentados em [componentes de automação e validação local](docs/automation-components.md).

## Manutenção das dependências de GitHub Actions

O [Dependabot](.github/dependabot.yml) verifica as Actions usadas neste control plane **toda terça-feira às 10h (America/Sao_Paulo)**. Ele propõe Pull Requests de atualização para a `main`, sujeitos a revisão humana. Esta configuração vale apenas para este repositório: **não** é herdada automaticamente pelos demais repositórios como um arquivo de community health. Não são necessárias novas credenciais de GitHub App, permissões elevadas ou configuração de auto-merge.

Mantenha todas as referências `uses:` remotas fixadas por **SHA completo de 40 caracteres** e preserve, quando disponível, o comentário na mesma linha com a versão legível da Action. Apenas atualizações minor/patch de `actions/upload-artifact` e `actions/download-artifact` são agrupadas para validação conjunta. Atualizações major e Actions que recebem credenciais, como `actions/create-github-app-token`, permanecem em PRs separados.

Antes do merge de um PR do Dependabot, confira as notas de release e a correspondência entre tag e commit; examine alterações de permissões e do código executado com secrets; confirme que os `uses:` continuam apontando para SHAs imutáveis, com comentários de versão coerentes; execute os checks existentes de governança, privacidade e secret scanning. Mudanças nos pins de reusable workflows ou Actions do próprio control plane que fazem parte de contratos explícitos exigem atualização coordenada das validações: não contorne esses controles. Preserve revisão humana e as regras de proteção de merge; não habilite auto-merge para PRs do bot.

Depois de integrar a configuração à `main`, consulte **Insights → Dependency graph → Dependabot** para conferir a última verificação do GitHub. A abertura do primeiro PR automático e o estado das configurações do serviço não podem ser comprovados apenas com este PR de configuração.

## Automações centrais de .NET

O [manifesto canônico de agent governance](agent-governance/manifest.json) define as nove skills e a política de ownership/distribuição por artefato. Quatro skills mantidas no upstream são sincronizadas e oferecidas a consumidores existentes por Pull Request revisado; as outras cinco e as instruções do perfil permanecem manuais. A [documentação de agent governance](agent-governance/README.md) descreve o schema e a validação local.


Mudanças no contrato de governança passam por verificação de versão em todo Pull Request: alterações em skills canônicas, políticas de agentes, instruções do perfil ou conteúdo semântico do manifesto/perfil exigem incremento de `agent-governance/VERSION` e versões coerentes no manifesto e no perfil. Atualizações de documentação independente não exigem bump. Consulte a [política de versionamento](agent-governance/README.md#required-version-bump-in-pull-requests).

### Sincronização central do .NET SDK

O workflow [`dotnet-sdk-sync.yml`](.github/workflows/dotnet-sdk-sync.yml) fornece manutenção centralizada de SDK para os repositórios acessíveis à GitHub App configurada.

A política atual é deliberadamente conservadora:

- verifica somente o `global.json` localizado na raiz do repositório;
- processa somente repositórios públicos; repositórios não públicos são reduzidos a uma contagem agregada anônima antes de qualquer processamento ou relatório específico do repositório;
- ignora repositórios arquivados e forks;
- ignora SDKs preview;
- mantém as atualizações dentro do mesmo canal `major.minor`;
- considera apenas canais .NET suportados nas fases active ou maintenance;
- utiliza os metadados oficiais de releases do .NET fornecidos pela Microsoft;
- abre Pull Request em vez de alterar diretamente a branch padrão;
- não faz merge automático dos Pull Requests gerados;
- oferece modo manual `dry_run` para validar o resultado antes de aplicar alterações.

A execução agendada ocorre toda segunda-feira às 09:00 em `America/Sao_Paulo` (12:00 UTC). O job de sincronização do SDK possui **limite global explícito de 90 minutos**. Se esse limite for atingido, o GitHub cancela a execução; repositórios restantes e o Summary final podem não ser processados, e uma mutação GitHub em andamento não é automaticamente repetida ou revertida. Erros operacionais por repositório continuam seguindo a política de isolamento do lote descrita abaixo.

Esse workflow é uma automação de manutenção e não um arquivo de comunidade herdado automaticamente pelos demais repositórios. Ele consulta ativamente os repositórios através da instalação da GitHub App e cria Pull Requests individuais quando encontra uma atualização elegível do SDK.

Como este control plane é público, a sincronização de SDK trata a visibilidade do repositório como uma trust boundary. A saída da descoberta da instalação serializa metadados completos somente quando a visibilidade é explicitamente `public`; valores private, internal, ausentes ou de qualquer outra forma não públicos são convertidos imediatamente em um marcador anônimo. Logs públicos e o Job Summary expõem apenas a contagem agregada de repositórios não públicos ignorados, e o loop de sincronização não realiza operações de leitura ou escrita nesses repositórios.

A branch reservada `chore/sync-dotnet-sdk` nunca é apagada apenas porque seu nome corresponde à convenção da automação. Se ela já existir, o workflow exige provenance válida do Pull Request antes de tratá-la como controlada pela automação; uma branch órfã ou criada manualmente permanece intacta e é reportada como erro de ownership.

A cada execução, o workflow recalcula o patch estável elegível mais recente. Se o Pull Request automation-owned estiver defasado, a mesma branch e o mesmo PR são atualizados para o novo target; um segundo PR não é criado. Se a branch já contiver o `sdk.version` alvo, nenhuma alteração é feita, mesmo que a formatação do JSON seja diferente. As versões atual e alvo precisam seguir o formato numérico estável `major.minor.patch` e permanecer no mesmo canal `major.minor` antes de qualquer mutação; metadados inválidos ou estado incompatível da branch falham de forma segura.

**Isolamento de falhas do lote:** erros de API, checkout, commit, push ou PR de um repositório público são registrados como `error` no Summary, e os demais repositórios continuam. Ao terminar, o job apresenta os erros agregados de operação, ownership e política de SDK e então falha se houver erros. Somente chamadas HTTP GET de leitura recebem retry para falha transitória de rede ou HTTP 429/500/502/503/504: no máximo três tentativas e backoff de 1s/2s. Erros HTTP 4xx (exceto 429), falhas de ownership e mutações Git/PR não são repetidos. Se o push ocorrer, mas a criação do PR falhar, a branch reservada é preservada e sinalizada para recuperação manual, sem exclusão ou reutilização não comprovada.

### Inventário central de repositórios .NET

O workflow [`dotnet-repository-inventory.yml`](.github/workflows/dotnet-repository-inventory.yml) gera um inventário consolidado, somente leitura, dos projetos .NET existentes nos repositórios acessíveis à GitHub App configurada.

O workflow usa duas trust boundaries explícitas. O job `discovery` é o único que recebe as credenciais da GitHub App; ele reduz a instalação a repositórios do owner que sejam públicos, não arquivados e não forks, transferindo apenas `repository` e `default_branch` por um artifact sanitizado com retenção de um dia. O job `inspection` baixa e valida esse artifact antes de qualquer clone, não recebe a private key da GitHub App nem token de escrita cross-repository, clona somente esses repositórios públicos e executa DotNetRepoInspector/MSBuild nessa fronteira sem privilégio. Isso continua válido mesmo com a instalação da GitHub App configurada como `All repositories`, portanto metadados de repositórios não públicos não são transferidos para o job de inspeção nem publicados por este control plane público.

Ele usa [`rodri-oliveira-dev/DotNetRepoInspector`](https://github.com/rodri-oliveira-dev/DotNetRepoInspector) como fonte de verdade para inspeção dos projetos. O código executável está fixado na versão **v1.5.2**, commit imutável `6524981f737086c1fdb370697e5d4100330f9bc3`; antes de restore/build, o workflow confirma que o checkout detached resolveu exatamente para esse SHA. A classificação é baseada em metadados MSBuild efetivos obtidos pelo Inspector, não em heurísticas Bash nem parsing direto de `.csproj`.

A versão e o SHA do Inspector são registrados no log do workflow, GitHub Actions Summary, metadados do artifact JSON e em todas as linhas do CSV. Atualizar o Inspector é uma mudança revisada do control plane: confirme a release estável desejada e seu commit no `DotNetRepoInspector`, atualize `INSPECTOR_VERSION` e `INSPECTOR_SHA` juntos em `dotnet-repository-inventory.yml` e faça a alteração por Pull Request. O check `Validate governance source` rejeita checkout mutável de `main`/`master` e qualquer SHA que não tenha 40 caracteres.

O inventário identifica estes tipos de projeto:

- `web`;
- `worker`;
- `console`;
- `library`;
- `test`;
- `unknown`.

O workflow mantém Target Framework e .NET SDK como conceitos separados. Um Target Framework como `net10.0` descreve o alvo de compilação/execução do projeto, enquanto um SDK configurado ou resolvido como `10.0.100` descreve o SDK usado pela avaliação/build tooling do repositório.

O inventário pode ser executado manualmente por `workflow_dispatch` e também roda semanalmente às quartas-feiras, às 09:30 em `America/Sao_Paulo` (12:30 UTC), sem sobrepor o agendamento de segunda-feira da sincronização de SDK. A configuração de concorrência impede execuções simultâneas do inventário.

**Timeouts e cancelamento:** o job privilegiado de descoberta tem limite de **15 minutos** e o job de inspeção sem credenciais tem limite de **120 minutos**. Dentro da inspeção, cada clone público é limitado a **120 segundos** e cada execução de Inspector/MSBuild a **300 segundos**. Os valores ficam em `REPOSITORY_CLONE_TIMEOUT_SECONDS` e `REPOSITORY_INSPECTION_TIMEOUT_SECONDS` no bloco `env` do job `inspection` (faixas permitidas: 1–600 e 1–3600 segundos), ajustáveis sem modificar a lógica de negócio. O GNU `timeout`, sem `--foreground`, envia SIGTERM ao grupo de processos e SIGKILL após **10 segundos de tolerância**, encerrando também descendentes `dotnet`/MSBuild. Um timeout local é identificado como `clone_timeout` ou `inspection_timeout` no JSON de repositórios/problemas, contado separadamente no log e no Step Summary e gera linhas fallback `inspection_timeout` para os projetos encontrados; os arquivos temporários são limpos e o processamento segue para o próximo repositório. O limite global do job é uma proteção final: se for atingido, a execução é cancelada e o inventário, Summary ou artifact podem ficar incompletos.

O log do workflow mostra a quantidade de repositórios elegíveis antes do início da inspeção e, em seguida, imprime o progresso por repositório no formato `[atual/total]`, com um status final curto para cada repositório. Falhas isoladas no nível de um repositório não interrompem a inspeção dos demais.

O GitHub Actions Summary é o relatório visual principal. Ele mostra uma tabela Markdown com uma linha por `.csproj`, incluindo repositório, caminho do projeto, tipo, Target Framework e SDK, seguida por contagens de repositórios planejados e processados, repositórios com e sem projetos .NET, total de projetos, totais por classificação e warnings/erros de inspeção. Problemas no nível de repositório também são consolidados no summary e ao final do log do workflow.

O workflow também exporta:

- `artifacts/dotnet-repository-inventory.csv`;
- `artifacts/dotnet-repository-inventory.json`.

Os dois arquivos são enviados como artifact `dotnet-repository-inventory` com `retention-days: 3`, permanecendo disponíveis para download na execução do workflow por 3 dias.

Repositórios sem arquivos `.csproj` são contabilizados e não fazem a execução falhar. Problemas de clone ou inspeção em repositórios individuais reportados são registrados como warnings/status, e o relatório consolidado continua sendo produzido. O workflow reutiliza as credenciais existentes da GitHub App, solicita apenas permissões de leitura no GitHub Actions, ignora forks e repositórios arquivados, inspeciona somente a branch padrão, remove diretórios temporários de cada repositório após a inspeção e não escreve nos repositórios analisados.

## Automação reutilizável de segurança

### Análise de secrets

O workflow [`reusable-secret-scan.yml`](.github/workflows/reusable-secret-scan.yml) fornece uma base reutilizável para análise de secrets, deliberadamente independente da linguagem da aplicação ou do sistema de build.

Ele analisa o histórico Git com o Infisical CLI e pode ser usado tanto em repositórios .NET quanto em Node.js/React, Java/JVM, Python, Go, Terraform, Kubernetes, Docker, configurações de CI/CD e outras stacks futuras.

A política de segurança é deliberadamente conservadora:

- solicita apenas `contents: read` ao GitHub Actions;
- não exige secrets do repositório e nunca compila ou executa código da aplicação;
- evita `pull_request_target` e desabilita a persistência das credenciais do checkout;
- realiza checkout do histórico Git completo para detectar credenciais commitadas além da árvore de trabalho atual;
- fixa as dependências do GitHub Actions em commit SHAs imutáveis;
- baixa uma versão fixa do Infisical CLI e valida seu checksum SHA-256 antes da execução;
- remove os valores detectados da saída do scanner;
- analisa apenas o intervalo de commits relevante do PR ou push quando esse intervalo é confiável, utilizando histórico completo como fallback;
- faz o check falhar quando encontra possíveis secrets, quando o scanner não conclui de forma confiável ou quando a cobertura por tamanho é incompleta;
- verifica o escopo Git selecionado em busca de blobs acima do limite de 20 MiB por target do scanner e falha fechado em vez de tratar um scan parcial como limpo;
- armazena apenas um relatório SARIF com valores ocultos e retenção de 3 dias;
- impede que um Pull Request enfraqueça sua própria política em `.infisical-scan.toml` ou `.infisicalignore`, usando durante o scan as versões existentes na branch base.

Falsos positivos devem ser revisados individualmente antes da inclusão de fingerprints ou exclusões. Uma credencial real deve primeiro ser revogada ou rotacionada; adicionar uma regra de ignore não é uma correção válida para um secret exposto.

Este repositório aplica a mesma política a si próprio por meio de [`control-plane-secret-scan.yml`](.github/workflows/control-plane-secret-scan.yml). O caller fixa o scanner reutilizável em um commit SHA imutável e revisado, executa em todo Pull Request sem filtros de path, em pushes para `main`, semanalmente e sob demanda. Seu check deve ser configurado como status check obrigatório do ruleset `main-hardened`, fazendo findings ou falhas da ferramenta bloquearem o merge enquanto Pull Requests limpos recebem uma conclusão determinística de sucesso.

Os repositórios podem adotar essa política através de um pequeno caller workflow que referencia este workflow reutilizável por `workflow_call`. Consulte [`docs/secret-scanning.pt-BR.md`](docs/secret-scanning.pt-BR.md) para exemplos de adoção, cenários suportados, tratamento de falsos positivos e orientações de resposta a incidentes.

## Governança de agentes

O diretório [`agent-governance/`](agent-governance/) é o registry canônico de instruções reutilizáveis de agentes e skills do Codex. O perfil inicial `dotnet-library` mantém a policy persistente do `AGENTS.md` compacta e move procedimentos específicos de tarefa para nove skills versionadas.

Nem GitHub nem Codex herdam implicitamente esses arquivos a partir do repositório especial `.github`. Os repositórios consumidores mantêm autoridade local e fazem opt-in ao armazenar os arquivos correspondentes em sua própria árvore.

### Sincronização das skills upstream

Quatro skills .NET são atualmente mantidas na origem por [`rodri-oliveira-dev/dotnet-library-template`](https://github.com/rodri-oliveira-dev/dotnet-library-template):

- `dotnet-issue-implementation`;
- `dotnet-bug-investigation`;
- `dotnet-pr-review`;
- `dotnet-security-review`.

O [`sync-agent-skills.yml`](.github/workflows/sync-agent-skills.yml) executa toda segunda-feira às 09:20 em `America/Sao_Paulo` (12:20 UTC) e também pode ser executado manualmente em `dry_run` ou apontando para outra ref de origem.

O workflow sincroniza somente esses quatro arquivos em allowlist, valida os metadados obrigatórios, compara o conteúdo byte-for-byte com o registry central e cria ou atualiza um único Pull Request na branch `chore/sync-upstream-agent-skills` quando encontra drift. Novas skills da origem não são importadas implicitamente e esse Pull Request nunca recebe auto-merge.

### Distribuição para consumidores

Depois que uma atualização de skill gerenciada é revisada e mergeada na `.github/main`, o [`distribute-agent-skills.yml`](.github/workflows/distribute-agent-skills.yml) executa automaticamente porque o gatilho de `push` contempla `agent-governance/manifest.json` e `agent-governance/skills/**`. Esse gatilho mais amplo não aumenta o conjunto distribuído: somente as skills marcadas como `pull-request-existing` no manifesto validado são elegíveis.

O distribuidor varre repositórios públicos visíveis para a GitHub App configurada e verifica se cada projeto já possui alguma skill gerenciada em `.agents/skills/<skill>/SKILL.md`. Os arquivos existentes são comparados byte-for-byte com a versão central aprovada.

Quando existe drift, o workflow cria ou atualiza uma única branch `chore/sync-agent-governance` e abre um Pull Request por repositório afetado, mesmo quando várias skills mudaram ao mesmo tempo. Ele não instala skills ausentes, não altera `AGENTS.md`, não faz auto-merge e não toca arquivos específicos do projeto fora dos quatro caminhos gerenciados.

Como este control plane é público, repositórios não públicos são ignorados sem expor seus nomes ou metadados na saída pública do workflow. Execuções manuais começam com `dry_run: true`, permitindo inspecionar a distribuição sem escrever nos repositórios consumidores.

A distribuição também isola erros por repositório público: falhas de leitura, clone, checkout, commit, push e criação/atualização de PR são registradas sem impedir os próximos consumidores. O Summary apresenta um status explícito `success`/`current`/`skipped`/`error` para cada repositório público avaliado e agrega o número de erros ao final. Somente requisições GET de leitura recebem retry transitório limitado; mutações nunca são repetidas sem proteção. A sincronização de skills upstream possui apenas o registry central como alvo, portanto uma falha nesse fluxo continua sendo falha do job, não de um lote de consumidores.

A cadeia resultante é deliberadamente controlada por revisão:

```text
dotnet-library-template
        |
        | sincronização semanal da origem
        v
registry agent-governance do .github
        |
        | validação + PR revisado + merge
        v
.github/main
        |
        | distribuição das skills gerenciadas
        v
repositórios consumidores
        |
        | CI do projeto + revisão humana
        v
decisão de merge
```

O [`agent-governance-validation.yml`](.github/workflows/agent-governance-validation.yml) valida o registry e os contratos dos dois workflows de sincronização para manter explícitos a allowlist, os mappings, os limites de revisão e a ausência de auto-merge.

O job `Validate governance source` executa em todo Pull Request. O ruleset ativo `main-hardened` da `main` exige esse check específico do GitHub Actions; o workflow sozinho não impõe a proteção de merge. Filtros de path em Pull Requests são deliberadamente evitados para que o required check seja criado mesmo quando a alteração não toca arquivos de agent governance.

Consulte [`docs/agent-governance.pt-BR.md`](docs/agent-governance.pt-BR.md) para o modelo de composição, regras de versionamento, fluxo de sincronização/distribuição e limites de enforcement.

## Estrutura do repositório

```text
.
├── .gitattributes
├── .github/
│   ├── FUNDING.yml
│   └── workflows/
│       ├── agent-governance-validation.yml
│       ├── distribute-agent-skills.yml
│       ├── dotnet-repository-inventory.yml
│       ├── dotnet-sdk-sync.yml
│       ├── reusable-secret-scan.yml
│       └── sync-agent-skills.yml
├── .github.code-workspace
├── .gitignore
├── agent-governance/
│   ├── VERSION
│   ├── base/
│   ├── profiles/
│   └── skills/
├── docs/
│   ├── agent-governance.md
│   ├── agent-governance.pt-BR.md
│   ├── secret-scanning.md
│   └── secret-scanning.pt-BR.md
├── CONTRIBUTING.md
├── SECURITY.md
├── README.md
└── README.pt-BR.md
```

## Princípios de governança

Este repositório segue alguns princípios simples:

- **padrões compartilhados, autoridade local** — configurações específicas do repositório têm prioridade;
- **menor privilégio** — automações entre repositórios usam uma GitHub App com permissões restritas;
- **revisão antes da alteração** — automações de manutenção e de governança de agentes abrem Pull Requests em vez de fazer merge direto;
- **padrões seguros** — a automação de versões não realiza migrações implícitas de major/minor e a distribuição manual de agentes inicia em dry-run;
- **defesa em profundidade** — checks reutilizáveis de segurança complementam controles específicos de cada repositório e os recursos de segurança nativos do GitHub;
- **automação observável** — os resultados dos workflows são registrados nos logs, summaries e artifacts de curta duração quando dados estruturados são úteis;
- **orientação por agentes, enforcement determinístico** — `AGENTS.md` e skills orientam agentes enquanto CI, analyzers, scanners e quality gates decidem o que é aceitável.

## Contribuição

Antes de enviar uma alteração, consulte [`CONTRIBUTING.md`](CONTRIBUTING.md).

Mudanças nos padrões compartilhados devem ser amplamente aplicáveis. Comportamentos específicos de um projeto normalmente devem permanecer no próprio repositório de destino.

## Segurança

Para reporte de vulnerabilidades e expectativas de divulgação, consulte [`SECURITY.md`](SECURITY.md).

Não reporte vulnerabilidades sensíveis por meio de issues públicas do GitHub.

## Escopo

Esses padrões atendem principalmente aos repositórios e pacotes open source que mantenho, com ênfase especial no ecossistema .NET.

Cada repositório pode definir requisitos adicionais de arquitetura, CI/CD, testes, empacotamento, compatibilidade, release, operação ou governança de agentes.