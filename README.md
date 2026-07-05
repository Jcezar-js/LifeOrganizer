# Life Organizer

App pessoal/familiar de organização de vida (tarefas/projetos, finanças, hábitos) para 5-10 usuários.

Escopo decomposto em sub-projetos sequenciais, cada um com spec própria em `docs/superpowers/specs/`:

1. **Base (auth) + Tarefas/Projetos** — em desenvolvimento
2. Finanças pessoais — spec futuro
3. Hábitos/rotina — spec futuro

## Stack

- **API**: Ruby on Rails 8 (`--api` mode), Ruby 3.4, em `api/`
- **Banco**: SQLite
- **Auth**: JWT manual (gem `jwt` + `has_secure_password`), sem Devise
- **Cliente**: Flutter/Dart (web + mobile) — ainda não iniciado
- **Testes API**: RSpec (request specs)

## Modelo de dados

- `User` — dono de contas, ganha um `Project` pessoal ("Inbox") automático no signup
- `Project` — agrupador de tarefas; pode ser pessoal ou compartilhado
- `ProjectMembership` — controla quem acessa qual `Project` (owner/member); todo acesso a dados passa por aqui, nunca `Project.all`/`Task.all` direto
- `Task` — pertence a um `Project`; subtarefa via `parent_task_id`; recorrência via `recurrence_rule`

## Rodando localmente

```bash
# API — instalar dependências
cd api && bundle install

# API — subir servidor
bin/rails server

# API — rodar testes
bundle exec rspec
```

## Endpoints

| Método | Rota      | Descrição                                    |
|--------|-----------|-----------------------------------------------|
| POST   | `/signup` | Cria usuário + Project "Inbox" + membership owner (transação atômica), com rate limit (5/min por IP) |

## Metodologia

Extreme Programming (XP): TDD obrigatório (red → green → refactor), passos pequenos, commits frequentes com suíte verde. Detalhes em `CLAUDE.md`.
