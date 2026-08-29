# Contributing

Thank you for considering contributing to one of my open-source projects.

This document defines the default contribution guidelines for repositories maintained under the `rodri-oliveira-dev` account. Repository-specific instructions, when present, take precedence over this document.

## English

### Before you start

Before opening a Pull Request:

1. Check the existing issues and Pull Requests to avoid duplicate work.
2. For larger changes, architectural changes, or new features, open an issue first so the proposal can be discussed.
3. Keep each contribution focused on a single concern whenever possible.

### Reporting bugs

When reporting a bug, include enough information to make the problem reproducible:

- A clear description of the problem.
- Expected behavior.
- Actual behavior.
- Steps to reproduce.
- Relevant environment information, such as operating system, runtime, framework, database, or package version.
- Logs, stack traces, screenshots, or minimal reproduction code when useful.

Please do not use public issues to report security vulnerabilities. See [SECURITY.md](SECURITY.md).

### Suggesting features

Feature requests are welcome.

Please explain:

- The problem or use case you are trying to address.
- Why the change would be useful.
- Any alternatives you considered.
- Potential compatibility or breaking-change concerns, when applicable.

### Development workflow

1. Fork the repository.
2. Create a branch from the repository's default branch.
3. Make your changes.
4. Add or update tests when appropriate.
5. Update documentation when behavior or public APIs change.
6. Run the project's validation commands locally when possible.
7. Open a Pull Request with a clear description of the change.

A branch name should preferably describe its purpose, for example:

```text
feat/add-postgresql-support
fix/null-parameter-handling
docs/improve-readme
```

### .NET repositories

For .NET projects, the usual local validation flow is:

```bash
dotnet restore
dotnet build --configuration Release
dotnet test --configuration Release
```

Some repositories may define additional validation, integration tests, formatting rules, package validation, analyzers, or CI requirements. Always check the repository's README and workflow files.

### Code quality

Contributions should:

- Follow the existing code style and architecture.
- Prefer clear and maintainable code over unnecessary complexity.
- Avoid unrelated refactoring in the same Pull Request.
- Preserve backward compatibility unless a breaking change is intentional and clearly documented.
- Include appropriate automated tests for fixes and new behavior.
- Avoid introducing new compiler, analyzer, or security warnings.

### Commits

Keep commit messages concise and descriptive.

Conventional Commit-style messages are encouraged, for example:

```text
feat: add PostgreSQL typed parameters
fix: handle null values correctly
docs: improve package documentation
test: add integration coverage
ci: update release workflow
```

### Pull Requests

A good Pull Request should explain:

- What changed.
- Why the change is needed.
- How it was validated.
- Whether it introduces a breaking change.
- Which issue it resolves, when applicable.

Prefer small and focused Pull Requests. Large changes are easier to review when divided into logical increments.

### Reviews

Review feedback is part of the contribution process.

Please address requested changes or explain the reasoning behind a different approach. Technical disagreement is welcome when it remains constructive and focused on the code, design, or requirements.

### Licensing

By contributing, you agree that your contribution will be licensed under the same license that applies to the repository.

---

## Português

Obrigado por considerar contribuir com um dos meus projetos open source.

Este documento define as orientações padrão de contribuição para os repositórios mantidos na conta `rodri-oliveira-dev`. Quando um repositório possuir instruções específicas, elas têm prioridade sobre este documento.

### Antes de começar

Antes de abrir um Pull Request:

1. Verifique as issues e Pull Requests existentes para evitar trabalho duplicado.
2. Para alterações maiores, mudanças arquiteturais ou novas funcionalidades, abra primeiro uma issue para que a proposta possa ser discutida.
3. Sempre que possível, mantenha cada contribuição focada em um único objetivo.

### Reportando bugs

Ao reportar um bug, forneça informações suficientes para que o problema possa ser reproduzido:

- Uma descrição clara do problema.
- Comportamento esperado.
- Comportamento atual.
- Passos para reprodução.
- Informações relevantes do ambiente, como sistema operacional, runtime, framework, banco de dados ou versão do pacote.
- Logs, stack traces, screenshots ou um exemplo mínimo reproduzível quando forem úteis.

Não utilize issues públicas para reportar vulnerabilidades de segurança. Consulte [SECURITY.md](SECURITY.md).

### Sugerindo funcionalidades

Sugestões de novas funcionalidades são bem-vindas.

Procure explicar:

- O problema ou caso de uso que deseja resolver.
- Por que a alteração seria útil.
- Alternativas que foram consideradas.
- Possíveis impactos de compatibilidade ou breaking changes, quando aplicável.

### Fluxo de desenvolvimento

1. Faça um fork do repositório.
2. Crie uma branch a partir da branch padrão do projeto.
3. Implemente suas alterações.
4. Adicione ou atualize testes quando apropriado.
5. Atualize a documentação quando houver mudança de comportamento ou de APIs públicas.
6. Execute localmente as validações do projeto sempre que possível.
7. Abra um Pull Request descrevendo claramente a alteração.

O nome da branch deve, preferencialmente, indicar seu propósito, por exemplo:

```text
feat/add-postgresql-support
fix/null-parameter-handling
docs/improve-readme
```

### Repositórios .NET

Em projetos .NET, o fluxo local de validação normalmente inclui:

```bash
dotnet restore
dotnet build --configuration Release
dotnet test --configuration Release
```

Alguns repositórios podem possuir validações adicionais, testes de integração, regras de formatação, validação de pacotes, analyzers ou requisitos específicos de CI. Consulte sempre o README e os workflows do projeto.

### Qualidade de código

As contribuições devem:

- Respeitar o estilo de código e a arquitetura existentes.
- Priorizar código claro e de fácil manutenção em vez de complexidade desnecessária.
- Evitar refatorações não relacionadas ao objetivo do Pull Request.
- Preservar compatibilidade retroativa, exceto quando um breaking change for intencional e estiver claramente documentado.
- Incluir testes automatizados adequados para correções e novos comportamentos.
- Evitar introduzir novos warnings de compilação, analyzers ou segurança.

### Commits

Mantenha as mensagens de commit objetivas e descritivas.

Mensagens no estilo Conventional Commits são recomendadas, por exemplo:

```text
feat: add PostgreSQL typed parameters
fix: handle null values correctly
docs: improve package documentation
test: add integration coverage
ci: update release workflow
```

### Pull Requests

Um bom Pull Request deve explicar:

- O que foi alterado.
- Por que a alteração é necessária.
- Como ela foi validada.
- Se existe algum breaking change.
- Qual issue é resolvida, quando aplicável.

Dê preferência a Pull Requests pequenos e focados. Alterações grandes são mais fáceis de revisar quando divididas em incrementos lógicos.

### Revisões

Feedback durante o code review faz parte do processo de contribuição.

Atenda às alterações solicitadas ou explique tecnicamente o motivo de uma abordagem diferente. Divergências técnicas são bem-vindas quando permanecem construtivas e focadas no código, design ou requisitos.

### Licenciamento

Ao contribuir, você concorda que sua contribuição será licenciada sob a mesma licença aplicável ao repositório.
