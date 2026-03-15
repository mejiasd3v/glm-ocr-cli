#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import os
import re
import statistics
import subprocess
import sys
import time
from dataclasses import dataclass, asdict
from pathlib import Path

SKILL_DIR = Path(__file__).resolve().parents[1]
REPO_DIR = Path(os.environ.get('GLMOCR_BENCHMARK_REPO_DIR', '')).expanduser() if os.environ.get('GLMOCR_BENCHMARK_REPO_DIR') else None
SOURCE_DIR = None if REPO_DIR is None else REPO_DIR / 'examples' / 'source'
REFERENCE_DIR = None if REPO_DIR is None else REPO_DIR / 'examples' / 'result'
PARSE_SH = SKILL_DIR / 'scripts' / 'parse.sh'
OCR_BIN = Path(os.environ.get('GLMOCR_BIN', str(SKILL_DIR.parents[1] / 'bin' / 'ocr'))).expanduser()
DEFAULT_CASES = ['code', 'page', 'paper', 'table', 'handwritten', 'seal']
MODEL_ALIASES = {
    'bf16': 'mlx-community/GLM-OCR-bf16',
    '8bit': 'mlx-community/GLM-OCR-8bit',
    '6bit': 'mlx-community/GLM-OCR-6bit',
    '5bit': 'mlx-community/GLM-OCR-5bit',
    '4bit': 'mlx-community/GLM-OCR-4bit',
}


def normalize_text(text: str) -> str:
    text = text.replace('\r\n', '\n').replace('\r', '\n')
    text = re.sub(r'\s+', ' ', text).strip()
    return text


def levenshtein(a: str, b: str) -> int:
    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)
    if len(a) < len(b):
        a, b = b, a
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        curr = [i]
        for j, cb in enumerate(b, 1):
            ins = curr[j - 1] + 1
            dele = prev[j] + 1
            sub = prev[j - 1] + (ca != cb)
            curr.append(min(ins, dele, sub))
        prev = curr
    return prev[-1]


@dataclass
class CaseResult:
    case: str
    source: str
    status: str
    seconds: float
    ref_chars: int
    pred_chars: int
    cer_raw: float | None
    cer_norm: float | None
    error: str | None = None


@dataclass
class ModelSummary:
    model: str
    cases: list[CaseResult]

    def aggregate(self) -> dict:
        successes = [c for c in self.cases if c.status == 'ok']
        failures = [c for c in self.cases if c.status != 'ok']
        secs = [c.seconds for c in self.cases]
        cer_raw = [c.cer_raw for c in successes if c.cer_raw is not None]
        cer_norm = [c.cer_norm for c in successes if c.cer_norm is not None]
        return {
            'model': self.model,
            'num_cases': len(self.cases),
            'num_success': len(successes),
            'num_fail': len(failures),
            'mean_seconds': round(statistics.mean(secs), 3) if secs else None,
            'median_seconds': round(statistics.median(secs), 3) if secs else None,
            'mean_cer_raw': round(statistics.mean(cer_raw), 4) if cer_raw else None,
            'mean_cer_norm': round(statistics.mean(cer_norm), 4) if cer_norm else None,
            'max_cer_norm': round(max(cer_norm), 4) if cer_norm else None,
        }


def require_benchmark_repo() -> Path:
    if REPO_DIR is None or SOURCE_DIR is None or REFERENCE_DIR is None:
        raise SystemExit(
            'Set GLMOCR_BENCHMARK_REPO_DIR to a local GLM-OCR checkout containing examples/source and examples/result.'
        )
    if not SOURCE_DIR.exists() or not REFERENCE_DIR.exists():
        raise SystemExit(
            f'Invalid GLMOCR_BENCHMARK_REPO_DIR: {REPO_DIR} (missing examples/source or examples/result)'
        )
    return REPO_DIR


def resolve_source(case: str) -> Path:
    for ext in ('.png', '.jpg', '.jpeg', '.pdf'):
        p = SOURCE_DIR / f'{case}{ext}'
        if p.exists():
            return p
    raise FileNotFoundError(f'No source file found for case {case}')


def reference_markdown(case: str) -> Path:
    p = REFERENCE_DIR / case / f'{case}.md'
    if not p.exists():
        raise FileNotFoundError(f'No reference markdown found for case {case}: {p}')
    return p


def run_cmd(cmd: list[str], env: dict[str, str]) -> None:
    proc = subprocess.run(cmd, env=env)
    if proc.returncode != 0:
        joined = ' '.join(cmd)
        raise RuntimeError(f'Command failed ({proc.returncode}): {joined}')


def benchmark_model(model: str, cases: list[str], out_dir: Path, port: str) -> ModelSummary:
    env = os.environ.copy()
    env['GLMOCR_MODEL'] = model
    env['GLMOCR_PORT'] = port
    env.setdefault('GLMOCR_HEALTH_TIMEOUT', '180')

    run_cmd([str(OCR_BIN), 'stop'], env)
    results: list[CaseResult] = []

    for case in cases:
        src = resolve_source(case)
        ref_md_path = reference_markdown(case)
        model_case_dir = out_dir / sanitize_model_name(model) / case
        model_case_dir.mkdir(parents=True, exist_ok=True)

        cmd = [
            'bash',
            str(PARSE_SH),
            str(src),
            '--output',
            str(model_case_dir),
            '--no-layout-vis',
        ]
        t0 = time.perf_counter()
        error = None
        try:
            run_cmd(cmd, env)
        except Exception as exc:
            error = str(exc)
        dt = time.perf_counter() - t0

        pred_md_path = model_case_dir / case / f'{case}.md'
        ref_text = ref_md_path.read_text(encoding='utf-8')
        if not pred_md_path.exists():
            results.append(
                CaseResult(
                    case=case,
                    source=str(src),
                    status='failed',
                    seconds=round(dt, 3),
                    ref_chars=len(ref_text),
                    pred_chars=0,
                    cer_raw=None,
                    cer_norm=None,
                    error=error or f'missing output: {pred_md_path}',
                )
            )
            continue

        pred_text = pred_md_path.read_text(encoding='utf-8')
        ref_norm = normalize_text(ref_text)
        pred_norm = normalize_text(pred_text)

        cer_raw = levenshtein(pred_text, ref_text) / max(1, len(ref_text))
        cer_norm = levenshtein(pred_norm, ref_norm) / max(1, len(ref_norm))
        results.append(
            CaseResult(
                case=case,
                source=str(src),
                status='ok',
                seconds=round(dt, 3),
                ref_chars=len(ref_text),
                pred_chars=len(pred_text),
                cer_raw=round(cer_raw, 4),
                cer_norm=round(cer_norm, 4),
            )
        )

    run_cmd([str(OCR_BIN), 'stop'], env)
    return ModelSummary(model=model, cases=results)


def sanitize_model_name(model: str) -> str:
    return model.replace('/', '__')


def write_report(out_dir: Path, summaries: list[ModelSummary], benchmark_repo_dir: Path) -> None:
    data = {
        'generated_at': time.strftime('%Y-%m-%d %H:%M:%S'),
        'repo_dir': str(benchmark_repo_dir),
        'summaries': [
            {
                'aggregate': s.aggregate(),
                'cases': [asdict(c) for c in s.cases],
            }
            for s in summaries
        ],
    }
    (out_dir / 'results.json').write_text(json.dumps(data, indent=2), encoding='utf-8')

    lines = ['# GLM-OCR Quantization Benchmark', '']
    lines.append(f'- benchmark_repo_dir: `{benchmark_repo_dir}`')
    lines.append('')
    lines.append('| Model | Success | Fail | Mean sec | Median sec | Mean CER raw | Mean CER norm | Max CER norm |')
    lines.append('|---|---:|---:|---:|---:|---:|---:|---:|')
    for s in summaries:
        agg = s.aggregate()
        lines.append(
            f"| {agg['model']} | {agg['num_success']} | {agg['num_fail']} | {agg['mean_seconds']} | {agg['median_seconds']} | {agg['mean_cer_raw']} | {agg['mean_cer_norm']} | {agg['max_cer_norm']} |"
        )
    lines.append('')
    for s in summaries:
        lines.append(f'## {s.model}')
        lines.append('')
        lines.append('| Case | Status | Seconds | CER raw | CER norm | Ref chars | Pred chars | Error |')
        lines.append('|---|---|---:|---:|---:|---:|---:|---|')
        for c in s.cases:
            err = (c.error or '').replace('|', '/').replace('\n', ' ')[:120]
            lines.append(
                f'| {c.case} | {c.status} | {c.seconds} | {c.cer_raw} | {c.cer_norm} | {c.ref_chars} | {c.pred_chars} | {err} |'
            )
        lines.append('')
    (out_dir / 'results.md').write_text('\n'.join(lines) + '\n', encoding='utf-8')


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument('--models', nargs='+', default=['bf16', '8bit', '4bit'])
    parser.add_argument('--cases', nargs='+', default=DEFAULT_CASES)
    parser.add_argument('--out-dir', default=str(SKILL_DIR / 'benchmarks' / time.strftime('%Y%m%d-%H%M%S')))
    parser.add_argument('--port', default='8080')
    args = parser.parse_args()

    benchmark_repo_dir = require_benchmark_repo()

    out_dir = Path(args.out_dir).resolve()
    out_dir.mkdir(parents=True, exist_ok=True)

    models = [MODEL_ALIASES.get(m, m) for m in args.models]
    summaries: list[ModelSummary] = []
    for model in models:
        print(f'== Benchmarking {model} ==', flush=True)
        summaries.append(benchmark_model(model, args.cases, out_dir, args.port))

    write_report(out_dir, summaries, benchmark_repo_dir)
    print(f'Wrote report to {out_dir}')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
