//======================================================================
// tb_awgn_datapath.v — Bit-accurate co-sim của datapath (BM + ROM + CLT)
//----------------------------------------------------------------------
// Nạp golden_urng.txt, đẩy từng giá trị vào bm_core (qua fr_rom/g_rom),
// so sánh bm_out với golden_bm.txt, và clt_out với golden_clt.txt.
//
// Tách URNG ra để cô lập datapath. Module URNG verify riêng ở tb_urng.v.
//======================================================================
`timescale 1ns/1ps

module tb_awgn_datapath;
    localparam N_URNG = 8000;     // = N_OUT * A
    localparam A      = 4;
    localparam N_OUT  = N_URNG/A;
    localparam FR_W=9 , G_W=9, BM_W=16, OUT_W=16;

    reg clk = 0, rst_n = 0, en = 0;
    always #5 clk = ~clk;

    // golden storage
    reg [31:0] urng_mem [0:N_URNG-1];
    reg [15:0] bm_gold  [0:N_URNG-1];
    reg [15:0] clt_gold [0:N_OUT-1];

    integer i;
    integer bm_errors = 0, clt_errors = 0;
    integer bm_idx = 0, clt_idx = 0;

    // DUT wiring
    reg  [31:0]           urng_in;
    reg                   urng_valid;
    wire [2:0]            r_idx;
    wire [3:0]            s_seg;
    wire [7:0]            s_prime;
    wire [FR_W-1:0]       fr_val;
    wire signed [G_W-1:0] g_val;
    wire signed [BM_W-1:0] bm_out;
    wire                   bm_valid;
    wire signed [OUT_W-1:0] clt_out;
    wire                    clt_valid;

    fr_rom #(.K(5), .FR_W(FR_W), .INITFILE("fr_table.txt")) u_fr (
        .r_idx(r_idx), .s(s_seg), .fr_val(fr_val));

    g_rom #(.G_W(G_W), .INITFILE("g_table.txt")) u_g (
        .s_prime(s_prime), .g_val(g_val));

    bm_core #(.K(5), .FR_W(FR_W), .G_W(G_W), .B(6), .M(7), .M_P(7), .BM_W(BM_W)) u_bm (
        .clk(clk), .rst_n(rst_n), .en(urng_valid), .urng(urng_in),
        .r_idx_o(r_idx), .s_o(s_seg), .s_prime_o(s_prime),
        .fr_val(fr_val), .g_val(g_val), .bm_out(bm_out), .valid(bm_valid));

    clt_acc #(.A(A), .B(6), .BM_W(BM_W), .OUT_W(OUT_W)) u_clt (
        .clk(clk), .rst_n(rst_n), .bm_valid(bm_valid), .bm_in(bm_out),
        .clt_out(clt_out), .out_valid(clt_valid));

    // Compare bm_out against golden when bm_valid
    always @(posedge clk) begin
        if (rst_n && bm_valid) begin
            if (bm_out !== $signed(bm_gold[bm_idx])) begin
                if (bm_errors < 10)
                    $display("BM MISMATCH idx=%0d got=%0d (%04h) exp=%0d (%04h)",
                        bm_idx, bm_out, bm_out[15:0], $signed(bm_gold[bm_idx]), bm_gold[bm_idx]);
                bm_errors = bm_errors + 1;
            end
            bm_idx = bm_idx + 1;
        end
        if (rst_n && clt_valid) begin
            if (clt_out !== $signed(clt_gold[clt_idx])) begin
                if (clt_errors < 10)
                    $display("CLT MISMATCH idx=%0d got=%0d (%04h) exp=%0d (%04h)",
                        clt_idx, clt_out, clt_out[15:0], $signed(clt_gold[clt_idx]), clt_gold[clt_idx]);
                clt_errors = clt_errors + 1;
            end
            clt_idx = clt_idx + 1;
        end
    end

    initial begin
        $readmemh("golden_urng.txt", urng_mem);
        $readmemh("golden_bm.txt",   bm_gold);
        $readmemh("golden_clt.txt",  clt_gold);

        urng_in = 0; urng_valid = 0;
        @(negedge clk); rst_n = 0;
        @(negedge clk); rst_n = 1; en = 1;

        // feed one URNG value per cycle
        for (i = 0; i < N_URNG; i = i + 1) begin
            @(negedge clk);
            urng_in    = urng_mem[i];
            urng_valid = 1;
        end
        @(negedge clk); urng_valid = 0;
        // drain
        repeat (10) @(negedge clk);

        $display("======================================");
        $display(" BM  checked=%0d  errors=%0d", bm_idx, bm_errors);
        $display(" CLT checked=%0d  errors=%0d", clt_idx, clt_errors);
        if (bm_errors==0 && clt_errors==0 && bm_idx==N_URNG && clt_idx==N_OUT)
            $display(" RESULT: PASS — RTL khop golden 100%%");
        else
            $display(" RESULT: FAIL");
        $display("======================================");
        $finish;
    end
endmodule
