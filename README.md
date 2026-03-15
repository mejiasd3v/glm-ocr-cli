# glm-ocr-cli

[![Platform](https://img.shields.io/badge/platform-macOS%20Apple%20Silicon-black)](#requirements)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](./LICENSE)
[![Pi Skill](https://img.shields.io/badge/pi-skill-blueviolet)](./SKILL.md)

Local OCR CLI and Pi skill powered by GLM-OCR on Apple Silicon.

It is designed for:
- PDFs
- scanned documents
- screenshots
- receipts, invoices, forms
- tables and formula-heavy document images

This project wraps a local GLM-OCR setup into a simple command:

```bash
ocr file.pdf --stdout
```

Normal runs are transient: the CLI starts the local model server, parses the input, and shuts the server down automatically.

## Features

- local OCR for PDFs and images
- Markdown + JSON outputs
- global `ocr` CLI
- Pi skill via `SKILL.md`
- Apple Silicon friendly via `mlx-vlm`
- BF16 default model
- optional quantized model benchmarking
- transient server lifecycle by default

## Requirements

- macOS on Apple Silicon
- Python 3.12
- `uv`
- optional but recommended for PDFs: `pdftoppm` from Poppler

Install Poppler with Homebrew if needed:

```bash
brew install poppler
```

## Demo

Run a self-test:

```bash
ocr doctor
```

Parse a file:

```bash
ocr ./invoice.pdf --stdout
ocr ./receipt.jpg --stdout --no-save
ocr ./scans --output ./ocr-results
```

Example output layout:

```text
output/
└── invoice/
    ├── invoice.md
    ├── invoice.json
    ├── imgs/
    └── layout_vis/
```

## Repo layout

```text
bin/                    Global CLI entrypoint
config/                 Example config
scripts/                Setup, parse, doctor, benchmark helpers
SKILL.md                Pi skill definition
README.md               Project docs
LICENSE                 MIT license
```

Generated local-only directories are ignored:

```text
.venv-mlx/
.venv-sdk/
.runtime/
benchmarks/
```

## Install

### One-line installer

Install from `main` directly:

```bash
curl -fsSL https://raw.githubusercontent.com/mejiasd3v/glm-ocr-cli/main/install.sh | bash
```

Or, if you set up the Cloudflare installer endpoint described below, install the latest release via your custom domain:

```bash
curl -fsSL https://glm-ocr-cli.mejiasdev.com/install.sh | bash
```

This will:
- clone the repo to `~/.local/share/glm-ocr-cli`
- symlink the CLI to `~/.local/bin/ocr`
- symlink the skill to `~/.agents/skills/ocr`

Then run:

```bash
ocr doctor
```

### Manual install

Clone the repo somewhere, for example:

```bash
git clone https://github.com/mejiasd3v/glm-ocr-cli.git ~/Developer/oss/glm-ocr-cli
```

Make the Pi skill available:

```bash
mkdir -p ~/.agents/skills
ln -s ~/Developer/oss/glm-ocr-cli ~/.agents/skills/ocr
```

Make the CLI global:

```bash
mkdir -p ~/.local/bin
ln -s ~/Developer/oss/glm-ocr-cli/bin/ocr ~/.local/bin/ocr
```

Ensure `~/.local/bin` is on your `PATH`.

## First run

The first run creates two local virtualenvs and installs dependencies automatically:

```bash
ocr doctor
```

Then parse a file:

```bash
ocr ./invoice.pdf --stdout
ocr ./receipt.jpg --stdout --no-save
ocr ./scans --output ./ocr-results
```

## Commands

```bash
ocr <file-or-dir> [glmocr flags...]
ocr parse <file-or-dir> [glmocr flags...]
ocr install
ocr doctor [sample-file]
ocr status
ocr logs
ocr stop
ocr server
ocr benchmark --models bf16 8bit 4bit
```

## Defaults

- host: `127.0.0.1`
- port: `8080`
- model: `mlx-community/GLM-OCR-bf16`
- layout analysis: off by default for local stability

## Environment overrides

```bash
GLMOCR_PORT=8081 ocr ./file.pdf --stdout
GLMOCR_MODEL=mlx-community/GLM-OCR-8bit ocr ./file.pdf --stdout
GLMOCR_ENABLE_LAYOUT=1 ocr ./file.pdf --stdout
```

## Output

For each file, the parser can produce:

- `<stem>.md` — Markdown reconstruction
- `<stem>.json` — structured OCR/layout result
- `imgs/` — cropped figures referenced by markdown
- `layout_vis/` — layout overlays when enabled

## Notes

- `mlx-community/GLM-OCR-bf16` is the recommended default.
- `8bit` is a lighter experimental option.
- Layout is disabled by default because the local SDK layout path was unstable in testing.
- Run `ocr doctor` after changes to verify the full local path.

## Cloudflare custom installer

To serve a stable custom-domain installer like:

```bash
curl -fsSL https://glm-ocr-cli.mejiasdev.com/install.sh | bash
```

use the included Cloudflare Worker files:

- `deploy/cloudflare/worker.js`
- `deploy/cloudflare/wrangler.toml.example`

Deployment notes:
- latest release installer docs: [`docs/cloudflare-installer.md`](./docs/cloudflare-installer.md)
- pinned version example:

```bash
curl -fsSL 'https://glm-ocr-cli.mejiasdev.com/install.sh?version=v0.1.0' | bash
```

## Acknowledgements

Built on top of:
- [GLM-OCR](https://huggingface.co/zai-org/GLM-OCR)
- [mlx-vlm](https://github.com/Blaizzy/mlx-vlm)
- the `glmocr` Python SDK
