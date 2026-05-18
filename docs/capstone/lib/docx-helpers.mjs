// Reusable docx primitives for ViewXRent capstone chapters.
// All chapter content modules build on these.

import {
  Paragraph,
  TextRun,
  HeadingLevel,
  AlignmentType,
  ImageRun,
  Table,
  TableRow,
  TableCell,
  WidthType,
  BorderStyle,
  ShadingType,
  PageNumber,
  Footer,
  Header,
  PageOrientation,
} from "docx";
import { readFileSync } from "node:fs";

// ─── Style constants ────────────────────────────────────────
export const FONT = "Times New Roman";
export const SIZE_BODY = 24; // 12 pt (docx uses half-points)
export const SIZE_H1 = 32;   // 16 pt
export const SIZE_H2 = 28;   // 14 pt
export const SIZE_H3 = 26;   // 13 pt
export const SIZE_CAPTION = 22; // 11 pt
export const COLOR_BODY = "000000";
export const COLOR_HEADING = "0F2A52";

// 1.5 line spacing in docx = 360 twips for spacing.line
export const LINE_15 = { line: 360, lineRule: "auto" };
export const LINE_SINGLE = { line: 240, lineRule: "auto" };

// 1-inch margins (1440 twips = 1 inch)
export const PAGE_MARGINS = {
  top: 1440,
  right: 1440,
  bottom: 1440,
  left: 1440,
};

// ─── Run helpers ────────────────────────────────────────────
export function runBody(text, opts = {}) {
  return new TextRun({
    text,
    font: FONT,
    size: SIZE_BODY,
    color: COLOR_BODY,
    bold: !!opts.bold,
    italics: !!opts.italics,
    break: opts.break,
  });
}

// ─── Paragraph helpers ──────────────────────────────────────
export function para(text, opts = {}) {
  return new Paragraph({
    alignment: opts.alignment || AlignmentType.JUSTIFIED,
    spacing: { ...LINE_15, before: 0, after: 120 },
    indent: opts.firstLineIndent ? { firstLine: 720 } : undefined, // 0.5"
    children: Array.isArray(text)
      ? text
      : [runBody(text, { bold: opts.bold, italics: opts.italics })],
  });
}

// Build a paragraph from a string that may contain **bold** segments.
export function richPara(text, opts = {}) {
  const segments = [];
  const re = /\*\*([^*]+?)\*\*/g;
  let last = 0;
  let m;
  while ((m = re.exec(text)) !== null) {
    if (m.index > last) segments.push(runBody(text.slice(last, m.index)));
    segments.push(runBody(m[1], { bold: true }));
    last = m.index + m[0].length;
  }
  if (last < text.length) segments.push(runBody(text.slice(last)));
  return new Paragraph({
    alignment: opts.alignment || AlignmentType.JUSTIFIED,
    spacing: { ...LINE_15, before: 0, after: 120 },
    indent: opts.firstLineIndent ? { firstLine: 720 } : undefined,
    children: segments,
  });
}

export function blank() {
  return new Paragraph({
    spacing: { ...LINE_15, before: 0, after: 0 },
    children: [runBody("")],
  });
}

// ─── Heading helpers ────────────────────────────────────────
export function chapterTitle(text) {
  return new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { ...LINE_SINGLE, before: 0, after: 360 },
    children: [
      new TextRun({
        text,
        font: FONT,
        size: SIZE_H1,
        bold: true,
        color: COLOR_HEADING,
        allCaps: true,
      }),
    ],
  });
}

export function sectionHeading(text) {
  return new Paragraph({
    alignment: AlignmentType.LEFT,
    spacing: { ...LINE_SINGLE, before: 280, after: 160 },
    children: [
      new TextRun({
        text,
        font: FONT,
        size: SIZE_H2,
        bold: true,
        color: COLOR_HEADING,
      }),
    ],
  });
}

export function subsectionHeading(text) {
  return new Paragraph({
    alignment: AlignmentType.LEFT,
    spacing: { ...LINE_SINGLE, before: 240, after: 140 },
    children: [
      new TextRun({
        text,
        font: FONT,
        size: SIZE_H3,
        bold: true,
        color: COLOR_HEADING,
      }),
    ],
  });
}

// Bold inline-style heading for Hardware/Software/Peopleware/Network groupings.
export function inlineHeading(text) {
  return new Paragraph({
    alignment: AlignmentType.LEFT,
    spacing: { ...LINE_SINGLE, before: 180, after: 100 },
    children: [
      new TextRun({
        text,
        font: FONT,
        size: SIZE_BODY,
        bold: true,
        color: COLOR_BODY,
      }),
    ],
  });
}

// ─── Bullet helpers ─────────────────────────────────────────
export function bullet(text, level = 0) {
  return new Paragraph({
    alignment: AlignmentType.JUSTIFIED,
    spacing: { ...LINE_15, before: 0, after: 80 },
    bullet: { level },
    children: [runBody(text)],
  });
}

// Bold lead + rest. Example: bulletLead("Stripe", " — payment gateway used in sandbox mode.")
export function bulletLead(lead, rest, level = 0) {
  return new Paragraph({
    alignment: AlignmentType.JUSTIFIED,
    spacing: { ...LINE_15, before: 0, after: 80 },
    bullet: { level },
    children: [runBody(lead, { bold: true }), runBody(rest)],
  });
}

// ─── Image / figure helpers ─────────────────────────────────
function pngSize(buf) {
  return { width: buf.readUInt32BE(16), height: buf.readUInt32BE(20) };
}

// Embed a PNG diagram scaled so that the width fits the page text area.
// Caps width at maxWidth pixels (default ~575px ≈ 6 inches at 96 DPI).
// Then adds a centered, italic figure caption underneath.
export function figure(pngPath, figureNumber, caption, opts = {}) {
  const buf = readFileSync(pngPath);
  const { width: w, height: h } = pngSize(buf);
  const maxW = opts.maxWidth || 575;
  const maxH = opts.maxHeight || 720; // ~7.5 inches tall

  let outW = w;
  let outH = h;
  if (outW > maxW) {
    outH = Math.round(outH * (maxW / outW));
    outW = maxW;
  }
  if (outH > maxH) {
    outW = Math.round(outW * (maxH / outH));
    outH = maxH;
  }

  const imageParagraph = new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { ...LINE_SINGLE, before: 200, after: 60 },
    children: [
      new ImageRun({
        data: buf,
        transformation: { width: outW, height: outH },
        type: "png",
      }),
    ],
  });

  const captionParagraph = new Paragraph({
    alignment: AlignmentType.CENTER,
    spacing: { ...LINE_SINGLE, before: 0, after: 240 },
    children: [
      new TextRun({
        text: `Figure ${figureNumber}. `,
        font: FONT,
        size: SIZE_CAPTION,
        bold: true,
        italics: true,
      }),
      new TextRun({
        text: caption,
        font: FONT,
        size: SIZE_CAPTION,
        italics: true,
      }),
    ],
  });

  return [imageParagraph, captionParagraph];
}

// ─── Table helpers ──────────────────────────────────────────
const BORDER = { style: BorderStyle.SINGLE, size: 4, color: "888888" };
const ALL_BORDERS = {
  top: BORDER, bottom: BORDER, left: BORDER, right: BORDER,
  insideHorizontal: BORDER, insideVertical: BORDER,
};

function cell(text, opts = {}) {
  const runs = Array.isArray(text)
    ? text
    : [
        new TextRun({
          text: text || "",
          font: FONT,
          size: opts.size || 22, // 11pt for tables
          bold: !!opts.bold,
          italics: !!opts.italics,
          color: opts.color || COLOR_BODY,
        }),
      ];
  return new TableCell({
    children: [
      new Paragraph({
        alignment: opts.alignment || AlignmentType.LEFT,
        spacing: { ...LINE_SINGLE, before: 60, after: 60 },
        children: runs,
      }),
    ],
    width: opts.width
      ? { size: opts.width, type: WidthType.PERCENTAGE }
      : undefined,
    shading: opts.shaded
      ? { type: ShadingType.CLEAR, fill: "EAF1FB", color: "auto" }
      : undefined,
  });
}

export function table(headerRow, dataRows, columnWidths) {
  const rows = [];
  rows.push(
    new TableRow({
      tableHeader: true,
      children: headerRow.map((h, i) =>
        cell(h, {
          bold: true,
          shaded: true,
          alignment: AlignmentType.CENTER,
          width: columnWidths?.[i],
        })
      ),
    })
  );
  for (const r of dataRows) {
    rows.push(
      new TableRow({
        children: r.map((c, i) => cell(c, { width: columnWidths?.[i] })),
      })
    );
  }
  return new Table({
    rows,
    width: { size: 100, type: WidthType.PERCENTAGE },
    borders: ALL_BORDERS,
  });
}

// Tighter, two-column "definition" table for use case narratives.
export function ucTable(rows) {
  return new Table({
    rows: rows.map(([k, v]) =>
      new TableRow({
        children: [
          cell(k, { bold: true, shaded: true, width: 25 }),
          cell(v, { width: 75 }),
        ],
      })
    ),
    width: { size: 100, type: WidthType.PERCENTAGE },
    borders: ALL_BORDERS,
  });
}

// ─── Document scaffolding ───────────────────────────────────
export function defaultStyles() {
  return {
    default: {
      document: {
        run: { font: FONT, size: SIZE_BODY, color: COLOR_BODY },
        paragraph: { spacing: LINE_15 },
      },
    },
    paragraphStyles: [],
  };
}

export function defaultPage() {
  return {
    page: {
      margin: PAGE_MARGINS,
      size: {
        orientation: PageOrientation.PORTRAIT,
        width: 12240, // 8.5"
        height: 15840, // 11"
      },
    },
  };
}

// Landscape variant: swap width/height and orientation. Margins kept at 1"
// per the capstone format. Used for the comprehensive ERD page.
export function landscapePage() {
  return {
    page: {
      margin: PAGE_MARGINS,
      size: {
        orientation: PageOrientation.LANDSCAPE,
        width: 15840,  // 11"
        height: 12240, // 8.5"
      },
    },
  };
}

export function pageFooter() {
  return new Footer({
    children: [
      new Paragraph({
        alignment: AlignmentType.CENTER,
        children: [
          new TextRun({
            children: [PageNumber.CURRENT],
            font: FONT,
            size: SIZE_CAPTION,
          }),
        ],
      }),
    ],
  });
}

export function pageHeader(text) {
  return new Header({
    children: [
      new Paragraph({
        alignment: AlignmentType.RIGHT,
        children: [
          new TextRun({
            text,
            font: FONT,
            size: SIZE_CAPTION,
            italics: true,
            color: "555555",
          }),
        ],
      }),
    ],
  });
}
