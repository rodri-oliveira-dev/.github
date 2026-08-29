# .github

Shared community health files and contribution guidelines for repositories maintained under the `rodri-oliveira-dev` account.

This repository centralizes default documentation and community standards that can be inherited by public repositories when they do not provide their own repository-specific version.

## English

### Purpose

The goal of this repository is to keep contribution, security, and community guidelines consistent across my open-source projects while avoiding unnecessary duplication.

Repository-specific files always take precedence when a project requires different rules or workflows.

### Current files

- [CONTRIBUTING.md](CONTRIBUTING.md) — default contribution guidelines, development workflow, Pull Request expectations, code-quality principles, and .NET validation guidance.
- [SECURITY.md](SECURITY.md) — default security policy, responsible vulnerability reporting, disclosure expectations, and scope.
- [.github/FUNDING.yml](.github/FUNDING.yml) — GitHub Sponsors configuration.

### How GitHub uses this repository

GitHub supports default community health files through a public repository named `.github`.

When one of my public repositories does not contain its own supported community health file, GitHub can use the corresponding default file from this repository.

This makes it possible to maintain a consistent baseline while still allowing each project to define its own requirements when necessary.

### Repository-specific rules

The contents of this repository are intended as defaults.

If another repository contains its own version of a supported file, that local version should be considered authoritative for that project.

For example, a repository may define its own:

- contribution workflow;
- security support policy;
- issue templates;
- Pull Request template;
- support policy;
- code of conduct.

### Open-source projects

These defaults are intended to support the repositories and packages I maintain, especially projects in the .NET ecosystem.

Each repository may still define additional build, testing, package, architecture, CI/CD, compatibility, or release requirements.

Always review the target repository's README, contribution instructions, and workflows before submitting a change.

---

## Português

Arquivos compartilhados de comunidade, segurança e contribuição para os repositórios mantidos na conta `rodri-oliveira-dev`.

Este repositório centraliza documentação e padrões que podem ser utilizados como configuração padrão pelos meus repositórios públicos quando eles não possuem uma versão específica própria.

### Objetivo

O objetivo deste repositório é manter as orientações de contribuição, segurança e comunidade consistentes entre meus projetos open source, evitando a duplicação desnecessária dos mesmos arquivos em diversos repositórios.

Quando um projeto precisar de regras ou fluxos diferentes, os arquivos específicos daquele repositório terão prioridade.

### Arquivos atuais

- [CONTRIBUTING.md](CONTRIBUTING.md) — orientações padrão para contribuição, fluxo de desenvolvimento, expectativas para Pull Requests, princípios de qualidade de código e validações comuns em projetos .NET.
- [SECURITY.md](SECURITY.md) — política padrão de segurança, reporte responsável de vulnerabilidades, expectativas de divulgação e escopo.
- [.github/FUNDING.yml](.github/FUNDING.yml) — configuração do GitHub Sponsors.

### Como o GitHub utiliza este repositório

O GitHub permite definir arquivos padrão de comunidade através de um repositório público chamado `.github`.

Quando um dos meus repositórios públicos não possuir seu próprio arquivo de comunidade suportado, o GitHub poderá utilizar o arquivo correspondente definido aqui.

Isso permite manter uma base consistente entre os projetos sem impedir que cada repositório possua regras próprias quando necessário.

### Regras específicas de cada repositório

O conteúdo deste repositório deve ser tratado como padrão.

Caso outro repositório possua sua própria versão de um arquivo suportado, a versão local deverá ser considerada a referência para aquele projeto.

Por exemplo, um repositório poderá definir seus próprios:

- fluxo de contribuição;
- política de suporte de segurança;
- templates de issues;
- template de Pull Request;
- política de suporte;
- código de conduta.

### Projetos open source

Esses padrões foram definidos para apoiar os repositórios e pacotes que mantenho, especialmente projetos do ecossistema .NET.

Cada repositório ainda poderá possuir requisitos adicionais relacionados a build, testes, empacotamento, arquitetura, CI/CD, compatibilidade ou releases.

Antes de contribuir, consulte sempre o README, as instruções de contribuição e os workflows do repositório de destino.
