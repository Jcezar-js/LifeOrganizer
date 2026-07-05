# Life Organizer — Design: Base (auth) + Módulo Tarefas/Projetos

Data: 2026-07-04

## Contexto e escopo

Life Organizer é um app pessoal/familiar cobrindo tarefas, finanças e hábitos,
para 5-10 usuários. Escopo grande demais pra um spec só — decompõe-se em
sub-projetos, cada um com seu próprio ciclo spec → plano → implementação:

1. **Base (auth) + Tarefas/Projetos** ← este spec
2. Finanças pessoais (spec futuro)
3. Hábitos/rotina (spec futuro)

Ordem definida pelo usuário: base primeiro, depois tarefas, depois os demais.

## Metodologia

Desenvolvimento segue **Extreme Programming (XP)**, com Claude atuando como
buddy de pair programming. Práticas adotadas:

- **TDD obrigatório**: todo código de produção nasce de um teste que falha
  primeiro (red → green → refactor). Nenhuma feature ou fix entra sem teste
  escrito antes da implementação.
- **Passos pequenos**: cada ciclo red-green-refactor é a menor fatia possível
  — um endpoint, uma regra de negócio, uma validação por vez.
- **Refactor contínuo**: depois de verde, limpar duplicação antes de seguir
  pro próximo teste — nunca acumular débito "pra depois".
- **Pair programming**: usuário e Claude revisam juntos cada ciclo antes de
  avançar — Claude não deve implementar lotes grandes sem checkpoint.
- **Integração contínua**: commits pequenos e frequentes, sempre com suíte
  verde.

O plano de implementação (próxima etapa) deve quebrar cada feature do MVP em
ciclos TDD explícitos, não em tarefas genéricas "implementar X".

## Arquitetura

- **API**: Ruby on Rails 7 em modo `--api`.
- **Banco**: SQLite (free tier / zero infra extra, suficiente para 5-10
  usuários).
- **Cliente**: Flutter/Dart, codebase único servindo web e mobile
  (iOS/Android), consumindo a API via REST/JSON.
- **Auth**: JWT manual (gem `jwt` + `has_secure_password`/`bcrypt`), sem
  Devise — mais simples para o volume de usuários do projeto.
- **State management (Flutter)**: Riverpod.
- **Hosting**: decisão adiada para quando o deploy for necessário.

## Segurança

- **JWT**: claim `exp` obrigatório (ex: 24h). Sem refresh token no MVP —
  expirado, usuário loga de novo.
- **Revogação**: tabela `revoked_tokens` (jti + expires_at) checada no
  middleware de auth; endpoint `DELETE /logout` insere o jti atual nela.
  Job de limpeza (ou query com `expires_at < now`) evita crescimento infinito.
- **Rate limiting**: gem `rack-attack` limitando `/login` e `/signup` por IP
  (ex: 5 tentativas/min) — mitiga brute force.
- **Senha**: validar tamanho máximo (72 bytes, limite do bcrypt) além do
  mínimo, pra não truncar silenciosamente.
- **Autorização em `/projects/:id/invite`**: só `role: owner` do project pode
  convidar. Resposta idêntica se o email já é membro ou não existe conta
  (evita account enumeration).
- **Strong params**: todo controller usa `params.require(...).permit(...)`
  explícito — nunca mass assignment direto. Campos como `role`, `owner_id`,
  `status` de outro usuário nunca vêm do client sem checagem de autorização.
- **`parent_task_id` cross-project**: validação de model garante que a task
  pai pertence ao mesmo `project_id` da subtarefa — bloqueia vazamento de
  `task_id` entre projects diferentes.
- **`recurrence_rule`**: enum fechado (`daily`, `weekly`, `monthly`, `nil`) —
  sem string livre.
- **CORS**: `rack-cors` restrito à origin do client Flutter web (sem `*`).

## Modelo de dados

```
User
  id, email, password_digest, name

Project
  id, name, owner_id (User), personal (bool)

ProjectMembership
  id, project_id, user_id, role (owner | member)

Task
  id, project_id, title, description, status (pending | done),
  due_date, priority (low | med | high),
  parent_task_id (nullable — self-reference para subtarefa),
  recurrence_rule (nullable, enum: daily | weekly | monthly)

RevokedToken
  id, jti, expires_at
```

Regras do modelo:

- Todo `User` recebe, na criação da conta, um `Project` pessoal automático
  (`personal: true`, ex. "Inbox"), do qual só ele é membro.
- Toda `Task` pertence a um `Project` — não existe "task sem projeto" como
  caso especial. Task em projeto pessoal = privada; task em projeto
  compartilhado = visível a todos os membros daquele projeto.
- Subtarefa = `Task` cujo `parent_task_id` aponta para outra `Task` (sem
  tabela adicional).
- Recorrência: `recurrence_rule` na própria task. Ao marcar uma task
  recorrente como concluída, o sistema cria automaticamente a próxima
  instância.
- Acesso a dados é sempre resolvido via `ProjectMembership` — nunca por
  consulta direta a `Project.all` ou `Task.all` (previne IDOR).
- `Task#parent_task_id` só aceita task com o mesmo `project_id` (validação de
  model — previne IDOR via campo, não só via rota).

## Endpoints da API

```
POST /signup                  → cria User + Project pessoal automático
POST /login                   → retorna JWT (exp 24h)
DELETE /logout                → revoga JWT atual (grava jti em RevokedToken)
GET  /me                      → dados do usuário autenticado

GET    /projects              → lista projects em que o usuário é membro
POST   /projects              → cria project (criador vira owner)
POST   /projects/:id/invite   → adiciona membro por email (só owner do
                                 project; resposta genérica se email já é
                                 membro ou não existe conta)

GET    /projects/:id/tasks    → lista tasks do project
POST   /tasks                 → cria task (project_id, title, due_date,
                                 priority, parent_task_id opcional)
PATCH  /tasks/:id              → edita / marca concluída (dispara criação
                                 da próxima instância se recorrente)
DELETE /tasks/:id
```

Toda rota exceto `/signup` e `/login` exige `Authorization: Bearer <JWT>`.
Controllers sempre filtram a partir de `current_user.projects`. Todo
controller usa strong params (`require`/`permit` explícito) — nenhum campo
sensível (`role`, `owner_id`, `status` alheio) aceito por mass assignment.

## Cliente Flutter

- Codebase único (`flutter build web` / `apk` / `ipa`).
- State management: Riverpod.
- Token JWT persistido via `flutter_secure_storage` (não em
  SharedPreferences puro, por ser dado sensível).
- Telas do MVP: Login/Signup, Lista de Projects, Lista de Tasks por Project,
  Detalhe/edição de Task (com subtarefas).

## Testes

- **Rails (RSpec, request specs)**:
  - signup cria Project "Inbox" automaticamente.
  - usuário não consegue acessar/editar task de um project do qual não é
    membro (regressão de IDOR).
  - concluir task recorrente cria a próxima instância com a data correta.
  - `member` (não-owner) não consegue chamar `/projects/:id/invite` (403).
  - invite com email já membro ou inexistente retorna a mesma resposta
    genérica (regressão de account enumeration).
  - `parent_task_id` de outro project é rejeitado na criação/edição de task
    (regressão de IDOR via campo).
  - request com JWT expirado retorna 401.
  - request com JWT revogado (pós `/logout`) retorna 401.
  - `/login` bloqueia após N tentativas na janela de rate limit.
- **Flutter**: 1 widget test cobrindo o fluxo login → lista de tasks.

## Fora de escopo deste spec

- Módulo de finanças pessoais.
- Módulo de hábitos/rotina.
- Decisão de hosting/deploy.
- Notificações push, offline-first, ou sincronização em tempo real.
