// make.js — lắp ráp Document và ghi report.docx
const fs = require('fs');
const {
  Document, Packer, Paragraph, TextRun, Header, Footer, AlignmentType,
  LevelFormat, HeadingLevel, BorderStyle, PageNumber, ShadingType
} = require('docx');

// require theo thứ tự để body được đổ đầy (content1 chạy trước, rồi content2)
const { body } = require('./content1.js');
require('./content2.js');   // đẩy tiếp chương 3–7 vào cùng body

const ACCENT = "1F4E79";

const doc = new Document({
  creator: "AWGN Project",
  title: "Báo cáo đồ án AWGN Generator",
  styles: {
    default: { document: { run: { font: "Arial", size: 22 } } },  // 11pt
    paragraphStyles: [
      { id:"Heading1", name:"Heading 1", basedOn:"Normal", next:"Normal", quickFormat:true,
        run:{ size:30, bold:true, font:"Arial", color:ACCENT },
        paragraph:{ spacing:{ before:280, after:160 }, outlineLevel:0,
          border:{ bottom:{ style:BorderStyle.SINGLE, size:4, color:"D5E8F0", space:4 } } } },
      { id:"Heading2", name:"Heading 2", basedOn:"Normal", next:"Normal", quickFormat:true,
        run:{ size:26, bold:true, font:"Arial", color:"2E5C8A" },
        paragraph:{ spacing:{ before:200, after:120 }, outlineLevel:1 } },
      { id:"Heading3", name:"Heading 3", basedOn:"Normal", next:"Normal", quickFormat:true,
        run:{ size:23, bold:true, font:"Arial", color:"333333" },
        paragraph:{ spacing:{ before:140, after:100 }, outlineLevel:2 } },
    ]
  },
  numbering: {
    config: [
      { reference:"b", levels:[{ level:0, format:LevelFormat.BULLET, text:"•",
        alignment:AlignmentType.LEFT, style:{ paragraph:{ indent:{ left:720, hanging:360 } } } }] },
      { reference:"n", levels:[{ level:0, format:LevelFormat.DECIMAL, text:"%1.",
        alignment:AlignmentType.LEFT, style:{ paragraph:{ indent:{ left:720, hanging:360 } } } }] },
      { reference:"r", levels:[{ level:0, format:LevelFormat.DECIMAL, text:"[%1]",
        alignment:AlignmentType.LEFT, style:{ paragraph:{ indent:{ left:600, hanging:420 } } } }] },
    ]
  },
  sections: [{
    properties: {
      page: {
        size: { width:12240, height:15840 },           // US Letter
        margin: { top:1440, right:1440, bottom:1440, left:1440 }
      }
    },
    headers: { default: new Header({ children:[ new Paragraph({
      alignment: AlignmentType.RIGHT,
      border:{ bottom:{ style:BorderStyle.SINGLE, size:4, color:"CCCCCC", space:4 } },
      children:[ new TextRun({ text:"Bộ sinh AWGN — Box-Muller + CLT", size:16, color:"888888" }) ] }) ] }) },
    footers: { default: new Footer({ children:[ new Paragraph({
      alignment: AlignmentType.CENTER,
      children:[ new TextRun({ text:"Trang ", size:18 }),
                 new TextRun({ children:[PageNumber.CURRENT], size:18 }),
                 new TextRun({ text:" / ", size:18 }),
                 new TextRun({ children:[PageNumber.TOTAL_PAGES], size:18 }) ] }) ] }) },
    children: body
  }]
});

Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync("/home/claude/report/report.docx", buf);
  console.log("✓ report.docx written,", buf.length, "bytes");
}).catch(e => { console.error("ERROR:", e); process.exit(1); });
