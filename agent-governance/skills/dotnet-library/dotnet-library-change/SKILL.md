---
name: dotnet-library-change
description: Use esta skill ao alterar código de produção, contratos públicos, configuração de projeto, dependências ou testes relacionados desta biblioteca .NET. Não use para CI/CD puro, auditoria de cobertura isolada ou refatoração sem mudança funcional.
license: MIT
---

# Objetivo

Orientar mudanças pequenas e seguras em bibliotecas .NET, preservando a baseline de build, testes, empacotamento e compatibilidade pública.

# Processo

1. Leia `AGENTS.md` e os arquivos diretamente relacionados à mudança.
2. Identifique o projeto de produção e os testes correspondentes.
3. Verifique se a mudança altera comportamento observável ou API pública.
4. Escolha o menor ajuste coerente com os padrões existentes.
5. Atualize ou adicione testes para mudanças comportamentais.
6. Para dependências, altere versões somente em `Directory.Packages.props` e regenere lock files por restore.
7. Atualize `CHANGELOG.md` se houver impacto relevante para consumidores.
8. Se a mudança afetar empacotamento ou contrato público, valide o pacote.
9. Revise o diff e remova alterações não relacionadas.
10. Execute a baseline definida em `AGENTS.md`.

# Restrições específicas

- Não adicione `Version=` em `PackageReference`.
- Não edite `packages.lock.json` manualmente.
- Não transforme membros internos em públicos apenas para facilitar testes.
- Não introduza dependência de domínio, infraestrutura ou framework sem necessidade reutilizável clara.
- Não quebre API pública de forma incidental.
- Não reduza warnings, testes, auditoria ou validações para contornar falhas.

As demais restrições e validações globais são definidas em `AGENTS.md`.

# Critério de qualidade

Uma boa mudança resolve o problema com diff limitado, preserva contratos não envolvidos, possui testes proporcionais ao risco e deixa restore, build, test e packaging coerentes com a baseline.
