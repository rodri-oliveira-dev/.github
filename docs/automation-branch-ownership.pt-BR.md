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
- o Pull Request foi criado por uma identidade de automação do GitHub;
- o body do Pull Request contém o marker específico da automação (salvo a exceção legada descrita abaixo);
- automações com título fixo mantêm o título esperado do Pull Request;
- todos os arquivos do Pull Request pertencem ao conjunto de paths gerenciados pela automação;
- o SHA do head do Pull Request é exatamente o SHA atualmente resolvido pela branch remota.

PRs legados abertos, criados antes da adoção do marker, podem ser aceitos sem ele apenas se a identidade bot, o repositório, as branches de origem/destino, o SHA, o título esperado e **todos** os arquivos alterados dentro dos paths explicitamente gerenciados comprovarem a mesma automação. O nome da branch ou o autor do commit, isoladamente, não são suficientes.

Se a branch e o Pull Request correspondente estiverem ambos ausentes, a branch pode ser criada. Os pushes usam uma expectativa vazia explícita em `--force-with-lease`, de forma que uma branch criada por outro ator depois da verificação faz o push falhar em vez de reutilizar essa branch.

Nos workflows de agent skills baseados em Git, uma branch comprovadamente controlada pela automação é atualizada passando o SHA remoto capturado explicitamente para `--force-with-lease`. Assim, qualquer push concorrente após a validação de provenance faz o push da automação ser rejeitado.

A distribuição da configuração do CodeRabbit segue o mesmo contrato de exact-head baseado em Git. Ela valida a provenance da branch reservada e do Pull Request, faz checkout do head capturado e envia a alteração com `--force-with-lease`. Uma nova branch reservada só é criada com lease vazio explícito, portanto uma branch criada concorrentemente nunca é reutilizada silenciosamente.

A sincronização do SDK aplica o mesmo princípio de exact-head por meio de um checkout temporário do repositório alvo. O workflow busca a branch reservada, confirma que o head obtido ainda é exatamente o SHA comprovado, cria o commit de atualização do SDK nesse checkout do repositório alvo e faz o push com `--force-with-lease="refs/heads/<branch>:<sha-comprovado>"`. O push só é aceito enquanto o ref remoto permanecer exatamente no SHA validado pela provenance; avanço concorrente, reset para um ancestral, exclusão ou substituição da branch são rejeitados. Um PR de automação já aberto é atualizado para um SDK mais novo sem apagar nem recriar sua branch; se a branch já propõe o SDK mais recente, ela permanece inalterada.

A política também consulta o histórico de Pull Requests fechados e mesclados. Uma branch remanescente é classificada como histórica mesclada, histórica fechada, modificada após o head registrado no PR, conflitante ou sem comprovação. Nenhuma dessas classificações autoriza a sobrescrita da branch.

## Recuperação

A sincronização do SDK, a sincronização upstream de skills e a distribuição de skills recuperam colisões mantendo a branch reservada intacta e selecionando a branch determinística `<reservada>-<automation-id>-managed`. A branch de recuperação obedece às mesmas provas de provenance e à proteção por `--force-with-lease`: para uma branch **ausente**, a expectativa de SHA é vazia (`refs/heads/<branch>:`), impedindo a criação se outro ator tiver criado a ref; para uma branch **existente e comprovada**, a lease usa o SHA remoto exato capturado na validação. Execuções posteriores reutilizam o PR aberto comprovado, sem duplicá-lo. PRs fechados intencionalmente nunca são reabertos e branches ou commits históricos não são apagados automaticamente.

Se tanto a branch preferencial quanto a de recuperação forem inseguras, o repositório aparece como bloqueio de segurança no Job Summary e nenhuma mutação é tentada. O restante do lote continua, mas o job falha ao final para que o bloqueio não seja ocultado como sucesso.

Quando um workflow reportar um bloqueio de segurança, não force a automação a atravessar a colisão.

1. Inspecione manualmente a branch reservada e qualquer Pull Request aberto.
2. Se a branch contiver trabalho humano, preserve esse trabalho em outra branch com nome diferente antes de alterar qualquer coisa.
3. Inspecione também a branch determinística de recuperação e seu Pull Request.
4. Se a execução falhou após o push e antes da criação do PR, preserve a branch e examine o diff em relação à base. Não abra um PR manualmente como atalho de recuperação: um PR aberto sem comprovação recebe o estado `unproven_open` e continua bloqueado.
5. Se a branch preferencial estiver órfã e a de recuperação não existir, mantenha a preferencial intacta: a próxima execução poderá selecionar a de recuperação. Se a branch de recuperação estiver órfã, ou ambas forem históricas, inspecione as duas e preserve eventuais alterações humanas em outra branch. Quando for necessário liberar um nome, um mantenedor poderá fechar o PR não proprietário e excluir **somente** uma branch comprovadamente restrita a alterações da automação, após inspeção. O workflow nunca exclui branches automaticamente.
6. Se a execução falhou porque a branch mudou depois da captura do SHA, inspecione o novo commit remoto. Execute novamente somente depois de confirmar que a branch continua sendo da automação; a nova execução capturará o SHA atualizado.

Nunca renomeie, apague, resete ou faça force-update da branch padrão do repositório como parte da recuperação. Adicionar manualmente o marker oculto a um Pull Request não relacionado não substitui a validação do histórico e do ownership da branch.
