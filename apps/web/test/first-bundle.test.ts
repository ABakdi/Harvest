import { existsSync, readFileSync, statSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';

const src = resolve(dirname(fileURLToPath(import.meta.url)), '../src');

/** The modules a file pulls in at once: static imports only, never `import type` or `import()`. */
function staticImports(file: string): string[] {
  const code = readFileSync(file, 'utf8');
  const found: string[] = [];
  for (const match of code.matchAll(/^import\s+(?!type\s)(?:[^'"]*?\sfrom\s+)?'([^']+)';/gms)) found.push(match[1]!);
  return found;
}

function resolveFrom(file: string, spec: string): string | null {
  const base = spec.startsWith('@/') ? resolve(src, spec.slice(2)) : spec.startsWith('.') ? resolve(dirname(file), spec) : null;
  if (base === null) return null;
  for (const candidate of [base, `${base}.ts`, `${base}.tsx`, resolve(base, 'index.ts')]) {
    if (existsSync(candidate) && statSync(candidate).isFile()) return candidate;
  }
  return null;
}

/** Every source file and package the /app entry loads before the Field can draw. */
function firstBundle(): { files: Set<string>; packages: Set<string> } {
  const files = new Set<string>();
  const packages = new Set<string>();
  const queue = [resolve(src, 'app/app-root.tsx')];
  while (queue.length) {
    const file = queue.pop()!;
    if (files.has(file)) continue;
    files.add(file);
    if (!/\.tsx?$/.test(file)) continue;
    for (const spec of staticImports(file)) {
      const next = resolveFrom(file, spec);
      if (next) queue.push(next);
      else if (!spec.startsWith('.') && !spec.startsWith('@/')) packages.add(spec);
    }
  }
  return { files, packages };
}

describe('the first bundle of /app (P6-10)', () => {
  const { files, packages } = firstBundle();
  const relative = [...files].map((file) => file.slice(src.length + 1));

  it('carries the Field, and none of the screens that load when first opened', () => {
    expect(relative).toContain('app/screens/field.tsx');
    const later = ['archive', 'calendar', 'farmer', 'goal', 'lists', 'onboarding', 'pomodoro', 'seed', 'settings', 'notes', 'places', 'granary', 'body', 'gallery'];
    expect(relative.filter((file) => later.some((screen) => file === `app/screens/${screen}.tsx`))).toEqual([]);
  });

  it('does not carry the gym’s name list or the map', () => {
    expect(relative.filter((file) => file.includes('exercise-names') || file.includes('exercise-catalogue'))).toEqual([]);
    expect([...packages].filter((name) => name.startsWith('maplibre-gl'))).toEqual([]);
  });
});
