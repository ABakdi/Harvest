# The web app: built once, served by Caddy as static files, with /v1
# handed to the sync server on the same origin ([[Deployment]]).
FROM node:22-alpine AS build
WORKDIR /harvest

RUN corepack enable

COPY pnpm-workspace.yaml pnpm-lock.yaml package.json tsconfig.base.json ./
COPY packages/contracts/package.json packages/contracts/
COPY packages/core/package.json packages/core/
COPY apps/web/package.json apps/web/
RUN pnpm install --frozen-lockfile --filter @harvest/web...

# The web compiles the shared packages from source (see vite.config.ts),
# so their sources come along, not their builds.
COPY packages/contracts packages/contracts
COPY packages/core packages/core
COPY apps/web apps/web
RUN pnpm --filter @harvest/web build

FROM caddy:2-alpine AS run
COPY deploy/Caddyfile /etc/caddy/Caddyfile
COPY --from=build /harvest/apps/web/dist /srv/harvest
EXPOSE 80 443
