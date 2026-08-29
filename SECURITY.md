# Security Policy

Security issues should be reported responsibly and privately whenever possible.

This document defines the default security policy for repositories maintained under the `rodri-oliveira-dev` account. Repository-specific security policies, when present, take precedence over this document.

## English

### Supported versions

Unless a repository explicitly documents a different support policy, security fixes are generally targeted at the latest maintained release.

Older versions may no longer receive security updates. If you are unsure whether a version is supported, include the affected version in your report.

### Reporting a vulnerability

Please **do not open a public GitHub issue** for suspected security vulnerabilities.

When the repository supports GitHub Private Vulnerability Reporting, use:

**Security → Report a vulnerability**

This allows the vulnerability to be discussed privately with the maintainer before public disclosure.

If Private Vulnerability Reporting is not available for the affected repository, avoid publishing exploit details or sensitive information publicly. Use an appropriate private contact channel associated with the repository or maintainer.

### What to include

A useful security report should include, when applicable:

- The affected repository, package, component, or version.
- A clear description of the vulnerability.
- Steps required to reproduce the issue.
- A minimal proof of concept, if appropriate.
- The potential security impact.
- Known attack prerequisites or limitations.
- Suggested mitigations, if you have identified any.

Please avoid accessing, modifying, or deleting data that does not belong to you while investigating a vulnerability.

### Disclosure

Please allow reasonable time for the issue to be investigated and, when necessary, fixed before public disclosure.

Once a vulnerability has been validated, the maintainer may:

- Prepare and test a fix.
- Publish a patched release.
- Create a GitHub Security Advisory when appropriate.
- Request a CVE when the vulnerability qualifies for one.
- Coordinate public disclosure with the reporter.

Credit may be given to the reporter when desired and appropriate.

### Scope

Security reports are appropriate for vulnerabilities that could affect confidentiality, integrity, availability, authentication, authorization, dependency integrity, package consumers, or other meaningful security boundaries.

General bugs, feature requests, performance issues, and code-quality suggestions should be reported through the repository's normal issue tracker unless they have a concrete security impact.

---

## Português

Problemas de segurança devem ser reportados de forma responsável e privada sempre que possível.

Este documento define a política de segurança padrão para os repositórios mantidos na conta `rodri-oliveira-dev`. Quando um repositório possuir uma política de segurança específica, ela tem prioridade sobre este documento.

### Versões suportadas

A menos que o repositório documente explicitamente uma política diferente, correções de segurança são normalmente direcionadas para a versão mais recente que ainda recebe manutenção.

Versões antigas podem não receber mais atualizações de segurança. Caso tenha dúvida sobre o suporte de uma versão, informe a versão afetada no relatório.

### Reportando uma vulnerabilidade

Por favor, **não abra uma issue pública no GitHub** para reportar uma possível vulnerabilidade de segurança.

Quando o repositório possuir o GitHub Private Vulnerability Reporting habilitado, utilize:

**Security → Report a vulnerability**

Esse recurso permite que a vulnerabilidade seja discutida de forma privada com o mantenedor antes de qualquer divulgação pública.

Caso o Private Vulnerability Reporting não esteja disponível no repositório afetado, evite publicar detalhes de exploração ou informações sensíveis publicamente. Utilize um canal de contato privado apropriado associado ao repositório ou ao mantenedor.

### O que incluir

Um bom relatório de segurança deve incluir, quando aplicável:

- O repositório, pacote, componente ou versão afetada.
- Uma descrição clara da vulnerabilidade.
- Os passos necessários para reproduzir o problema.
- Uma prova de conceito mínima, quando apropriado.
- O impacto potencial de segurança.
- Pré-requisitos ou limitações conhecidas para exploração.
- Possíveis mitigações, caso tenha identificado alguma.

Durante a investigação, evite acessar, modificar ou excluir dados que não pertençam a você.

### Divulgação

Por favor, conceda um período razoável para que o problema seja investigado e, quando necessário, corrigido antes de qualquer divulgação pública.

Após a validação de uma vulnerabilidade, o mantenedor poderá:

- Preparar e testar uma correção.
- Publicar uma versão corrigida.
- Criar um GitHub Security Advisory quando apropriado.
- Solicitar um CVE quando a vulnerabilidade atender aos critérios.
- Coordenar a divulgação pública com o responsável pelo reporte.

O responsável pelo reporte poderá receber crédito pela descoberta quando desejar e quando isso for apropriado.

### Escopo

Relatórios de segurança são adequados para vulnerabilidades que possam afetar confidencialidade, integridade, disponibilidade, autenticação, autorização, integridade de dependências, consumidores de pacotes ou outras fronteiras relevantes de segurança.

Bugs comuns, solicitações de funcionalidades, problemas de performance e sugestões de qualidade de código devem ser reportados pelo fluxo normal de issues do repositório, exceto quando apresentarem um impacto concreto de segurança.
