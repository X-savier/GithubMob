// Top-level generator — builds two .docx files (Chapter 3 + Chapter 4).
// Pre-requisite: `node render-diagrams.mjs` has already produced out/diagrams/*.png.

import { Document, Packer, SectionType } from "docx";
import { writeFileSync, mkdirSync, existsSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  defaultStyles,
  defaultPage,
  landscapePage,
  pageFooter,
  pageHeader,
} from "./lib/docx-helpers.mjs";
import { chapter3 } from "./content/chapter3.mjs";
import { chapter4Portrait, chapter4Landscape } from "./content/chapter4.mjs";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, "out");
if (!existsSync(OUT)) mkdirSync(OUT, { recursive: true });

function makeDoc(title, sections) {
  return new Document({
    creator: "ViewXRent Capstone Generator",
    title,
    description: title,
    styles: defaultStyles(),
    sections: sections.map((sec) => ({
      properties: sec.properties,
      headers: { default: pageHeader("ViewXRent — " + title) },
      footers: { default: pageFooter() },
      children: sec.children,
    })),
  });
}

async function writeDoc(filename, doc) {
  const buf = await Packer.toBuffer(doc);
  const fp = path.join(OUT, filename);
  writeFileSync(fp, buf);
  console.log(`  wrote ${path.relative(__dirname, fp)}  (${(buf.length / 1024).toFixed(1)} KB)`);
}

console.log("Building Chapter 3 ...");
const c3 = chapter3();
console.log(`  ${c3.length} block(s)`);
const doc3 = makeDoc("Chapter III: Technical Background", [
  { properties: defaultPage(), children: c3 },
]);

console.log("Building Chapter 4 ...");
const c4p = chapter4Portrait();
const c4l = chapter4Landscape();
console.log(`  portrait ${c4p.length} block(s) + landscape ${c4l.length} block(s)`);
const doc4 = makeDoc("Chapter IV: Methodology, Results and Discussion", [
  { properties: defaultPage(), children: c4p },
  { properties: landscapePage(), children: c4l },
]);

await writeDoc("Chapter_3_Technical_Background.docx", doc3);
await writeDoc("Chapter_4_Methodology.docx", doc4);

console.log("\nDone.");
