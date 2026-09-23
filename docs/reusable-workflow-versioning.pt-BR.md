# Versionamento dos workflows reutilizáveis

O control plane `.github` publica os workflows reutilizáveis sob um único
contrato revisado. A entrada pública é
[reusable-secret-scan.yml](../.github/workflows/reusable-secret-scan.yml).
O `agent-governance/VERSION` possui **contrato independente**: mudanças nos
workflows reutilizáveis não alteram silenciosamente a versão da governança de agentes.

## Política de versões e compatibilidade

- **`v1.0.0`**, `v1.0.1` e demais tags `vMAJOR.MINOR.PATCH` são
  imutáveis. O ruleset existente `release-tags-immutable` impede
  redirecionar ou excluir tags `v*.*.*`. Uma tag publicada não deve
  apontar para outro commit.
- **`v1`** é um alias de versão principal **intencionalmente mutável**:
  aponta para a release `v1.x.y` compatível e revisada mais recente.
  Consumidores em `@v1` recebem atualizações compatíveis e correções
  de segurança. Remover ou renomear inputs/outputs, alterar a expectativa
  de permissões/secrets ou quebrar comportamento documentado exige
  **`v2.0.0` e `v2`**, não uma mudança incompatível em `v1`.
- `vMAJOR.MINOR.PATCH` fixa uma *versão de release*. Para
  reprodutibilidade e isolamento máximos de supply chain, utilize o
  **SHA completo de commit** para o qual a tag aponta. Confira a
  correspondência entre tag e commit antes de copiar o SHA.
- Não recomende `@main`: cada merge comum na `main` alteraria o
  comportamento dos consumidores sem release, revisão de compatibilidade
  ou aceite explícito.

## Primeira release e promoção controlada

A versão revisada dos workflows reutilizáveis fica em
[`.github/reusable-workflows/VERSION`](../.github/reusable-workflows/VERSION).
O valor inicial é **`v1.0.0`**. Os consumidores devem aguardar a release e o
alias `v1` ficarem visíveis antes de adotar os exemplos abaixo.

A publicação é **dirigida por merge e protegida por review**: alterar
`VERSION` exige Pull Request. Somente depois que essa mudança revisada chega
à `main` o workflow
[Publish reusable workflow release](../.github/workflows/reusable-workflow-release.yml)
executa com `contents: write`. Ele nunca executa em `pull_request`. O
trigger de `push` aceita somente a `main` e somente mudanças no arquivo
`VERSION`, portanto merges comuns não publicam releases.
`workflow_dispatch` permanece disponível para retry/recuperação. Tanto a
publicação automática quanto o retry manual resolvem o target para o último
commit da `main` que alterou `VERSION`, impedindo que um merge posterior e não
relacionado mude silenciosamente o conteúdo da release.

**Pré-requisito obrigatório de proteção da branch:** o ruleset ativo
`main-hardened` deve exigir pelo menos **uma aprovação de review** para Pull
Requests e não pode ter **atores com bypass**. A publicação falha de forma
fechada se essa configuração estiver ausente ou se o PR mergeado que alterou
`VERSION` não tiver uma aprovação de pessoa diferente da autora no último
commit do PR. O ajuste deve ser aplicado nas configurações do repositório
antes do merge deste PR; versionar um arquivo não altera o ruleset ativo.

O workflow resolve a versão a partir do arquivo revisado, valida o formato
canônico `vMAJOR.MINOR.PATCH`, repositório, branch e SHA completo de 40
caracteres, cria a tag imutável e a GitHub Release e então promove o alias da
major correspondente. Ele recusa redirecionar tags existentes, rejeita
regressão SemVer dentro da major e impede apontar o alias major para um commit
que não descenda da versão anterior. Reexecutar a mesma versão no mesmo commit
é idempotente. Se a release for publicada mas a promoção do alias falhar,
corrija o problema antes de recomendar `@v1`; consumidores ainda podem usar
uma tag exata/SHA verificados.

Para uma versão compatível, incremente `VERSION` em PR revisado (por exemplo,
`v1.0.1`) e faça merge na `main`; nunca mova `v1.0.0`. Mudanças
incompatíveis exigem nova major (por exemplo, `v2.0.0`) com instruções de
migração, preservando a major anterior para consumidores ainda não migrados.
O alias major só muda por esse workflow privilegiado de release, nunca por
renomeação de branch ou auto-merge de PR de dependências.

## Exemplo de consumidor

O exemplo abaixo vale **depois que `v1` for publicada**. Ele usa
somente permissão de leitura e não depende de `pull_request_target`.

```yaml
name: Secret scan
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  secrets:
    uses: rodri-oliveira-dev/.github/.github/workflows/reusable-secret-scan.yml@v1
```

Para fixar uma versão exata de release, substitua `@v1` por
`@v1.0.0` depois da publicação inicial. Para origem estritamente
imutável, use `@<SHA completo de commit de 40 caracteres>` **com o SHA
real conferido na release aprovada**; nunca copie um placeholder
para um workflow executável.

O caller obrigatório de secret scanning do **próprio control plane**
permanece propositalmente fixado em SHA completo em vez de seguir
`@v1`: um PR não pode enfraquecer seu próprio check obrigatório
alterando o scanner reutilizável. Toda atualização do SHA do caller
exige PR revisado e aprovação dos testes de governança existentes.

## Atualização, reversão e verificações

1. Revise as notas de release e possíveis mudanças de inputs/outputs,
   runtime, secrets ou permissões. Incremente
   `.github/reusable-workflows/VERSION` em PR revisado, faça merge na
   `main`, confira se a tag da release e o alias da major correspondente
   (por exemplo, `v2` para `v2.0.0`) apontam para esse commit aprovado e
   aguarde a conclusão do workflow.
2. O consumidor em `@v1` acompanha promoções compatíveis
   automaticamente; consumidores em `@v1.0.0` ou SHA devem atualizar
   o caller explicitamente em PR revisado e executar secret scanning
   e CI específica do repositório.
3. Para reverter um consumidor, altere o caller em PR revisado para a
   tag de patch exata previamente validada ou para seu SHA. **Não
   reescreva uma tag de release imutável** para reverter. Em caso de
   incidente com o alias, suspenda promoções e publique um patch
   corretivo compatível após revisão; não introduza mudança incompatível
   silenciosamente na mesma major.
4. Confirme que a [release](https://github.com/rodri-oliveira-dev/.github/releases)
   existe, que sua tag aponta para o commit revisado e que o workflow
   reutilizável executa corretamente pelo ref publicado. Até essa
   verificação, a publicação permanece uma etapa operacional pendente
   da issue #24.
