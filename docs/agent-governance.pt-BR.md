# Governança de agentes

O diretório `agent-governance/` é a fonte canônica de autoria para instruções e skills reutilizáveis de agentes de IA compartilhadas entre os repositórios mantidos em `rodri-oliveira-dev`.

## Importante: não existe herança implícita

O repositório especial `.github` do GitHub não faz com que `AGENTS.md` ou `.agents/skills` fiquem automaticamente disponíveis ao Codex nos outros repositórios. Um consumidor precisa copiar/materializar o perfil selecionado em sua própria árvore.

Portanto, isto é um **control plane de autoria, versionamento, validação e distribuição revisada**, não um mecanismo oculto de herança em runtime.

## Camadas

### Política base

`agent-governance/base/AGENTS.base.md` contém regras compactas e reutilizáveis sobre:

- gerenciamento de contexto;
- roteamento/delegação;
- diffs mínimos;
- validação determinística;
- comportamento seguro de entrega.

A base permanece deliberadamente pequena porque instruções persistentes consomem contexto em todas as tarefas.

### Perfis

Um perfil transforma os princípios compartilhados em um contrato pronto para uso em um tipo de repositório.

O primeiro perfil é `dotnet-library`:

```text
agent-governance/profiles/dotnet-library/
├── AGENTS.md
└── profile.yml
```

`AGENTS.md` é o arquivo distribuível de instruções. `profile.yml` declara a versão canônica da governança e as skills que devem ser materializadas em `.agents/skills/` no repositório consumidor.

### Skills

Skills mantêm procedimentos específicos de tarefa fora do contexto persistente do `AGENTS.md`.

O catálogo inicial é separado entre skills reutilizáveis de .NET e skills específicas de bibliotecas. A versão de governança `1.0.0` inclui nove skills.

Quatro skills são espelhadas byte-for-byte a partir de `rodri-oliveira-dev/dotnet-library-template` pelo workflow `.github/workflows/sync-agent-skills.yml`:

- `dotnet-issue-implementation`;
- `dotnet-bug-investigation`;
- `dotnet-pr-review`;
- `dotnet-security-review`.

## Versionamento

A versão do contrato fica em `agent-governance/VERSION` e segue versionamento semântico.

Atualizações de governança devem ser tratadas como atualizações de dependência: revisar o diff, entender mudança de comportamento, executar validações e fazer merge de forma intencional.

Não faça auto-merge de mudanças de governança.

## Fluxo de atualização de consumidores

O caminho automatizado para as quatro skills gerenciadas é:

```text
dotnet-library-template
        |
        | PR semanal de sincronização
        v
.github/agent-governance
        |
        | revisão + validação + merge
        v
distribute-agent-skills.yml
        |
        +--> PR no repositório consumidor
        +--> PR no repositório consumidor
        +--> repositório já atualizado
```

`.github/workflows/distribute-agent-skills.yml` roda depois que uma skill canônica gerenciada muda na `main` e também pode ser executado manualmente em modo `dry_run`.

O workflow percorre os repositórios públicos visíveis para a GitHub App configurada. Um consumidor participa apenas das skills gerenciadas que já existem em `.agents/skills/<skill>/SKILL.md`. Skills ausentes não são instaladas automaticamente.

Quando existe drift, o arquivo canônico substitui byte-for-byte a cópia do consumidor na branch controlada pela automação `chore/sync-agent-governance`. Um único Pull Request revisável é criado ou atualizado por repositório, independentemente de quantas skills tenham mudado. Auto-merge continua desabilitado.

Como o repositório de controle `.github` é público, repositórios não públicos são ignorados para evitar exposição de nomes ou metadados em logs e summaries públicos do workflow.

A sincronização do perfil completo e do `AGENTS.md` continua manual nesta etapa.

## Autoridade local

Um perfil compartilhado é uma baseline, não substitui o conhecimento específico do projeto. Repositórios consumidores podem estender ou sobrescrever regras de arquitetura, domínio, comandos de build/teste, release, segurança, compatibilidade e skills locais.

A árvore real e o contrato local do repositório continuam sendo a fonte de verdade. Para as skills gerenciadas automaticamente, divergências locais são apresentadas como Pull Request em vez de serem sobrescritas diretamente na branch padrão.

## Modelo de enforcement

Instruções de agente são soft policy. A automação determinística continua sendo a camada de enforcement:

```text
AGENTS.md / skills
      |
      v
implementação orientada
      |
      v
build / testes / analyzers / scanners / quality gates
      |
      v
decisão de merge
```

A governança centralizada nunca deve ser usada como justificativa para remover ou contornar CI, CodeQL, Dependency Review, secret scanning, validação de pacotes ou outros controles específicos do repositório.

## Validação

`.github/workflows/agent-governance-validation.yml` valida a versão canônica, arquivos obrigatórios do perfil, frontmatter das skills, nomes duplicados, referências do perfil, regras essenciais de contexto/validação e os contratos dos workflows de sincronização upstream e distribuição.
