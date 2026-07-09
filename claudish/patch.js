#!/usr/bin/env node
/**
 * Reapplies local fixes to claudish's dist/index.js needed for the
 * Cloudflare Workers AI customEndpoints setup (see ~/.claudish/config.json,
 * profile "cloudflare-glm"), plus a status line fix:
 *
 * 1. ComposedHandler '@' bug: ComposedHandler throws if the modelName it's
 *    constructed with contains '@', but Cloudflare Workers AI model IDs always
 *    start with '@cf/'. The buildSimpleHandler/buildComplexHandler functions
 *    pass the already-prefixed model (finalModel, which contains '@') into
 *    that parameter instead of the bare alias (ctx.modelName). This swaps
 *    that one argument in all 5 ComposedHandler(...) call sites, without
 *    touching the real outbound API request (which still uses finalModel
 *    correctly via the transport/adapter).
 *
 * 2. No ${VAR} interpolation for customEndpoints fields other than apiKey:
 *    claudish only resolves "${VAR}" placeholders for the apiKey field
 *    (resolveCustomEndpointApiKey). Fields like baseUrl/url are validated as
 *    a URL by zod before any substitution, so a placeholder like
 *    ".../accounts/${CLOUDFLARE_ACCOUNT_ID}/ai" would fail schema validation.
 *    This adds a generic interpolateEnvVarsDeep() step in loadCustomEndpoints
 *    that resolves "${VAR}" anywhere in a customEndpoints entry (baseUrl,
 *    url, headers, apiKey, ...) from process.env before the entry is
 *    validated.
 *
 * 3. Forced status line: claudish always injects its own cost-tracking
 *    statusLine into the temp --settings file it passes to `claude` (and
 *    overwrites it even when the user already supplied --settings), which
 *    clobbers our own claude/ccstatusline-settings.json statusLine. This
 *    removes the forced statusLine key entirely so Claude Code falls back
 *    to the statusLine from ~/.claude/settings.json as usual.
 *
 * Safe to re-run: skips patches that are already applied, and re-applies any
 * that were reset by a `npm install -g claudish` upgrade.
 */
"use strict";

const fs = require("fs");
const { execFileSync } = require("child_process");

function findTarget() {
  let root;
  try {
    root = execFileSync("npm", ["root", "-g"], { encoding: "utf-8" }).trim();
  } catch (err) {
    console.error(`ERROR: could not run 'npm root -g': ${err.message}`);
    process.exit(1);
  }
  return `${root}/claudish/dist/index.js`;
}

const REPLACEMENTS = [
  [
    'return new ComposedHandler(transport2, ctx.targetModel, finalModel, ctx.port, {\n' +
      '      adapter: adapter2,\n' +
      '      tokenStrategy: "delta-aware",\n' +
      '      ...ctx.sharedOpts\n' +
      '    });',
    'return new ComposedHandler(transport2, ctx.targetModel, ctx.modelName, ctx.port, {\n' +
      '      adapter: adapter2,\n' +
      '      tokenStrategy: "delta-aware",\n' +
      '      ...ctx.sharedOpts\n' +
      '    });',
  ],
  [
    'return new ComposedHandler(transport, ctx.targetModel, finalModel, ctx.port, {\n' +
      '    adapter,\n' +
      '    ...ctx.sharedOpts\n' +
      '  });',
    'return new ComposedHandler(transport, ctx.targetModel, ctx.modelName, ctx.port, {\n' +
      '    adapter,\n' +
      '    ...ctx.sharedOpts\n' +
      '  });',
  ],
  [
    'return new ComposedHandler(transport, ctx.targetModel, finalModel, ctx.port, {\n' +
      '        adapter,\n' +
      '        ...ctx.sharedOpts\n' +
      '      });',
    'return new ComposedHandler(transport, ctx.targetModel, ctx.modelName, ctx.port, {\n' +
      '        adapter,\n' +
      '        ...ctx.sharedOpts\n' +
      '      });',
  ],
  [
    'return new ComposedHandler(transport, ctx.targetModel, finalModel, ctx.port, {\n' +
      '        adapter,\n' +
      '        tokenStrategy: "delta-aware",\n' +
      '        ...ctx.sharedOpts\n' +
      '      });',
    'return new ComposedHandler(transport, ctx.targetModel, ctx.modelName, ctx.port, {\n' +
      '        adapter,\n' +
      '        tokenStrategy: "delta-aware",\n' +
      '        ...ctx.sharedOpts\n' +
      '      });',
  ],
  [
    'function loadCustomEndpoints(config2) {\n' +
      '  const result = { registered: 0, errors: [] };\n' +
      '  const raw2 = config2.customEndpoints;\n' +
      '  if (!raw2 || typeof raw2 !== "object")\n' +
      '    return result;\n' +
      '  for (const [name, entry] of Object.entries(raw2)) {\n' +
      '    try {\n' +
      '      const validated = CustomEndpointSchema.parse(entry);',
    'function interpolateEnvVarsDeep(value) {\n' +
      '  if (typeof value === "string") {\n' +
      '    return value.replace(/\\$\\{([A-Z_][A-Z0-9_]*)\\}/gi, (match, varName) => {\n' +
      '      const envValue = process.env[varName];\n' +
      '      return envValue !== undefined ? envValue : match;\n' +
      '    });\n' +
      '  }\n' +
      '  if (Array.isArray(value)) {\n' +
      '    return value.map((item) => interpolateEnvVarsDeep(item));\n' +
      '  }\n' +
      '  if (value && typeof value === "object") {\n' +
      '    const result2 = {};\n' +
      '    for (const [key, val] of Object.entries(value)) {\n' +
      '      result2[key] = interpolateEnvVarsDeep(val);\n' +
      '    }\n' +
      '    return result2;\n' +
      '  }\n' +
      '  return value;\n' +
      '}\n' +
      'function loadCustomEndpoints(config2) {\n' +
      '  const result = { registered: 0, errors: [] };\n' +
      '  const raw2 = config2.customEndpoints;\n' +
      '  if (!raw2 || typeof raw2 !== "object")\n' +
      '    return result;\n' +
      '  for (const [name, rawEntry] of Object.entries(raw2)) {\n' +
      '    try {\n' +
      '      const entry = interpolateEnvVarsDeep(rawEntry);\n' +
      '      const validated = CustomEndpointSchema.parse(entry);',
  ],
  [
    'function buildClaudishSettingsOverlay(statusLine, proxyAuthMode) {\n' +
      '  const settings = { statusLine, disableClaudeAiConnectors: true };\n' +
      '  if (proxyAuthMode) {\n' +
      '    settings.forceLoginMethod = "console";\n' +
      '  }\n' +
      '  return settings;\n' +
      '}',
    'function buildClaudishSettingsOverlay(statusLine, proxyAuthMode) {\n' +
      '  const settings = { disableClaudeAiConnectors: true };\n' +
      '  if (proxyAuthMode) {\n' +
      '    settings.forceLoginMethod = "console";\n' +
      '  }\n' +
      '  return settings;\n' +
      '}',
  ],
  [
    '    userSettings.statusLine = statusLine;\n' +
      '    if (!("disableClaudeAiConnectors" in userSettings)) {',
    '    if (!("disableClaudeAiConnectors" in userSettings)) {',
  ],
];

function countOccurrences(haystack, needle) {
  if (needle === "") return 0;
  let count = 0;
  let pos = 0;
  while ((pos = haystack.indexOf(needle, pos)) !== -1) {
    count++;
    pos += needle.length;
  }
  return count;
}

function main() {
  const target = findTarget();

  let data;
  try {
    data = fs.readFileSync(target, "utf-8");
  } catch (err) {
    if (err.code === "ENOENT") {
      console.error(`ERROR: claudish bundle not found at ${target}`);
      process.exit(1);
    }
    throw err;
  }

  let applied = 0;
  let already = 0;
  let missing = 0;

  for (const [oldStr, newStr] of REPLACEMENTS) {
    const count = countOccurrences(data, oldStr);
    if (count === 0) {
      if (countOccurrences(data, newStr) > 0) {
        already++;
      } else {
        missing++;
      }
      continue;
    }
    data = data.split(oldStr).join(newStr);
    applied += count;
  }

  if (applied) {
    fs.writeFileSync(target, data, "utf-8");
    console.log(`Patched ${target}: applied ${applied} fix(es).`);
  } else {
    console.log(`No changes needed in ${target}.`);
  }

  if (already) {
    console.log(`  ${already} site(s) already patched.`);
  }
  if (missing) {
    console.error(
      `  WARNING: ${missing} expected site(s) not found — claudish's source ` +
        "may have changed shape (e.g. after a version upgrade). Re-check " +
        "buildSimpleHandler/buildComplexHandler manually."
    );
    process.exit(2);
  }
}

main();