# glm-ocr-cli

[![Platform](https://img.shields.io/badge/platform-macOS%20Apple%20Silicon-black)](#requirements)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](./LICENSE)
[![Pi Skill](https://img.shields.io/badge/pi-skill-blueviolet)](./skills/ocr/SKILL.md)

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

## Install

### One-line installer

Latest release via custom domain:

```bash
curl -fsSL https://glm-ocr-cli.mejiasdev.com/install.sh | bash
```

Or install directly from GitHub `main`:

```bash
curl -fsSL https://raw.githubusercontent.com/mejiasd3v/glm-ocr-cli/main/install.sh | bash
```

On macOS, the installer automatically sets up required system dependencies when missing:
- Homebrew
- Xcode Command Line Tools
- `git`
- `uv`
- `python@3.12`
- `poppler` (`pdftoppm` for PDFs)

It also:
- clones the repo to `~/.local/share/glm-ocr-cli`
- symlinks the CLI to `~/.local/bin/ocr`
- symlinks the skill to `~/.agents/skills/ocr`
- bootstraps the local OCR virtualenvs

Then verify with:

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
ln -s ~/Developer/oss/glm-ocr-cli/skills/ocr ~/.agents/skills/ocr
```

Make the CLI global:

```bash
mkdir -p ~/.local/bin
ln -s ~/Developer/oss/glm-ocr-cli/bin/ocr ~/.local/bin/ocr
```

Ensure `~/.local/bin` is on your `PATH`, then bootstrap dependencies:

```bash
ocr install
ocr doctor
```

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
- internet access for first-time dependency and model setup

If you use the one-line installer on macOS, it installs the required local tooling automatically.

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
skills/ocr/             Skill package
skills/ocr/config/      Example config
skills/ocr/scripts/     Setup, parse, doctor, benchmark helpers
skills/ocr/SKILL.md     Pi skill definition
package.json            Repo metadata + validation scripts
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

## First run

If you used the one-line installer, the local OCR environments are already bootstrapped. For a manual install, create them with:

```bash
ocr install
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

## Development

Basic checks:

```bash
npm run check
npm run test:install
```

## Acknowledgements

Built on top of:
- [GLM-OCR](https://huggingface.co/zai-org/GLM-OCR)
- [mlx-vlm](https://github.com/Blaizzy/mlx-vlm)
- the `glmocr` Python SDK
