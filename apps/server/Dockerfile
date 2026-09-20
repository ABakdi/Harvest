# The sync server, built once and run as nobody.
#
# Two stages: the first installs the workspace and compiles the server
# and the packages it imports; the second carries the built output and
# the production dependencies, and nothing else — no sources, no
# toolchain, no pnpm store.
FROM node:22-alpine AS build
WORKDIR /harvest

RUN corepack enable

# The manifests first, so a change to a source file does not re-install
# the world.
COPY pnpm-workspace.yaml pnpm-lock.yaml package.json tsconfig.base.json ./
COPY packages/contracts/package.json packages/contracts/
COPY packages/core/package.json packages/core/
COPY apps/server/package.json apps/server/
RUN pnpm install --frozen-lockfile --filter @harvest/server...

COPY packages/contracts packages/contracts
COPY packages/core packages/core
COPY apps/server apps/server
RUN pnpm --filter @harvest/contracts build \
  && pnpm --filter @harvest/core build \
  && pnpm --filter @harvest/server build

# `pnpm deploy` writes a self-contained tree: the server, the workspace
# packages it imports as real directories rather than links, and the
# production dependencies of all three. Nothing outside /out is needed
# to run it, which is what the second stage carries.
RUN pnpm deploy --filter @harvest/server --prod /out

FROM node:22-alpine AS run
WORKDIR /harvest
ENV NODE_ENV=production
ENV PORT=8080

COPY --from=build /out ./

USER node
EXPOSE 8080
# The health route is the same one a load balancer should watch.
HEALTHCHECK --interval=30s --timeout=3s --start-period=10s \
  CMD node -e "fetch('http://127.0.0.1:'+(process.env.PORT||8080)+'/v1/health').then(r=>process.exit(r.ok?0:1),()=>process.exit(1))"
CMD ["node", "dist/index.js"]
