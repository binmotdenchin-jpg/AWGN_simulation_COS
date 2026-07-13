//======================================================================
// tb_urng.v — Verify taus_urng.v khớp golden_urng.txt
//======================================================================
`timescale 1ns/1ps

module tb_urng;
    localparam N = 8000;
    reg clk = 0, rst_n = 0, en = 0;
    always #5 clk = ~clk;

    reg [31:0] gold [0:N-1];
    wire [31:0] rng;
    wire        valid;
    integer i, idx = 0, errors = 0;

    taus_urng #(
        .SEED1(32'd12345), .SEED2(32'd67891), .SEED3(32'd11213)
    ) dut (.clk(clk), .rst_n(rst_n), .en(en), .rng_out(rng), .valid(valid));

    always @(posedge clk) begin
        if (rst_n && valid && idx < N) begin
            if (rng !== gold[idx]) begin
                if (errors < 10)
                    $display("URNG MISMATCH idx=%0d got=%08h exp=%08h", idx, rng, gold[idx]);
                errors = errors + 1;
            end
            idx = idx + 1;
        end
    end

    initial begin
        $readmemh("golden_urng.txt", gold);
        @(negedge clk); rst_n = 0;
        @(negedge clk); rst_n = 1; en = 1;
        for (i = 0; i < N+2; i = i + 1) @(negedge clk);
        repeat(3) @(negedge clk);
        $display("======================================");
        $display(" URNG checked=%0d errors=%0d", idx, errors);
        $display(" RESULT: %s", (errors==0 && idx>=N) ? "PASS" : "FAIL");
        $display("======================================");
        $finish;
    end
endmodule
