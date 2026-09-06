---
name: coverage-analysis
description: Use esta skill para analisar cobertura de testes desta biblioteca .NET, identificar gaps relevantes e priorizar testes por risco. Não use para inflar percentual, reduzir qualidade de asserts ou instalar ferramentas sem necessidade concreta.
license: MIT
---

# Objetivo

Usar cobertura como sinal de risco, não como objetivo isolado. A análise deve priorizar comportamento público, complexidade, frequência de mudança e impacto de regressão.

# Regras obrigatórias

- Não altere testes apenas para aumentar percentual.
- Não aceite teste sem assert significativo como melhoria real de cobertura.
- Não reduza threshold ou validação para contornar falha sem instrução explícita.
- Não adicione pacote ou ferramenta sem consumidor real.
- Não substitua análise de risco por ranking puramente numérico.
- Considere API pública, branches, tratamento de erro, invariantes e caminhos de compatibilidade.

# Processo

1. Leia `AGENTS.md` e identifique o comportamento que deveria estar protegido.
2. Execute ou utilize o relatório de cobertura existente.
3. Relacione gaps de cobertura ao código de produção correspondente.
4. Classifique por risco: alto para API pública, regras, branches complexos, validações, erros e compatibilidade; médio para transformação/coordenação observável; baixo para boilerplate, glue code trivial, configuração declarativa ou código gerado.
5. Diferencie ausência de cobertura de cobertura superficial.
6. Sugira testes por comportamento e cenário, não por linha isolada.
7. Se houver mudança de teste, valide a suite completa e a baseline definida em `AGENTS.md`.

# Saída esperada

- Hotspots priorizados por risco.
- Explicação do comportamento não protegido.
- Separação entre gap aceitável e gap perigoso.
- Cenários de teste recomendados com motivo.
- Validações executadas ou bloqueios encontrados.

# Critério de qualidade

O resultado é bom quando reduz risco real de regressão e melhora a confiança nos comportamentos relevantes, mesmo que o percentual global mude pouco.
