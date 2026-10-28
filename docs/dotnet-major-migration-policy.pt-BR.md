# Política de recomendação para migração entre versões principais do .NET

## Decisão

A automação central pode identificar e reportar repositórios que precisam de
avaliação para migrar entre versões principais do .NET. Ela não deve alterar
automaticamente canais de SDK, TFMs, pacotes, workloads, imagens de runtime ou
propriedades de publicação.

Atualizações de patch no canal `major.minor` atual continuam sendo a única
mutação realizada por `dotnet-sdk-sync.yml`. A migração principal pertence ao
repositório consumidor: sucesso de build, isoladamente, não comprova
compatibilidade comportamental, de pacotes, runtime ou implantação.

## Fontes autoritativas

As recomendações devem ser calculadas a cada execução, sem tabela de suporte
fixa no código:

- o [índice oficial de releases do .NET](https://github.com/dotnet/core/blob/main/release-notes/releases-index.json)
  fornece canal, tipo de release, fase de suporte, data de EOL e SDK mais novo;
- a [política oficial de suporte do .NET](https://dotnet.microsoft.com/platform/support/policy/dotnet-core)
  define os ciclos LTS e STS;
- o inventário sem credenciais fornece SDKs configurado e resolvido, TFMs,
  diagnósticos do Inspector e propriedades de publicação;
- os resultados de CI e testes do repositório fornecem evidência de
  compatibilidade e não são substituídos pelo inventário.

Somente canais estáveis em suporte `active` ou `maintenance` podem ser alvos.
Canais preview, release candidate e `go-live` ficam excluídos até que uma
política futura e revisada faça opt-in explícito.

Como exemplo datado, em 28/10/2026 o índice informa .NET 10 como LTS ativo,
.NET 8 e .NET 9 em manutenção com EOL em 10/11/2026 e .NET 11 como canal
pré-release `go-live`. Esse retrato é apenas explicativo; a automação sempre
deve consultar o índice corrente.

## Identificação de candidatos

Um repositório é candidato quando ao menos uma condição for observada:

1. O canal do SDK configurado na raiz está `eol` ou ausente dos metadados de
   suporte.
2. Algum TFM avaliado aponta para uma implementação .NET sem suporte.
3. Um canal suportado está dentro da janela configurável anterior ao EOL
   (proposta inicial: 90 dias).
4. SDK configurado e SDK resolvido pertencem a canais `major.minor` diferentes.
5. A inspeção está incompleta, contraditória ou contém diagnósticos de
   compatibilidade. O resultado é `needs-evidence`, nunca migração automática.

Repositórios sem `global.json` na raiz podem receber recomendação informativa,
mas a ausência de pin não basta para criar uma alteração.

## Alvo recomendado

O alvo padrão é o LTS estável e suportado mais novo que seja compatível com as
restrições verificadas. Um canal atual suportado não é obsoleto apenas porque
existe uma versão principal mais recente. STS continua sendo uma escolha
explícita válida do repositório, mas não é o alvo padrão.

A recomendação deve separar SDK e patch exato, TFMs (preservando
multi-targeting intencional), família de runtime/container observável e
pacotes ou workloads que exigem revisão manual. Ela nunca deve sugerir que
alterar somente `global.json` conclui a migração de runtime ou TFM.

## Elegibilidade e confiança

| Nível | Evidência mínima | Resultado |
| --- | --- | --- |
| `informational` | SDK/TFM em EOL ou próximo de EOL, com inventário incompleto | Apenas reportar e coletar evidências |
| `candidate` | Inventário completo, alvo estável e SDKs/TFMs conhecidos | Recomendação para triagem pelo owner |
| `ready-for-assisted-pr` | Candidato, restore/build/test verdes em branch explícita, revisão de pacotes/workloads e opt-in | Uma ferramenta futura pode preparar PR para revisão humana |

Nenhum nível autoriza merge automático. Os repositórios continuam limitados a
públicos e pertencentes ao owner configurado, conforme a política de
privacidade atual.

## Sinais de risco

A recomendação deve destacar, sem interpretar valores desconhecidos como
seguros:

- projetos multi-target e gerações de TFM misturadas;
- estados `unknown` ou `context-dependent` do Inspector;
- publicação self-contained, Native AOT, trimmed, single-file ou com versão de
  runtime fixada;
- workloads e identificadores de runtime específicos de plataforma;
- imagens Docker incompatíveis com os TFMs propostos;
- incompatibilidade de pacotes, analyzers, source generators ou targets MSBuild;
- breaking changes, serialização, globalização, hosting e restrições do ambiente;
- testes ausentes, falhas de restore/build/test ou inspeção incompleta.

O DotNetRepoInspector fornece evidências, não um veredito de vulnerabilidade ou
compatibilidade. Como a avaliação MSBuild pode executar lógica do repositório,
ela deve permanecer no job com timeout e sem chave privada da GitHub App, token
de escrita, token OIDC ou token de runtime de artifacts. O job privilegiado de
sync não deve executar MSBuild não confiável.

## Evolução proposta

1. Acrescentar ao artifact do inventário recomendações determinísticas e sem
   mutação, calculadas com os metadados atuais de releases.
2. Publicar contagens por urgência (`eol`, `eol-soon`, `needs-evidence`) no
   resumo, sem expor metadados de repositórios não públicos.
3. Criar fixtures para limites de lifecycle, janelas de data, exclusão de
   previews, TFMs mistos e estados de publicação desconhecidos.
4. Após avaliação operacional, criar issues ou draft PRs apenas por opt-in,
   com novo marcador de ownership e nova branch; não reutilizar
   `chore/sync-dotnet-sdk`.
5. Manter commits, validação, rollout e rollback sob responsabilidade de cada
   repositório. Nunca fazer auto-merge nem trocar silenciosamente a major.

