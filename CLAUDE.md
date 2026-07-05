# CLAUDE.md

Guia pro Claude Code neste repositório (Life Organizer).

## Sobre o projeto

App pessoal/familiar de organização de vida (tarefas/projetos, finanças,
hábitos) para 5-10 usuários. Escopo decomposto em sub-projetos sequenciais,
cada um com spec próprio em `docs/superpowers/specs/`:

1. Base (auth) + Tarefas/Projetos — spec em
   `docs/superpowers/specs/2026-07-04-base-e-tarefas-design.md`
2. Finanças pessoais (spec futuro)
3. Hábitos/rotina (spec futuro)

## Metodologia

**Extreme Programming (XP)**, Claude como buddy de pair programming.

- TDD obrigatório: todo código de produção nasce de teste vermelho antes.
  Ciclo red → green → refactor, sem pular etapa.
- Passos pequenos: menor fatia possível por ciclo (um endpoint, uma regra
  de negócio por vez).
- Refactor contínuo: limpar duplicação antes do próximo teste, nunca
  acumular débito.
- Checkpoints de revisão conjunta a cada ciclo — não implementar lotes
  grandes sem parar pra revisar junto.
- Commits pequenos e frequentes, sempre com suíte de testes verde.

## Stack

- **API**: Ruby on Rails 8 (`--api` mode) — em `api/`, Ruby 3.4 via rbenv
- **Banco**: SQLite
- **Cliente**: Flutter/Dart — codebase único (web + mobile iOS/Android)
- **Auth**: JWT manual (gem `jwt` + `has_secure_password`), sem Devise
- **State management (Flutter)**: Riverpod
- **Testes API**: RSpec (request specs)
- **Testes Flutter**: `flutter_test` (widget tests)

## Modelo de dados (base + tarefas)

- `User` → dono de contas, ganha `Project` pessoal automático no signup.
- `Project` → agrupador de tarefas; pode ser pessoal ou compartilhado.
- `ProjectMembership` → controla quem acessa qual `Project`.
- `Task` → sempre pertence a um `Project`; subtarefa via `parent_task_id`
  auto-referenciado; recorrência via `recurrence_rule`.

Acesso a dados sempre resolvido via `ProjectMembership` — nunca
`Project.all`/`Task.all` direto (previne IDOR).

## Comandos

```bash
# API (Rails) — dev (a partir de api/)
bin/rails server

# API (Rails) — testes (a partir de api/)
bundle exec rspec

# Flutter — dev (web)
flutter run -d chrome

# Flutter — dev (mobile)
flutter run

# Flutter — testes
flutter test
```

## Variáveis de ambiente

_A preencher conforme necessário (ex: `SECRET_KEY_BASE`, chave JWT)._

## Hosting

Ainda não decidido — adiado pra fase de deploy.
