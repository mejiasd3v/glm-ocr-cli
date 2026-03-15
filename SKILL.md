---
name: ocr
description: Extract text, tables, formulas, and structured document content from local PDFs and images using the GLM-OCR model running locally on Apple Silicon via mlx-vlm. Use when a user asks for OCR, document parsing, scanned PDF extraction, invoice/receipt/ID/document digitization, or converting screenshots and document images into Markdown/JSON.
---

# OCR

This skill runs **GLM-OCR locally** and is optimized for:

- PDFs
- scanned documents
- screenshots
- receipts, invoices, forms
- tables and formulas in document images

It uses a **two-part local setup**:

1. `mlx-vlm` serves the GLM-OCR model on Apple Silicon
2. `glmocr` SDK handles PDF/image parsing and structured output

## Global CLI

A global CLI should be installed at:

```bash
~/.local/bin/ocr
```

If `~/.local/bin` is on PATH, you can just run `ocr`.

The CLI now handles both of these automatically:

- first-run environment setup
- temporary model server startup for each parse
- automatic server shutdown after the parse completes

So the normal flow is just:

```bash
ocr /path/to/file.pdf --stdout
```

Examples:

```bash
# Parse a single PDF and save outputs under ./output
ocr ./docs/invoice.pdf

# Parse an image and print Markdown/JSON to stdout
ocr ./images/receipt.jpg --stdout --no-save

# Parse a whole directory
ocr ./scans --output ./ocr-results --no-layout-vis
```

Useful management commands:

```bash
ocr install      # force setup/install
ocr server       # optional: start a persistent background server
ocr status       # show config and server state
ocr stop         # stop background server if one is running
ocr logs         # tail server log
ocr doctor       # run a local self-test
```

Defaults:

- host: `127.0.0.1`
- port: `8080`
- model: `mlx-community/GLM-OCR-bf16`
- layout analysis: `off` by default for local stability

Override with env vars if needed:

```bash
GLMOCR_PORT=8081 ocr ./file.pdf --stdout
GLMOCR_MODEL=mlx-community/GLM-OCR-8bit ocr ./file.pdf --stdout
GLMOCR_ENABLE_LAYOUT=1 ocr ./file.pdf --stdout
```

## Output

The parser writes structured artifacts per file:

- `<stem>.md` — Markdown reconstruction of the document
- `<stem>.json` — structured regions with labels and bounding boxes
- `imgs/` — cropped figures referenced by Markdown
- `layout_vis/` — layout overlays unless disabled

This is usually enough for downstream extraction. Typical flow:

1. run OCR locally
2. inspect `.md` or `.json`
3. extract the final fields the user wants

## Good prompts / use cases

- “Extract all text from this scanned PDF”
- “Turn this invoice into JSON”
- “OCR this screenshot and preserve the table”
- “Parse this receipt image into Markdown”
- “Read this form PDF and summarize key fields”

## Notes

- Best on Apple Silicon because this setup uses `mlx-vlm`.
- For PDFs, Poppler is helpful; this machine already has `pdftoppm`.
- By default, `ocr <file>` starts a temporary local server and shuts it down automatically when parsing finishes, so no background process is left around.
- First model load can take a while because weights and Metal kernels need to warm up.
- Layout analysis is currently disabled by default because the local SDK layout path was unstable in testing.
- `mlx-community/GLM-OCR-bf16` is the recommended default. `8bit` is a lighter experimental option.
- Run `ocr doctor` after setup or changes to confirm the full local path still works.
