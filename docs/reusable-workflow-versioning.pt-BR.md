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

Alterar `VERSION` exige Pull Request, mas a publicação é
intencionalmente **manual e explícita**. Depois que a versão revisada chega à
`main`, o mantenedor executa
[Publish reusable workflow release](../.github/workflows/reusable-workflow-release.yml)
por `workflow_dispatch` e informa o mesmo valor `vMAJOR.MINOR.PATCH`.
O workflow nunca executa em `pull_request`, `pull_request_target`, `push`
ou `schedule`, portanto o merge de um bump de versão não obtém automaticamente
`contents: write`.

O job manual confirma que a versão solicitada é exatamente a declarada em
`.github/reusable-workflows/VERSION`, valida repositório, ref `main` e SHA
completo de 40 caracteres, cria a tag imutável e a GitHub Release e promove o
alias da major correspondente. Ele recusa redirecionar tags existentes,
rejeita regressão SemVer dentro da major e impede apontar o alias major para
um commit que não descenda da versão anterior. Reexecutar a mesma versão
enquanto a `main` ainda aponta para o mesmo commit é idempotente. Se houver
falha parcial, faça o retry antes de avançar a `main`; as verificações de
imutabilidade falham de forma fechada em vez de mover silenciosamente uma
versão publicada.

Para uma versão compatível, incremente `VERSION` em PR revisado (por exemplo,
`v1.0.1`), faça merge na `main` e execute explicitamente o workflow de
release com essa versão; nunca mova `v1.0.0`. Mudanças incompatíveis exigem
nova major (por exemplo, `v2.0.0`) com instruções de migração, preservando a
major anterior para consumidores ainda não migrados. O alias major só muda por
esse workflow manual privilegiado, nunca por renomeação de branch ou auto-merge
de PR de dependências.

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
   `main`, execute manualmente o workflow de release com essa versão exata
   e então confira se a tag da release e o alias da major correspondente
   (por exemplo, `v2` para `v2.0.0`) apontam para o commit publicado da
   `main` e aguarde a conclusão do workflow.
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
