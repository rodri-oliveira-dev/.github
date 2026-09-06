---
name: test-anti-patterns
description: Use esta skill para auditar qualidade dos testes desta biblioteca .NET, encontrando asserts fracos, ausência de asserts, flakiness, over-mocking, acoplamento à implementação, dependência de ordem e cobertura artificial. Não use para migrar framework de testes ou escrever uma suite inteira do zero.
license: MIT
---

# Objetivo

Aumentar a confiança, o diagnóstico e a manutenibilidade dos testes automatizados sem confundir quantidade de testes com qualidade.

# Anti-patterns críticos

- teste sem assert significativo;
- assert tautológico;
- coverage touching sem verificação de comportamento;
- assert fraco demais para o contrato real;
- over-mocking que valida configuração de mocks em vez de comportamento;
- acoplamento a detalhes privados de implementação;
- flakiness por sleeps, horário real, ordem, estado global ou recursos externos;
- dados mágicos sem intenção clara.

# Processo

1. Identifique o comportamento que o teste deveria proteger.
2. Leia o código de produção relacionado quando necessário.
3. Classifique achados por severidade e risco de falso positivo/falso negativo.
4. Separe problema de teste de problema de design no código de produção.
5. Sugira o menor ajuste seguro para cada achado.
6. Combine com `coverage-analysis` quando o problema também envolver gaps de cobertura.
7. Execute a suite afetada e, ao final, a baseline definida em `AGENTS.md` quando houver alteração.

# Restrições específicas

- Não altere testes apenas para fazê-los passar.
- Não remova asserts ou cenários para reduzir flakiness sem corrigir a causa.
- Não torne código de produção público apenas para testar.
- Não introduza sleeps arbitrários.
- Não crie dependência de ordem entre testes.
- Não adicione infraestrutura externa quando um teste determinístico mais simples cobrir o risco.

As demais restrições e validações globais são definidas em `AGENTS.md`.

# Critério de qualidade

Um teste bom deixa claro qual comportamento protege, prepara dados intencionais, executa uma ação observável e verifica o resultado ou efeito com asserts relevantes.
