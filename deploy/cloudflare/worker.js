export default {
  async fetch(request) {
    const url = new URL(request.url)

    if (url.pathname !== '/install.sh') {
      return new Response('Not found', { status: 404 })
    }

    const explicitVersion = url.searchParams.get('version') || ''
    const repo = 'mejiasd3v/glm-ocr-cli'

    let ref = explicitVersion
    if (!ref) {
      const latest = await fetch(`https://api.github.com/repos/${repo}/releases/latest`, {
        headers: {
          'User-Agent': 'glm-ocr-cli-installer',
          'Accept': 'application/vnd.github+json',
        },
      })

      if (!latest.ok) {
        return new Response(`Failed to resolve latest release: ${latest.status}\n`, {
          status: 502,
          headers: { 'content-type': 'text/plain; charset=utf-8' },
        })
      }

      const data = await latest.json()
      ref = data.tag_name
    }

    const script = `#!/usr/bin/env bash
set -euo pipefail

REPO="${repo}"
REF="${ref}"
SCRIPT_URL="https://raw.githubusercontent.com/${repo}/${ref}/install.sh"

echo "[glm-ocr-cli-bootstrap] resolved ref: ${ref}" >&2
curl -fsSL "$SCRIPT_URL" | GLMOCR_VERSION="$REF" bash
`

    return new Response(script, {
      headers: {
        'content-type': 'text/plain; charset=utf-8',
        'cache-control': explicitVersion
          ? 'public, max-age=3600'
          : 'public, max-age=300',
      },
    })
  },
}
