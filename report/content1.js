// report.js — nội dung + lắp ráp tài liệu
const L = require('./lib.js');
const {
  fs, Document, Packer, Paragraph, TextRun, Header, Footer, AlignmentType,
  LevelFormat, TableOfContents, HeadingLevel, BorderStyle, ShadingType,
  PageNumber, PageBreak,
  P, runs, H1, H2, H3, bullet, numItem, code, img, table, ACCENT
} = L;

const body = [];
const push = (...x) => x.forEach(e => Array.isArray(e) ? body.push(...e) : body.push(e));

// ============================ TITLE PAGE ============================
push(
  new Paragraph({ spacing:{before:1400, after:120}, alignment:AlignmentType.CENTER,
    children:[new TextRun({ text:"ĐỒ ÁN THIẾT KẾ HỆ THỐNG SỐ", bold:true, size:28, color:ACCENT })] }),
  new Paragraph({ spacing:{after:600}, alignment:AlignmentType.CENTER,
    children:[new TextRun({ text:"AWGN Generator cho Channel Emulation", size:24, color:"555555" })] }),
  new Paragraph({ spacing:{after:120}, alignment:AlignmentType.CENTER, border:{bottom:{style:BorderStyle.SINGLE,size:6,color:ACCENT,space:8}},
    children:[new TextRun({ text:"THIẾT KẾ VÀ KIỂM CHỨNG BỘ SINH NHIỄU GAUSS", bold:true, size:40 })] }),
  new Paragraph({ spacing:{before:120, after:1000}, alignment:AlignmentType.CENTER,
    children:[new TextRun({ text:"theo phương pháp Box-Muller kết hợp Định lý Giới hạn Trung tâm (CLT)", italics:true, size:24 })] }),
  new Paragraph({ spacing:{after:80}, alignment:AlignmentType.CENTER,
    children:[new TextRun({ text:"Đồng thiết kế bit-accurate MATLAB ↔ RTL Verilog", size:22 })] }),
  new Paragraph({ spacing:{after:80}, alignment:AlignmentType.CENTER,
    children:[new TextRun({ text:"Tham chiếu: Boutillon–Danger–Ghazel (ICECS 2000)", size:22 })] }),
  new Paragraph({ spacing:{before:1200, after:60}, alignment:AlignmentType.CENTER,
    children:[new TextRun({ text:"Sinh viên thực hiện: ___________________", size:22 })] }),
  new Paragraph({ spacing:{after:60}, alignment:AlignmentType.CENTER,
    children:[new TextRun({ text:"Giảng viên hướng dẫn: ___________________", size:22 })] }),
  new Paragraph({ spacing:{after:60}, alignment:AlignmentType.CENTER,
    children:[new TextRun({ text:"Năm học 2025–2026", size:22 })] }),
  new Paragraph({ children:[new PageBreak()] }),
);

// ============================ TOC ============================
push(
  new Paragraph({ heading:HeadingLevel.HEADING_1, children:[new TextRun("Mục lục")] }),
  new TableOfContents("Mục lục", { hyperlink:true, headingStyleRange:"1-3" }),
  new Paragraph({ children:[new PageBreak()] }),
);

// ============================ CH1: GIỚI THIỆU ============================
push(
  H1("1. Giới thiệu"),
  H2("1.1. Bối cảnh và động lực"),
  P("Đánh giá hiệu năng của các hệ thống truyền thông số đòi hỏi mô phỏng kênh truyền với số lượng mẫu rất lớn. Để ước lượng tỉ lệ lỗi bit (BER) ở mức 10⁻⁶ với độ tin cậy ±3,3% cần khoảng 10⁹ phép thử. Mô phỏng thuần phần mềm cho khối lượng này tốn rất nhiều thời gian, do đó việc mô phỏng kênh (channel emulation) trên FPGA trở thành giải pháp tăng tốc hiệu quả."),
  P("Thành phần cốt lõi của bộ mô phỏng kênh AWGN (Additive White Gaussian Noise) là bộ sinh nhiễu Gauss. Bộ sinh này phải đạt: phân bố chuẩn N(0,1) với sai số nhỏ trong dải rộng quanh giá trị trung bình, phổ công suất phẳng (tính trắng), chu kỳ lặp lớn, và tốc độ lấy mẫu cao."),
  H2("1.2. Mục tiêu đồ án"),
  P("Đồ án thiết kế và kiểm chứng một bộ sinh AWGN theo phương pháp Box-Muller có hỗ trợ Định lý Giới hạn Trung tâm (CLT) của Boutillon, Danger và Ghazel (ICECS 2000), với các chỉ tiêu:"),
  bullet("Đầu ra Gauss N(0,1), độ lệch nhỏ so với phân bố lý tưởng trong dải ±4σ."),
  bullet("Chu kỳ lặp ≥ 2⁶⁰ (≈ 10¹⁸)."),
  bullet("Phổ công suất phẳng (white noise)."),
  bullet("Tốc độ lấy mẫu ≥ 10 MHz trên FPGA."),
  bullet("Khớp bit-by-bit giữa mô hình MATLAB và RTL Verilog (golden reference)."),
  P("Trọng tâm của đồ án đặt vào phần mô phỏng và kiểm chứng (chương 5), chiếm khoảng 40% nội dung báo cáo, nhằm chứng minh tính đúng đắn thống kê của bộ sinh nhiễu trước khi tổng hợp phần cứng.", { after: 160 }),
  H2("1.3. Sản phẩm bàn giao"),
  table([
    ["Mã","Sản phẩm","Trạng thái"],
    ["D1","Mô hình MATLAB dấu phẩy động (tham chiếu)","Hoàn thành"],
    ["D2","Mô hình MATLAB dấu phẩy tĩnh (bit-accurate, golden)","Hoàn thành"],
    ["D3","RTL Verilog: URNG + Fr/G ROM + BM core + CLT","Hoàn thành"],
    ["D4","Testbench + golden vectors, đồng mô phỏng","Hoàn thành (0 mismatch)"],
    ["D5","Báo cáo mô phỏng: histogram, PSD, autocorr, χ², BER","Hoàn thành"],
    ["D6","Ước lượng tài nguyên tổng hợp FPGA","Hoàn thành (script + ước lượng)"],
    ["D7","Tài liệu kỹ thuật (báo cáo này)","Hoàn thành"],
  ], [1100, 5600, 2660]),
);

// ============================ CH2: CƠ SỞ LÝ THUYẾT ============================
push(
  new Paragraph({ children:[new PageBreak()] }),
  H1("2. Cơ sở lý thuyết"),
  H2("2.1. Phương pháp Box-Muller"),
  P("Phương pháp Box-Muller sinh một mẫu Gauss N(0,1) từ hai biến ngẫu nhiên phân bố đều x₁, x₂ trên [0,1) theo công thức (dạng dùng trong Boutillon):"),
  code("f(x₁) = √(−ln x₁)     g(x₂) = √2 · cos(2π x₂)     n = f(x₁) · g(x₂)"),
  P("Tích f(x₁)·g(x₂) = √(−2 ln x₁) · cos(2π x₂) chính là dạng Box-Muller chuẩn, cho mẫu n ~ N(0,1). Hệ số √2 trong g(x₂) bù cho việc f(x₁) dùng √(−ln) thay vì √(−2ln). Lưu ý này rất quan trọng và sẽ được phân tích lại ở chương 7 (một sai khác phát hiện trong quá trình kiểm chứng)."),
  P("Để hiện thực trên phần cứng, f và g được lượng tử hóa và lưu trong hai bảng tra (ROM):"),
  bullet("Bảng Fr lưu f(x₁) với phân vùng đệ quy (recursive partition) trên [0,1] gồm K=5 mức, mỗi mức 16 đoạn con; m=7 bit phân số; offset δ=0,467."),
  bullet("Bảng G lưu g(x₂) gồm 256 từ; m'=7 bit phân số; offset δ'=0,5; tận dụng tính đối xứng của cosine để chỉ lưu 1/4 chu kỳ."),
  H3("2.1.1. Phân vùng đệ quy của Fr"),
  P("Hàm f(x) = √(−ln x) rất dốc khi x→0 và phẳng khi x→1. Nếu chia đều [0,1] thành 16 đoạn, đoạn gần 0 sẽ có sai số lượng tử rất lớn. Phương pháp Boutillon dùng phân vùng đệ quy, mỗi mức 'zoom' sâu hơn vào vùng x→0 với hệ số 16:"),
  code("Mức 1: [0, 1/16]   Mức 2: [0, 1/256]   ...   Mức 5: [0, 1/16⁵]"),
  P("Số mức K=5 quyết định độ dài đuôi phân bố (tail). K=5 cho đuôi đạt khoảng ±4σ, đủ cho mục tiêu BER 10⁻⁶. Tổng dung lượng bảng Fr chỉ K×16×9 ≈ 90 byte."),
  H2("2.2. Định lý Giới hạn Trung tâm (CLT)"),
  P("Một mẫu Box-Muller đơn lẻ sau lượng tử vẫn còn sai lệch nhỏ so với Gauss. CLT phát biểu rằng tổng của A biến ngẫu nhiên độc lập cùng phân bố sẽ tiến gần Gauss khi A tăng. Vì vậy ta tích lũy A=4 mẫu Box-Muller để 'làm mượt' sai số lượng tử:"),
  code("BM_A = Σ(i=1..A) BMᵢ   →   mean = −A·2^(−B−1),  std = √A"),
  P("Việc chọn A=4 có ba lý do: (1) đủ để CLT làm mượt sai số lượng tử của một mẫu; (2) std = √4 = 2 = 2¹ nên chuẩn hóa về N(0,1) chỉ cần dịch phải 1 bit — 'miễn phí' trong phần cứng; (3) thông lượng vẫn đạt mục tiêu >10 MHz. Phần bù trung bình (mean compensation) cộng A·2^(−B−1)·2^B = A/2 = 2 vào tổng để đưa trung bình về 0."),
  H2("2.3. Bộ sinh số giả ngẫu nhiên đều (URNG) — Tausworthe"),
  P("Hai biến đều x₁, x₂ được lấy từ bộ sinh Tausworthe tổ hợp 3 thành phần của L'Ecuyer (1996), với bậc (k₁,k₂,k₃) = (31, 29, 28). Mỗi thành phần là một thanh ghi dịch phản hồi tuyến tính (LFSR) với hồi quy:"),
  code("b = ((s << q) ^ s) >> (k−p);   s = ((s & MASK) << p) ^ b;   out = s1 ^ s2 ^ s3;"),
  P("Chu kỳ tổ hợp đạt khoảng 2⁸⁸, vượt xa yêu cầu 2⁶⁰. Mỗi thành phần có một mặt nạ (MASK) xóa các bit thấp; do đó hạt giống (seed) phải thỏa s1>1, s2>7, s3>15 để tránh trạng thái suy biến (state = 0 khiến LFSR kẹt)."),
  H2("2.4. Lượng tử hóa và chế độ làm tròn"),
  P("Toàn bộ đường dữ liệu dùng B=6 bit phân số (định dạng Q với 6 bit sau dấu phẩy). Chế độ làm tròn là round-half-up: y = ⌊x + 0,5⌋. Lý do chọn round-half-up: đơn giản trong Verilog (chỉ cộng nửa LSB rồi dịch phải), độ chệch +0,5 LSB được CLT bù lại, và đảm bảo MATLAB và Verilog cho kết quả khớp tuyệt đối. Trong phần cứng, round-half-up tương đương phép dịch số học (arithmetic shift) sau khi cộng hằng số nửa LSB — điều đã được kiểm chứng khớp 100% với ⌊·⌋ của MATLAB cho mọi giá trị có dấu."),
);
module.exports = { body, push };
