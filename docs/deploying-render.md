# Deploying AFFiNE on Render

This repo can run on Render with a Docker-based web service, Render Postgres, and Render Key Value.

The checked-in [render.yaml](/Users/ignaciopardo/autonoma/AFFiNE/render.yaml) is aimed at a practical first deployment:

- one Docker web service built from [Dockerfile](/Users/ignaciopardo/autonoma/AFFiNE/Dockerfile)
- one Render Postgres instance
- one Render Key Value instance for queues and cache
- one persistent disk mounted at `/root/.affine` for uploads and generated config
- automatic preview environments for pull requests, with a 3-day expiry
- search indexing disabled by default via `AFFINE_INDEXER_ENABLED=false`

## Why this shape

AFFiNE's self-hosted server expects:

- Postgres
- Redis-compatible storage
- a writable filesystem for uploads and the generated private key

The Render runtime helper at [scripts/render-runtime.mjs](/Users/ignaciopardo/autonoma/AFFiNE/scripts/render-runtime.mjs) does two things for Render:

- maps `RENDER_EXTERNAL_URL` to `AFFINE_SERVER_EXTERNAL_URL` when Render provides the public URL
- parses the Render Key Value connection string into the `REDIS_SERVER_*` variables that AFFiNE expects

## Create the stack

1. Push this repository to GitHub.
2. In Render, create a new Blueprint from the repo.
3. Let Render read [render.yaml](/Users/ignaciopardo/autonoma/AFFiNE/render.yaml).
4. Review plan sizes before applying. The defaults here are intentionally conservative, not tuned.
5. Deploy.

You can validate the Blueprint locally first with:

```bash
render blueprints validate ./render.yaml
```

## Preview environments

Blueprint preview environments are enabled with `previews.generation: automatic`.

Render creates a fresh copy of the web service, Postgres database, and Key Value service for each pull request. Render's docs are explicit that preview datastores do not copy production data, so preview environments start empty unless you add your own seed step.

Because the app is stateful, previews are useful for UI and auth regression checks, but they are not seeded with real workspaces by default.

## Current limitations

- Search indexing is disabled in this setup. AFFiNE supports Manticore or Elasticsearch/OpenSearch, but this Blueprint keeps the initial deployment smaller.
- SMTP is not configured. Email/password auth already exists in AFFiNE; outbound email flows still need a mail provider if you want them in production.
- The service uses a persistent disk, so Render will not scale this service horizontally.

## Notes on auth

Email/password sign-in already works in AFFiNE. In local verification, the seeded development account from [docs/developing-server.md](/Users/ignaciopardo/autonoma/AFFiNE/docs/developing-server.md:48) authenticated successfully, so no additional auth implementation was added here.
