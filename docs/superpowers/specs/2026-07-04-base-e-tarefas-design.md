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

## Arquitetura

- **API**: Ruby on Rails 7 em modo `--api`.
- **Banco**: SQLite (Regra 18 — Punk Computing; suficiente para 5-10 usuários,
  zero infra extra).
- **Cliente**: Flutter/Dart, codebase único servindo web e mobile
  (iOS/Android), consumindo a API via REST/JSON.
- **Auth**: JWT manual (gem `jwt` + `has_secure_password`/`bcrypt`), sem
  Devise — mais simples para o volume de usuários do projeto.
- **State management (Flutter)**: Riverpod.
- **Hosting**: decisão adiada para quando o deploy for necessário.

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
  recurrence_rule (nullable — ex: "daily" | "weekly" | "monthly")
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

## Endpoints da API

```
POST /signup                  → cria User + Project pessoal automático
POST /login                   → retorna JWT
GET  /me                      → dados do usuário autenticado

GET    /projects              → lista projects em que o usuário é membro
POST   /projects              → cria project (criador vira owner)
POST   /projects/:id/invite   → adiciona membro por email

GET    /projects/:id/tasks    → lista tasks do project
POST   /tasks                 → cria task (project_id, title, due_date,
                                 priority, parent_task_id opcional)
PATCH  /tasks/:id              → edita / marca concluída (dispara criação
                                 da próxima instância se recorrente)
DELETE /tasks/:id
```

Toda rota exceto `/signup` e `/login` exige `Authorization: Bearer <JWT>`.
Controllers sempre filtram a partir de `current_user.projects`.

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
- **Flutter**: 1 widget test cobrindo o fluxo login → lista de tasks.

## Fora de escopo deste spec

- Módulo de finanças pessoais.
- Módulo de hábitos/rotina.
- Decisão de hosting/deploy.
- Notificações push, offline-first, ou sincronização em tempo real.
