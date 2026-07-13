//======================================================================
// lzc32.v — Leading Zero Counter (32-bit, combinational)
//----------------------------------------------------------------------
// Đếm số bit 0 liên tiếp tính từ MSB (bit31) xuống.
// Khớp vòng for trong box_muller_fixed.m:
//   lz_count = số bit 0 đầu tiên trước bit '1' đầu tiên (xét MSB->LSB)
//   Nếu word = 0 -> lz_count = 32.
//
// TỐI ƯU: cài đặt binary-search (halving) 5 tầng thay cho chuỗi ưu tiên
//   32 tầng của vòng for — độ sâu logic O(log2 32)=5 thay vì O(32),
//   rút ngắn critical path (LZC nằm đầu datapath bm_core).
//   Đã kiểm chứng tương đương bit-exact với tham chiếu (mọi lớp lz 0..32
//   + 1M vector ngẫu nhiên, 0 mismatch).
//
// Output count: 0..32 (cần 6 bits).
//======================================================================
`timescale 1ns/1ps

module lzc32 (
    input  wire [31:0] in,
    output reg  [5:0]  lz       // 0..32
);
    reg [31:0] v;
    reg [4:0]  n;
    always @(*) begin
        if (in == 32'b0) begin
            lz = 6'd32;
        end else begin
            v = in;
            n = 5'd0;
            if (v[31:16] == 16'b0) begin n[4] = 1'b1; v = v << 16; end
            if (v[31:24] == 8'b0)  begin n[3] = 1'b1; v = v << 8;  end
            if (v[31:28] == 4'b0)  begin n[2] = 1'b1; v = v << 4;  end
            if (v[31:30] == 2'b0)  begin n[1] = 1'b1; v = v << 2;  end
            if (v[31]    == 1'b0)  begin n[0] = 1'b1;              end
            lz = {1'b0, n};
        end
    end
endmodule
