# Project Standards

This file extends the global `~/.claude/CLAUDE.md`. It defines stack-specific conventions for this project.

---

## Stack

TypeScript (strict mode), Prisma ORM, PostgreSQL, Redis, Better Auth, Docker Compose.

**External Documentation:**
- Better Auth: https://www.better-auth.com/llms.txt

---

## Docker-First Development

- **All commands run inside containers** — never run npm/npx directly on the host.
  ```bash
  docker compose exec backend npm test
  docker compose exec backend npx prisma migrate dev --name description
  ```
- **No host bind mounts by default** — code lives in Docker images. After code changes, rebuild before testing:
  ```bash
  docker compose up -d --build
  ```
- If the project uses bind mounts for dev hot-reload, it will be noted in the Project Architecture section below.

---

## Code Style

- **Prettier**: semi: true, singleQuote: true, trailingComma: all, printWidth: 100, tabWidth: 2
- **TypeScript**: strict mode enabled, prefer explicit types at boundaries
- **Naming**: camelCase for variables/functions, PascalCase for types/components, kebab-case for files
- Avoid `any` — use `unknown` and narrow, or define proper types
- Underscore prefix (`_var`) for intentionally unused parameters only

---

## Type Checking

Vitest and esbuild strip TypeScript types without checking them. **Passing tests does NOT mean the code compiles.** Only `tsc` enforces types.

Before marking any change complete, run:
```bash
docker compose exec backend npx tsc --noEmit
docker compose exec frontend npx tsc -b
```
Both must exit 0. If there are pre-existing errors in files you did not touch, flag them to the user.

---

## Testing

- **Unit/integration:** Vitest (run inside containers)
- **E2E:** Playwright
- Test files live alongside source: `*.test.ts` / `*.test.tsx`

---

## Database and Prisma

- **Always read `prisma/schema.prisma` before any database work** — it is the source of truth
- **Use Prisma's query builder exclusively** — never use `prisma.$queryRaw` or raw SQL
  - Prisma model names (camelCase) differ from PostgreSQL table names (snake_case)
  - Raw SQL bypasses type safety and breaks on schema changes
- Run migrations inside the container: `docker compose exec backend npx prisma migrate dev --name description`
- After schema changes, rebuild: `docker compose up -d --build`
- **NEVER reset or wipe the database without explicit user permission** — `prisma migrate reset`, `prisma db push --force-reset`, or any command that drops tables is FORBIDDEN unless the user explicitly asks

---

## Better Auth

- Config: `backend/src/auth.ts`
- Frontend auth client: `frontend/src/lib/auth.ts`
- Express 4 wildcard syntax: `/api/auth/*` (NOT `*splat`)

**Express middleware ordering is critical — do not change:**
1. Helmet
2. CORS
3. **Better Auth handler BEFORE `express.json()`** — `app.all('/api/auth/*', toNodeHandler(auth))`
4. `express.json()` and `express.urlencoded()`
5. Request logging
6. Routes

---

## Project Architecture

<!-- Update this section when you start a new project -->

**Application type:** <!-- e.g., REST API, full-stack web app, CLI tool -->

**Key directories:**
<!-- e.g.,
- backend/src/routes/ — API route handlers
- backend/src/services/ — business logic
- backend/src/auth.ts — Better Auth configuration
- backend/prisma/schema.prisma — data model
- frontend/src/pages/ — route page components
- frontend/src/components/ — shared UI components
-->

**Ports:**
<!-- e.g.,
| Service  | Port |
|----------|------|
| Frontend | 4000 |
| Backend  | 4001 |
| Postgres | 5432 |
| Redis    | 6379 |
-->

**Key decisions:**
<!-- e.g.,
- Auth: Better Auth with email/password + GitHub OAuth
- Sessions stored in PostgreSQL, not Redis
- Background jobs handled by BullMQ via Redis
-->
