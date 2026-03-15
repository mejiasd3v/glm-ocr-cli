import { existsSync, statSync } from 'node:fs'
import { join } from 'node:path'

const required = [
  'README.md',
  'LICENSE',
  'install.sh',
  'bin/ocr',
  'skills/ocr/SKILL.md',
  'skills/ocr/config/selfhosted.example.yaml',
  'skills/ocr/scripts/common.sh',
  'skills/ocr/scripts/setup.sh',
  'skills/ocr/scripts/parse.sh',
  'skills/ocr/scripts/doctor.sh',
  'skills/ocr/scripts/start_server.sh',
  'skills/ocr/scripts/benchmark_quantization.py',
]

let ok = true
for (const rel of required) {
  const path = join(process.cwd(), rel)
  if (!existsSync(path)) {
    console.error(`[validate-layout] missing: ${rel}`)
    ok = false
    continue
  }
  const stat = statSync(path)
  if (!stat.isFile()) {
    console.error(`[validate-layout] not a file: ${rel}`)
    ok = false
  }
}

if (!ok) process.exit(1)
console.log('[validate-layout] ok')
