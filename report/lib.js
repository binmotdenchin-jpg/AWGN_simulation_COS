// build_report.js — Báo cáo đồ án AWGN Generator (D7)
const fs = require('fs');
const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell, ImageRun,
  Header, Footer, AlignmentType, LevelFormat, TabStopType, TabStopPosition,
  TableOfContents, HeadingLevel, BorderStyle, WidthType, ShadingType,
  VerticalAlign, PageNumber, PageBreak
} = require('docx');

const FIG = '/home/claude/report';
const ACCENT = "1F4E79", LIGHT = "D5E8F0", GREY = "F2F2F2";

// ---------- helpers ----------
const P = (text, opts={}) => new Paragraph({
  spacing: { after: opts.after ?? 120, line: 276, ...(opts.spacing||{}) },
  alignment: opts.align,
  children: [new TextRun({ text, ...opts })],
  ...(opts.pPr||{})
});
const runs = (arr, opts={}) => new Paragraph({
  spacing: { after: opts.after ?? 120, line: 276 }, alignment: opts.align,
  children: arr.map(r => r instanceof TextRun ? r : new TextRun(r))
});
const H1 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_1, children:[new TextRun(t)] });
const H2 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_2, children:[new TextRun(t)] });
const H3 = (t) => new Paragraph({ heading: HeadingLevel.HEADING_3, children:[new TextRun(t)] });
const bullet = (t, lvl=0) => new Paragraph({
  numbering:{reference:"b", level:lvl}, spacing:{after:80, line:264},
  children:[new TextRun(t)] });
const numItem = (t) => new Paragraph({
  numbering:{reference:"n", level:0}, spacing:{after:80, line:264},
  children:[new TextRun(t)] });
const code = (t) => new Paragraph({
  spacing:{after:120}, shading:{fill:GREY, type:ShadingType.CLEAR},
  children:[new TextRun({ text:t, font:"Consolas", size:18 })] });

function img(file, w, h, caption) {
  const out = [ new Paragraph({
    alignment: AlignmentType.CENTER, spacing:{before:120, after:60},
    children:[ new ImageRun({ type:"png", data: fs.readFileSync(`${FIG}/${file}`),
      transformation:{ width:w, height:h },
      altText:{title:caption, description:caption, name:file} }) ] }) ];
  out.push(new Paragraph({ alignment:AlignmentType.CENTER, spacing:{after:200},
    children:[ new TextRun({ text:caption, italics:true, size:18, color:"555555" }) ] }));
  return out;
}

const border = { style: BorderStyle.SINGLE, size: 1, color: "BBBBBB" };
const borders = { top:border, bottom:border, left:border, right:border };
function tcell(text, w, {head=false, bold=false, align}={}) {
  return new TableCell({ borders, width:{size:w, type:WidthType.DXA},
    shading:{ fill: head?LIGHT:"FFFFFF", type:ShadingType.CLEAR },
    margins:{top:60, bottom:60, left:100, right:100},
    verticalAlign: VerticalAlign.CENTER,
    children:[ new Paragraph({ alignment:align,
      children:[ new TextRun({ text:String(text), bold:bold||head, size:19 }) ] }) ] });
}
function table(rows, widths) {
  const total = widths.reduce((a,b)=>a+b,0);
  return new Table({ width:{size:total, type:WidthType.DXA}, columnWidths:widths,
    rows: rows.map((r,ri)=> new TableRow({ tableHeader: ri===0,
      children: r.map((c,ci)=> typeof c==='object' && c.cell
        ? tcell(c.cell, widths[ci], {...c, head: ri===0})
        : tcell(c, widths[ci], { head: ri===0,
            align: ci===0?AlignmentType.LEFT:AlignmentType.CENTER }) ) })) });
}
const figcap = []; // not used; captions inline

module.exports = { fs, Document, Packer, Paragraph, TextRun, Header, Footer,
  AlignmentType, LevelFormat, TableOfContents, HeadingLevel, BorderStyle,
  WidthType, ShadingType, PageNumber, PageBreak, VerticalAlign,
  P, runs, H1, H2, H3, bullet, numItem, code, img, table, ACCENT };
