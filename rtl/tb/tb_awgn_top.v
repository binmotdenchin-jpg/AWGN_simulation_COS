//======================================================================
// tb_awgn_top.v — Full integration co-sim của awgn_top.v
//----------------------------------------------------------------------
// URNG tự sinh trong DUT (không force). So sánh noise_out với golden_clt.txt.
// Seed phải khớp gen_golden.py: (12345, 67891, 11213).
//======================================================================
`timescale 1ns/1ps

module tb_awgn_top;
    localparam N_OUT = 2000;
    reg clk = 0, rst_n = 0, en = 0;
    always #5 clk = ~clk;

    reg  [15:0] clt_gold [0:N_OUT-1];
    wire signed [15:0] noise;
    wire               nvalid;
    integer i, idx = 0, errors = 0;

    awgn_top #(
        .SEED1(32'd12345), .SEED2(32'd67891), .SEED3(32'd11213),
        .FR_INIT("fr_table.txt"), .G_INIT("g_table.txt")
    ) dut (.clk(clk), .rst_n(rst_n), .en(en),
           .noise_out(noise), .noise_valid(nvalid));

    always @(posedge clk) begin
        if (rst_n && nvalid && idx < N_OUT) begin
            if (noise !== $signed(clt_gold[idx])) begin
                if (errors < 10)
                    $display("TOP MISMATCH idx=%0d got=%0d exp=%0d",
                             idx, noise, $signed(clt_gold[idx]));
                errors = errors + 1;
            end
            idx = idx + 1;
        end
    end

    initial begin
        $readmemh("golden_clt.txt", clt_gold);
        @(negedge clk); rst_n = 0;
        @(negedge clk); rst_n = 1; en = 1;
        // cần N_OUT*A = 8000 URNG cycles + latency
        for (i = 0; i < N_OUT*4 + 50; i = i + 1) @(negedge clk);
        $display("======================================");
        $display(" TOP checked=%0d errors=%0d", idx, errors);
        $display(" RESULT: %s", (errors==0 && idx==N_OUT) ? "PASS" : "FAIL");
        $display("======================================");
        $finish;
    end
endmodule
