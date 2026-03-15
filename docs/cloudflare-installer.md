# Cloudflare installer endpoint

This project includes a small Cloudflare Worker that serves a stable installer URL such as:

```bash
curl -fsSL https://glm-ocr-cli.mejiasdev.com/install.sh | bash
```

The Worker resolves the latest GitHub release tag and returns a tiny bootstrap shell script that downloads and runs the matching tagged `install.sh` from GitHub.

## Files

- `deploy/cloudflare/worker.js`
- `deploy/cloudflare/wrangler.toml`

## Behavior

### Latest release

```bash
curl -fsSL https://glm-ocr-cli.mejiasdev.com/install.sh | bash
```

This resolves `releases/latest` from GitHub and installs that tag.

### Pinned version

```bash
curl -fsSL 'https://glm-ocr-cli.mejiasdev.com/install.sh?version=v0.1.0' | bash
```

This installs a specific tag.

## Deploy with Cloudflare Workers

1. Install Wrangler:

```bash
npm install -g wrangler
```

2. Log in:

```bash
cd deploy/cloudflare
npx wrangler login
```

3. Deploy:

```bash
npx wrangler deploy
```

5. In Cloudflare, attach a custom route or domain such as:

- `glm-ocr-cli.mejiasdev.com/install.sh`

You can do this either in the dashboard or by adding a `routes` entry in `wrangler.toml`.

## Suggested DNS/domain setup

Use a dedicated subdomain:

- `glm-ocr-cli.mejiasdev.com`

Then route `/install.sh` to the Worker.

## Notes

- The bootstrap script intentionally installs the latest **release**, not `main`.
- The repo `install.sh` supports both:
  - `GLMOCR_VERSION=v0.1.0`
  - `GLMOCR_BRANCH=main`
- Latest release responses are cached briefly; pinned versions can be cached longer.
