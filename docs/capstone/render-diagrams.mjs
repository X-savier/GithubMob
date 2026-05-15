// Render every .mmd in diagrams/ to a PNG inside out/diagrams/.
// Uses the local @mermaid-js/mermaid-cli (mmdc).
import { readdirSync, mkdirSync, existsSync } from "node:fs";
import { spawnSync } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const SRC = path.join(__dirname, "diagrams");
const OUT = path.join(__dirname, "out", "diagrams");

if (!existsSync(OUT)) mkdirSync(OUT, { recursive: true });

const isWin = process.platform === "win32";
const mmdcBin = path.join(
  __dirname,
  "node_modules",
  ".bin",
  isWin ? "mmdc.cmd" : "mmdc"
);

const puppeteerConfig = path.join(__dirname, "puppeteer.json");

// Per-file width override (in pixels). Files not listed here use DEFAULT_WIDTH.
const DEFAULT_WIDTH = 1600;
const WIDTH_OVERRIDES = {
  "424_erd.mmd": 2800, // comprehensive ERD with 28 tables needs more room
};

const files = readdirSync(SRC).filter((f) => f.endsWith(".mmd"));
console.log(`Rendering ${files.length} diagram(s)...`);

let failed = 0;
for (const f of files) {
  const input = path.join(SRC, f);
  const output = path.join(OUT, f.replace(/\.mmd$/, ".png"));
  const width = WIDTH_OVERRIDES[f] || DEFAULT_WIDTH;
  console.log(`  - ${f} -> ${path.basename(output)} (w=${width})`);

  const q = (p) => `"${p}"`;
  const cmd = [
    q(mmdcBin),
    "-i", q(input),
    "-o", q(output),
    "-b", "white",
    "-s", "2",
    "-w", String(width),
    "-p", q(puppeteerConfig),
  ].join(" ");

  const res = spawnSync(cmd, {
    stdio: "inherit",
    shell: true,
  });

  if (res.status !== 0) {
    console.error(`    FAILED: exit ${res.status}`);
    failed += 1;
  }
}

if (failed > 0) {
  console.error(`\n${failed} diagram(s) failed to render.`);
  process.exit(1);
}
console.log("\nAll diagrams rendered.");
