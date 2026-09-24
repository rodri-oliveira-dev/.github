# Ownership de branches de automação

Este control plane reserva um conjunto pequeno de nomes de branch para manutenção cross-repository:

| Automação | Branch reservada | Marker de ownership |
| --- | --- | --- |
| Sincronização do .NET SDK | `chore/sync-dotnet-sdk` | `<!-- automation-branch-owner: dotnet-sdk-sync/v1 -->` |
| Sincronização de agent skills upstream | `chore/sync-upstream-agent-skills` | `<!-- automation-branch-owner: sync-upstream-agent-skills/v1 -->` |
| Distribuição de agent skills para consumidores | `chore/sync-agent-governance` | `<!-- automation-branch-owner: distribute-agent-skills/v1 -->` |
| Distribuição da configuração do CodeRabbit | `chore/sync-coderabbit-config` | `<!-- automation-branch-owner: coderabbit-config-sync/v1 -->` |

O nome reservado, isoladamente, nunca é evidência de que uma branch pertence à automação.

## Contrato de provenance

Antes de qualquer mutação automatizada de uma branch reservada existente, o workflow precisa comprovar todos os pontos abaixo:

- a branch reservada é diferente da branch padrão/base do repositório;
- existe exatamente um Pull Request aberto originado dessa branch no mesmo repositório;
- o Pull Request aponta para a branch base esperada;
- o body do Pull Request contém o marker específico da automação;
- automações com título fixo mantêm o título esperado do Pull Request;
- o SHA do head do Pull Request é exatamente o SHA atualmente resolvido pela branch remota.

Se a branch e o Pull Request correspondente estiverem ambos ausentes, a branch pode ser criada. Os pushes usam uma expectativa vazia explícita em `--force-with-lease`, de forma que uma branch criada por outro ator depois da verificação faz o push falhar em vez de reutilizar essa branch.

Nos workflows de agent skills baseados em Git, uma branch comprovadamente controlada pela automação é atualizada passando o SHA remoto capturado explicitamente para `--force-with-lease`. Assim, qualquer push concorrente após a validação de provenance faz o push da automação ser rejeitado.

A distribuição da configuração do CodeRabbit segue o mesmo contrato de exact-head baseado em Git. Ela valida a provenance da branch reservada e do Pull Request, faz checkout do head capturado e envia a alteração com `--force-with-lease`. Uma nova branch reservada só é criada com lease vazio explícito, portanto uma branch criada concorrentemente nunca é reutilizada silenciosamente.

A sincronização do SDK aplica o mesmo princípio de exact-head por meio de um checkout temporário do repositório alvo. O workflow busca a branch reservada, confirma que o head obtido ainda é exatamente o SHA comprovado, cria o commit de atualização do SDK nesse checkout do repositório alvo e faz o push com `--force-with-lease="refs/heads/<branch>:<sha-comprovado>"`. O push só é aceito enquanto o ref remoto permanecer exatamente no SHA validado pela provenance; avanço concorrente, reset para um ancestral, exclusão ou substituição da branch são rejeitados. Um PR de automação já aberto é atualizado para um SDK mais novo sem apagar nem recriar sua branch; se a branch já propõe o SDK mais recente, ela permanece inalterada.

A sincronização do SDK não apaga mais uma `chore/sync-dotnet-sdk` existente apenas porque o nome é reservado. Uma branch existente sem provenance válida permanece intacta e é reportada como erro de ownership.

## Recuperação

Quando um workflow reportar uma branch reservada órfã ou sem ownership comprovado, não force a automação a atravessar a colisão.

1. Inspecione manualmente a branch reservada e qualquer Pull Request aberto.
2. Se a branch contiver trabalho humano, preserve esse trabalho em outra branch com nome diferente antes de alterar qualquer coisa.
3. Se for uma branch antiga da automação, confirme que não há commits humanos a preservar, feche o Pull Request antigo se existir e apague manualmente a branch reservada.
4. Execute novamente a automação; com branch e Pull Request de automação ausentes, ela poderá recriar a provenance a partir de um estado limpo.
5. Se a execução falhou porque a branch mudou depois da captura do SHA, inspecione o novo commit remoto. Execute novamente somente depois de confirmar que a branch continua sendo da automação; a nova execução capturará o SHA atualizado.

Nunca renomeie, apague, resete ou faça force-update da branch padrão do repositório como parte da recuperação. Adicionar manualmente o marker oculto a um Pull Request não relacionado não substitui a validação do histórico e do ownership da branch.
