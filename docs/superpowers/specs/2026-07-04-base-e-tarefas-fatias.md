# Life Organizer — Fatias de implementação: Base (auth) + Tarefas/Projetos

Data: 2026-07-04
Deriva de: `2026-07-04-base-e-tarefas-design.md`

Cada fatia = ciclo TDD completo (request spec vermelho → implementação →
refactor → suíte 100% verde). Uma fatia por vez, checkpoint de revisão entre
fatias, commit só após aprovação reviewer + tester.

## Decisões já tomadas (valem pras fatias seguintes)

- Rate limiting: `rate_limit` **nativo do Rails 8** por IP — substitui
  rack-attack do design (zero gem nova). Test env usa `memory_store` +
  `Rails.cache.clear` before each.
- Enum como strings no banco (`role: "owner"`), não ints — legível em
  banco/logs sem mapa mental.
- Efeitos colaterais de criação (Inbox no signup) orquestrados em transação
  explícita no controller — nunca callback escondido no model.
- Erros: 422 `{errors: [...]}` validação, 400 JSON pra ParameterMissing,
  500 JSON genérico pra falha de sistema (rescue_from RecordInvalid +
  logger.error, detalhe só no log), 429 JSON rate limit. Nunca HTML/stack
  trace pro client.
- Signup retorna JWT direto (auto-login) — entra na A3 junto com o login.
- `filter_parameters` default do Rails 8 já cobre `:passw` e `:token`.

## Bloco A — Base (auth)

### A1 — Setup RSpec + POST /signup cria User ✅ (commitada)

- rspec-rails + bcrypt; User (email normalizado/único, senha min 8 + 1
  especial + máx 72 bytes nativo, name); 201 id/email/name; 422 erros;
  strong params; rate limit 5/min; 400 body vazio.

### A2 — Signup cria Project "Inbox" automático ✅ (implementada, aguarda review)

- Models `Project` (name, owner→User, personal) e `ProjectMembership`
  (project, user, role owner|member, índice único [project_id, user_id]).
- Signup: User + Inbox (`personal: true`) + membership owner na MESMA
  transação — falhou qualquer parte, nada persiste.
- Response do signup não muda.

### A3 — POST /login retorna JWT + GET /me

- Gem `jwt`. Token com claims `sub` (user id), `exp` 24h, `jti` (pra A4).
- Chave de assinatura: `Rails.application.secret_key_base` (sem env var nova).
- `POST /login` (email+senha) → 200 `{token: ...}`; credencial errada → 401
  resposta genérica (sem distinguir email inexistente de senha errada).
- Rate limit nativo no login (mesma config do signup).
- Concern/base de autenticação: `authenticate_request!` lê `Authorization:
  Bearer`, resolve `current_user`; token ausente/inválido/expirado → 401 JSON.
- `GET /me` → id/email/name do current_user (primeira rota autenticada).
- Signup passa a devolver campo `token` também (auto-login).
- Testes chave: login ok; senha errada 401 genérico; `/me` sem token 401;
  `/me` com token expirado 401 (viajar no tempo com `travel_to`); `/me` ok;
  response do signup ganha campo `token`.

### A4 — DELETE /logout + revogação de token

- Model `RevokedToken` (jti único, expires_at, índice em jti).
- `DELETE /logout` grava jti do token atual → respostas seguintes com esse
  token = 401.
- Middleware/concern de auth checa jti revogado.
- Limpeza: destroy de `expires_at < now` no próprio logout (sem job novo —
  volume 5-10 users não justifica; upgrade pra job se crescer).
- Testes chave: logout 204; request pós-logout 401; token expirado não
  entra na tabela à toa.

## Bloco B — Projects

### B1 — GET /projects + POST /projects

- `GET /projects` → só projects onde user é membro (`current_user.projects`,
  nunca `Project.all` — IDOR).
- `POST /projects` → cria project (`personal: false`) + membership owner na
  mesma transação (mesmo padrão da A2 — extrair helper se duplicar).
- Strong params: só `name`. `owner_id`/`personal` nunca vêm do client.
- Testes chave: lista só os meus; project de outro user não aparece
  (regressão IDOR); criar me torna owner.

### B2 — POST /projects/:id/invite

- Só `role: owner` pode convidar → member recebe 403.
- Resposta idêntica (200 genérico) se email já é membro, não existe conta,
  ou convite ok — anti account enumeration.
- Convidado vira membership `role: member`.
- Testes chave: owner convida ok; member 403; email inexistente vs. já
  membro vs. sucesso → mesma resposta (regressão enumeration); user de fora
  do project 403/404.

## Bloco C — Tasks

### C1 — POST /tasks + GET /projects/:id/tasks

- Model `Task`: project, title (null: false), description, status enum
  string (pending|done, default pending), due_date, priority enum string
  (low|med|high), parent_task_id, recurrence_rule (nullable). Índices:
  project_id, parent_task_id.
- Criar/listar exige membership no project (via `current_user.projects`).
- Paginação na listagem desde já (Regra 11) — `limit/offset` simples.
- Testes chave: cria task no meu project; project alheio → 404 (não 403,
  não vazar existência); lista só tasks do project; sem membership → 404.

### C2 — PATCH /tasks/:id + DELETE /tasks/:id

- Editar/concluir/deletar só se membro do project da task (resolver task
  via `current_user.projects` join — IDOR).
- Strong params: title, description, status, due_date, priority,
  parent_task_id. `project_id` não muda no PATCH.
- Testes chave: edito task minha; task de project alheio 404 (regressão
  IDOR do spec de design); status inválido 422.

### C3 — Subtarefas (parent_task_id)

- Validação de model: task pai deve ter o MESMO `project_id` — bloqueia
  IDOR via campo (teste de regressão do design).
- Máximo 3 níveis de subtarefa (decisão fechada do usuário). Validação
  caminha a cadeia de parents (máx 3 hops) — de brinde bloqueia self-parent
  e ciclo A→B→A.
- Testes chave: subtarefa ok; 3º nível ok; 4º nível 422; self-parent 422;
  ciclo 422; parent de outro project 422 na criação E no PATCH; parent
  inexistente 422.

### C4 — Recorrência

- `recurrence_rule` enum string fechado: daily | weekly | monthly | nil.
- PATCH marcando `status: done` em task recorrente → cria próxima instância
  na mesma transação (due_date + 1 day/week/month), próxima herda
  recurrence_rule e demais campos.
- Testes chave: concluir daily cria próxima com due_date +1 dia (idem
  weekly/monthly); concluir de novo a MESMA task não duplica; task sem
  recurrence_rule não cria nada; rule fora do enum 422.

## Bloco D — Infra transversal da API

### D1 — CORS

- `rack-cors` restrito à origin do client Flutter web (sem `*`), via env
  var com default de dev (`http://localhost:PORTA_FLUTTER`).
- Teste: preflight da origin permitida ok; origin desconhecida sem headers
  CORS.

## Bloco E — Cliente Flutter

### E1 — Setup projeto + design system

- `flutter create` (web + mobile), Riverpod, `flutter_secure_storage`.
- Design system definido ANTES de telas (Regra 9): tokens de cor,
  tipografia, espaçamento, uma lib de ícones.

### E2 — Auth: telas login/signup + sessão

- Consome POST /signup e /login; token no `flutter_secure_storage`.
- Estado de sessão via Riverpod; 401 → volta pro login.

### E3 — Lista de Projects + lista de Tasks

- GET /projects, GET /projects/:id/tasks, POST /tasks.

### E4 — Detalhe/edição de Task + subtarefas

- PATCH/DELETE /tasks/:id, criação de subtarefa, marcar concluída.

### E5 — Widget test do fluxo principal

- 1 widget test login → lista de tasks (teste do spec de design).

## Fora de escopo (não virar fatia)

- Finanças, hábitos, hosting/deploy, push, offline-first (spec de design).
- Update/delete de project e remoção de membro — backlog pós-MVP (decisão
  registrada em memória do projeto).
- Delete de User: sem endpoint no MVP. Nota do reviewer: deletar user dono
  de projects estouraria a FK `owner_id` — resolver quando/se o endpoint
  existir.
- Refresh token — expirou, loga de novo (spec de design).
