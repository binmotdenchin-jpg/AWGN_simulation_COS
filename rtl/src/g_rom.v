//======================================================================
// g_rom.v — G(s') lookup ROM (Boutillon ICECS'00 eq.5)
//----------------------------------------------------------------------
// Bit-exact với MATLAB golden: g_rom_gen.m + box_muller_fixed.m
//
// G(s') = round(2^m' * sqrt(2) * cos(pi*(s'+delta')/512))
//   s' = 0..255, m'=7, delta'=0.5
//
// Word width: |G| max = 181 -> cần 9 bits signed (Q1.7). Dùng G_W=9.
//   (g_rom_gen.m ghi "1+m'=8" nhưng sqrt(2)*128=181 > 127 nên cần 9b.
//    g_table.txt phải được sinh với word_bits=9 để 2's complement đúng.)
//
// Dữ liệu trong g_table.txt là 2's complement theo word_bits của generator.
// QUAN TRỌNG: regenerate g_table.txt với info.word_bits=9 trước khi nạp,
//   nếu không giá trị âm sẽ sai dấu. Xem note ở cuối generate_rtl.
//======================================================================
`timescale 1ns/1ps

module g_rom #(
    parameter G_W      = 9,                  // signed word width
    parameter DEPTH    = 256,
    parameter ADDR_W   = 8,
    parameter INITFILE = "g_table.txt"
)(
    input  wire [7:0]            s_prime,    // 0..255
    output wire signed [G_W-1:0] g_val       // signed Q1.7
);

    (* rom_style = "block" *)
    reg [G_W-1:0] rom [0:DEPTH-1];

    initial begin
        $readmemh(INITFILE, rom);
    end

    assign g_val = rom[s_prime];   // bits đã ở 2's complement G_W-bit

endmodule
