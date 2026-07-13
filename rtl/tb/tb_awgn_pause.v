//======================================================================
// tb_awgn_pause.v — Kiểm tra tạm dừng pipeline (en toggling)
//----------------------------------------------------------------------
// Chuỗi output KHÔNG được phụ thuộc vào việc en tạm dừng giữa chừng:
// pause chỉ kéo dài thời gian, không được làm sai/mất/trùng mẫu.
// So sánh noise_out với cùng golden_clt.txt của tb_awgn_top.
//
// Test này bắt được lỗi valid "dính mức 1" của taus_urng phiên bản cũ
// (khi en=0, valid vẫn 1 -> clt_acc tích lũy trùng mẫu cũ).
//
// Chạy cả hai cấu hình: PIPE=0 (mặc định) và PIPE=1 (2-stage bm_core).
//======================================================================
`timescale 1ns/1ps

module tb_awgn_pause;
    localparam N_OUT = 2000;
    reg clk = 0, rst_n = 0, en = 0;
    always #5 clk = ~clk;

    reg [15:0] clt_gold [0:N_OUT-1];

    // ---- DUT 0: PIPE=0 ----
    wire signed [15:0] noise0;
    wire               nvalid0;
    awgn_top #(
        .SEED1(32'd12345), .SEED2(32'd67891), .SEED3(32'd11213), .PIPE(0),
        .FR_INIT("fr_table.txt"), .G_INIT("g_table.txt")
    ) dut0 (.clk(clk), .rst_n(rst_n), .en(en),
            .noise_out(noise0), .noise_valid(nvalid0));

    // ---- DUT 1: PIPE=1 ----
    wire signed [15:0] noise1;
    wire               nvalid1;
    awgn_top #(
        .SEED1(32'd12345), .SEED2(32'd67891), .SEED3(32'd11213), .PIPE(1),
        .FR_INIT("fr_table.txt"), .G_INIT("g_table.txt")
    ) dut1 (.clk(clk), .rst_n(rst_n), .en(en),
            .noise_out(noise1), .noise_valid(nvalid1));

    integer idx0 = 0, err0 = 0;
    integer idx1 = 0, err1 = 0;

    always @(posedge clk) begin
        if (rst_n && nvalid0 && idx0 < N_OUT) begin
            if (noise0 !== $signed(clt_gold[idx0])) begin
                if (err0 < 10)
                    $display("PIPE0 MISMATCH idx=%0d got=%0d exp=%0d",
                             idx0, noise0, $signed(clt_gold[idx0]));
                err0 = err0 + 1;
            end
            idx0 = idx0 + 1;
        end
        if (rst_n && nvalid1 && idx1 < N_OUT) begin
            if (noise1 !== $signed(clt_gold[idx1])) begin
                if (err1 < 10)
                    $display("PIPE1 MISMATCH idx=%0d got=%0d exp=%0d",
                             idx1, noise1, $signed(clt_gold[idx1]));
                err1 = err1 + 1;
            end
            idx1 = idx1 + 1;
        end
    end

    integer cyc;
    initial begin
        $readmemh("golden_clt.txt", clt_gold);
        @(negedge clk); rst_n = 0; en = 0;
        @(negedge clk); rst_n = 1;
        // en pattern: chạy 80 cycles, dừng 20 cycles, lặp lại
        for (cyc = 0; cyc < N_OUT*4*2 + 200; cyc = cyc + 1) begin
            en = ((cyc % 100) < 80);
            @(negedge clk);
        end
        en = 0;
        repeat (10) @(negedge clk);

        $display("======================================");
        $display(" PAUSE test  PIPE=0: checked=%0d errors=%0d", idx0, err0);
        $display(" PAUSE test  PIPE=1: checked=%0d errors=%0d", idx1, err1);
        if (err0==0 && err1==0 && idx0==N_OUT && idx1==N_OUT)
            $display(" RESULT: PASS — pipeline chịu được tạm dừng en");
        else
            $display(" RESULT: FAIL");
        $display("======================================");
        $finish;
    end
endmodule
