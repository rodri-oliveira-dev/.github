---
name: ci-release-governance
description: Use esta skill para revisar ou ajustar GitHub Actions, packaging, segurança de automação, versionamento e fluxo de release de uma biblioteca .NET. Não use para mudanças funcionais sem impacto no pipeline.
license: MIT
---

# Objetivo

Orientar mudanças em CI/CD, packaging, versionamento e release com segurança, rastreabilidade e aderência aos workflows que realmente existem no repositório.

# Regra principal

Antes de assumir qualquer automação, inspecione `.github/workflows/`. O estado real do repositório é a fonte de verdade para triggers, permissões, credenciais, versionamento, packaging e publicação.

# Processo

1. Leia `AGENTS.md` e liste os workflows existentes.
2. Identifique trigger, permissões, comandos, credenciais, artifacts e fonte de versão do fluxo afetado.
3. Preserve restore reproduzível, build e testes antes de packaging/publicação.
4. Use permissões mínimas e evite credenciais persistentes quando houver mecanismo temporário/OIDC suportado.
5. Preserve uma única fonte editável de versão por contexto e valide SemVer quando aplicável.
6. Garanta que falhas de build, testes, análise, pack ou verificação bloqueiem publicação/release.
7. Confirme que ações de terceiros estão pinadas de acordo com a política do repositório.
8. Revise se uma mudança pertence apenas ao template/source repository ou também deve existir no projeto gerado.
9. Atualize documentação quando o comportamento oficial do pipeline mudar.
10. Execute a baseline e validações específicas definidas em `AGENTS.md`.

# Segurança de supply chain

- Não use `write-all` por conveniência.
- Restrinja permissões de escrita aos jobs que realmente precisam delas.
- Não exponha secrets a eventos não confiáveis.
- Prefira OIDC/Trusted Publishing quando o destino suportar.
- Não permita publicação quando identidade, versão ou pacote não tiverem sido validados.
- Não enfraqueça CodeQL, Dependency Review, NuGet Audit, Sonar, secret scanning ou outros gates para acelerar release.

# Restrições específicas

- Não execute publicação, criação de tag, GitHub Release ou deploy sem solicitação explícita.
- Não mantenha duas fontes de versão independentes para o mesmo artefato.
- Não assuma que variables, secrets, environments, rulesets ou Trusted Publishing são copiados por template de repositório.
- Não amplie permissões ou retenção de artifacts sem necessidade demonstrável.

As demais restrições e validações globais são definidas em `AGENTS.md`.

# Critério de qualidade

Uma boa mudança de automação reproduz comandos suportados localmente, usa menor privilégio, mantém rastreabilidade entre commit, versão e artefato, falha de forma fechada antes de publicação e documenta somente capacidades realmente presentes no repositório.
