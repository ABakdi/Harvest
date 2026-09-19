# syntax=docker/dockerfile:1
#
# The sync server. Build from the repository root, because the server
# needs the contracts package beside it:
#
#   docker build -f apps/server/Dockerfile -t harvest-server .

FROM node:22-alpine AS build
WORKDIR /repo
# The mongod that the tests use is a test dependency; the image never runs it.
ENV MONGOMS_DISABLE_POSTINSTALL=1
RUN corepack enable

# Manifests first, so a source change does not reinstall everything.
COPY package.json pnpm-lock.yaml pnpm-workspace.yaml tsconfig.base.json ./
COPY packages/contracts/package.json packages/contracts/
COPY apps/server/package.json apps/server/
RUN pnpm install --frozen-lockfile --filter "@harvest/server..."

COPY packages/contracts packages/contracts
COPY apps/server apps/server
RUN pnpm --filter "@harvest/server..." run build \
 && pnpm --filter @harvest/server deploy --prod /out

FROM node:22-alpine
ENV NODE_ENV=production PORT=8080
WORKDIR /app
COPY --from=build --chown=node:node /out ./
USER node
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s \
  CMD wget -qO- "http://127.0.0.1:${PORT}/v1/health" >/dev/null || exit 1
CMD ["node", "dist/index.js"]
