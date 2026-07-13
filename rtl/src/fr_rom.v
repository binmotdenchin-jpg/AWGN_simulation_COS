//======================================================================
// fr_rom.v — Fr(s) lookup ROM (Boutillon ICECS'00 eq.4)
//----------------------------------------------------------------------
// Bit-exact với MATLAB golden: fr_rom_gen.m + box_muller_fixed.m
//
// Fr(s) = round(2^m * sqrt(-ln((s+delta)/16^r)))   if s>0, else 0
//   (Boutillon eq.1 dùng sqrt(-ln x); hệ số sqrt(2) đã nằm trong G ROM.)
//   K=5 levels (r=1..5), 16 sub-segments (s=0..15)
//   m=7 fraction bits, delta=0.467
//
// Storage: K*16 = 80 words. Layout row-major (r=1 chiếm addr 0..15,
//   r=2 chiếm 16..31, ...) — KHỚP thứ tự ghi của fr_rom_gen.m.
//
// Word width: với Fr = sqrt(-ln x) (Boutillon eq.1), Fr max = 470 -> 9 bits
//   unsigned (Q2.7), đúng 2+m=9 như tài liệu. (Lỗi sqrt(-2ln x) trước đây
//   thổi Fr max lên 665 khiến tưởng cần 10 bit.) Dùng FR_W=9.
//
// Địa chỉ: addr = (r-1)*16 + s   với r in [1..K], s in [0..15]
//   -> truyền r_idx = r-1 (0-based) cho gọn.
//======================================================================
`timescale 1ns/1ps

module fr_rom #(
    parameter K       = 5,
    parameter FR_W    = 9 ,                  // word width (bits)
    parameter DEPTH   = K*16,                // 80
    parameter ADDR_W  = 7,                   // ceil(log2(80)) = 7
    parameter INITFILE = "fr_table.txt"
)(
    input  wire [2:0]        r_idx,          // 0..K-1 (= r-1)
    input  wire [3:0]        s,              // 0..15
    output wire [FR_W-1:0]   fr_val          // unsigned Q2.7
);

    (* rom_style = "block" *)
    reg [FR_W-1:0] rom [0:DEPTH-1];

    initial begin
        $readmemh(INITFILE, rom);
    end

    wire [ADDR_W-1:0] addr = (r_idx << 4) + s;   // r_idx*16 + s
    assign fr_val = rom[addr];

endmodule
