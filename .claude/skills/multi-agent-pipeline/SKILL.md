---
name: multi-agent-pipeline
description: Use when a spec or feature in this repo is ready to size, break into tasks, and implement via the coder/reviewer/tester agent trio — before writing any code for a new spec-driven task.
---

# Multi-Agent Pipeline

## Overview

Orquestra os três agents do projeto (`coder`, `reviewer`, `tester`) em torno de
uma spec: primeiro discutem e dimensionam a tarefa juntos, depois executam em
loop por subtarefa.

## Quando usar

- Usuário aponta pra uma spec (`docs/superpowers/specs/*.md`) ou feature e
  pede "implementa isso".
- Tarefa não trivial (toca API + Flutter, ou tem vários critérios de
  aceite) — se compensa dimensionar antes de codar.

Pular pra fix de uma linha ou typo — edita direto, sem pipeline.

## Fase 1 — Discussão e sizing

Não é dispara-os-três-e-pronto: reviewer precisa do que o coder propõe antes
de opinar. Ordem:

1. **coder** e **tester** em paralelo (tool Agent, `run_in_background: false`
   em cada um), ambos só com o caminho da spec:
   - **coder**: lê a spec e propõe abordagem de implementação — complexidade
     técnica, design patterns/abordagem TDD a aplicar, riscos.
   - **tester**: lê só a spec, aponta dúvidas sobre comportamento esperado
     (critério de aceite ambíguo, edge case não coberto, regra 10) — sem
     testabilidade de código ainda, porque não existe implementação proposta
     pra testar.

2. **reviewer**, depois dos dois acima, recebe spec + proposta do coder
   (não só a spec) e já aponta ajustes nessa fase — sobre-engenharia,
   duplicação, segurança (regra 8) — na abordagem proposta, antes de uma
   linha de código existir.

Depois de coletar as três respostas, sintetiza (main thread) num resumo
único com:

1. Tamanho estimado (P/M/G) com justificativa.
2. Metodologia/design patterns acordados entre os três.
3. Divisão em tarefas TDD — menor fatia possível por ciclo.

Apresenta esse resumo ao usuário e para — espera "ok"/"pode implementar"
antes da Fase 2.

## Fase 2 — Execução (loop por tarefa)

Pra cada tarefa da divisão, em ordem:

1. **coder** implementa (ciclo red-green-refactor) → devolve diff.
2. **reviewer** revisa o diff:
   - Sem achados → segue pro tester.
   - Achado "small fix" (nit, sem ambiguidade) → coder aplica direto, sem
     novo round de discussão.
   - Achado maior/ambíguo → volta pro coder como issue, revisão se repete
     no novo diff.
3. **tester** valida contra critérios de aceite da spec:
   - Tudo verde → tarefa concluída, segue pra próxima.
   - Bug/critério falho → reporta causa raiz (não sintoma) pro coder, volta
     ao passo 1 pra essa tarefa.

Loop até esgotar as tarefas da divisão. Reporta status final por tarefa
(concluída / bloqueada / precisa de input do usuário).

## Referência rápida

| Etapa | Quem | Pode devolver? |
|---|---|---|
| Sizing | coder+tester (paralelo) → reviewer (depois, com proposta do coder) | reviewer já aponta ajuste na proposta |
| Implementação | coder | — |
| Revisão | reviewer | sim → coder, exceto small fix |
| Teste | tester | sim → coder (causa raiz) |

## Erros comuns

- Pular Fase 1 e mandar direto pro coder — perde o sizing e a divisão que
  o usuário pediu.
- Reviewer aplicando fix: reviewer não tem Write/Edit
  (`.claude/agents/reviewer.md`), só reporta — quem edita é sempre o coder.
- Avançar pra próxima tarefa com teste vermelho ou achado de segurança em
  aberto.
