`timescale 1ns/1ps

// =====================================================================
// File    : tb_top.sv
// Project : MESI Cache Coherence Protocol — Layered Testbench
// Course  : 23ECE333 — Functional Verification
// Batch   : 12 | AY 2025-2026
// =====================================================================
// Testbench Architecture (UVM-style, without UVM library):
//   Interface → Transaction → Generator → Driver → DUT
//                                                     ↓
//                                        Monitor → Scoreboard
//
// 150 randomised transactions are generated. Each targets one of the
// three CPUs with a random read or write to a random 5-bit address.
// The scoreboard checks that every active transaction results in a
// visible hit or miss (no silent no-ops), logging PASS or FAIL.
// =====================================================================


// =====================================================================
// INTERFACE
// =====================================================================
interface mesi_if (input logic clk);
    logic        rst;
    logic        read_A,  write_A;
    logic        read_B,  write_B;
    logic        read_C,  write_C;
    logic [4:0]  addr_A,  addr_B,  addr_C;
    logic [7:0]  wdata_A, wdata_B, wdata_C;
    logic [1:0]  state_A, state_B, state_C;
    logic        hit_A,   miss_A;
    logic        hit_B,   miss_B;
    logic        hit_C,   miss_C;
    logic [7:0]  rdata_A, rdata_B, rdata_C;
endinterface


// =====================================================================
// TRANSACTION
// =====================================================================
class mesi_transaction;
    rand bit [1:0] cpu;   // 0=A, 1=B, 2=C
    rand bit       rd;
    rand bit       wr;
    rand bit [4:0] addr;
    rand bit [7:0] data;

    constraint valid_op {
        rd != wr;           // exactly one of read/write
        cpu inside {[0:2]};
    }

    function void display(string tag = "TXN");
        $display("[%s] CPU=%0d RD=%0d WR=%0d ADDR=%02h DATA=%02h",
                  tag, cpu, rd, wr, addr, data);
    endfunction
endclass


// =====================================================================
// GENERATOR
// =====================================================================
class generator;
    mailbox gen2drv;

    function new(mailbox gen2drv);
        this.gen2drv = gen2drv;
    endfunction

    task run();
        repeat (150) begin
            mesi_transaction tr;
            tr = new();
            assert(tr.randomize()) else $fatal(1, "Randomization failed");
            tr.display("GEN");
            gen2drv.put(tr);
        end
    endtask
endclass


// =====================================================================
// DRIVER
// =====================================================================
class driver;
    virtual mesi_if vif;
    mailbox gen2drv;

    function new(virtual mesi_if vif, mailbox gen2drv);
        this.vif     = vif;
        this.gen2drv = gen2drv;
    endfunction

    task clear_signals();
        vif.read_A  <= 0; vif.write_A <= 0;
        vif.read_B  <= 0; vif.write_B <= 0;
        vif.read_C  <= 0; vif.write_C <= 0;
    endtask

    task run();
        mesi_transaction tr;
        clear_signals();
        forever begin
            gen2drv.get(tr);
            @(posedge vif.clk);
            // Broadcast address to all (bus model)
            vif.addr_A  <= tr.addr;
            vif.addr_B  <= tr.addr;
            vif.addr_C  <= tr.addr;
            case (tr.cpu)
                0: begin
                    vif.read_A  <= tr.rd;
                    vif.write_A <= tr.wr;
                    vif.wdata_A <= tr.data;
                end
                1: begin
                    vif.read_B  <= tr.rd;
                    vif.write_B <= tr.wr;
                    vif.wdata_B <= tr.data;
                end
                2: begin
                    vif.read_C  <= tr.rd;
                    vif.write_C <= tr.wr;
                    vif.wdata_C <= tr.data;
                end
            endcase
            @(posedge vif.clk);
            clear_signals();
        end
    endtask
endclass


// =====================================================================
// MONITOR
// =====================================================================
class monitor;
    virtual mesi_if vif;
    mailbox mon2scb;

    function new(virtual mesi_if vif, mailbox mon2scb);
        this.vif     = vif;
        this.mon2scb = mon2scb;
    endfunction

    task run();
        mesi_transaction tr;
        forever begin
            @(posedge vif.clk);
            if (vif.read_A || vif.write_A) begin
                tr = new();
                tr.cpu  = 0;
                tr.rd   = vif.read_A;
                tr.wr   = vif.write_A;
                tr.addr = vif.addr_A;
                tr.data = vif.wdata_A;
                mon2scb.put(tr);
            end else if (vif.read_B || vif.write_B) begin
                tr = new();
                tr.cpu  = 1;
                tr.rd   = vif.read_B;
                tr.wr   = vif.write_B;
                tr.addr = vif.addr_B;
                tr.data = vif.wdata_B;
                mon2scb.put(tr);
            end else if (vif.read_C || vif.write_C) begin
                tr = new();
                tr.cpu  = 2;
                tr.rd   = vif.read_C;
                tr.wr   = vif.write_C;
                tr.addr = vif.addr_C;
                tr.data = vif.wdata_C;
                mon2scb.put(tr);
            end
        end
    endtask
endclass


// =====================================================================
// SCOREBOARD
// =====================================================================
class scoreboard;
    virtual mesi_if vif;
    mailbox mon2scb;
    int pass_cnt = 0;
    int fail_cnt = 0;

    function new(virtual mesi_if vif, mailbox mon2scb);
        this.vif     = vif;
        this.mon2scb = mon2scb;
    endfunction

    function string state_name(input logic [1:0] s);
        case (s)
            2'b00: state_name = "I";
            2'b01: state_name = "S";
            2'b10: state_name = "E";
            2'b11: state_name = "M";
        endcase
    endfunction

    task run();
        mesi_transaction tr;
        forever begin
            mon2scb.get(tr);
            @(posedge vif.clk);
            $display("------------------------------------------------");
            tr.display("MON");
            $display("STATE_A=%s HIT=%0d MISS=%0d",
                     state_name(vif.state_A), vif.hit_A, vif.miss_A);
            $display("STATE_B=%s HIT=%0d MISS=%0d",
                     state_name(vif.state_B), vif.hit_B, vif.miss_B);
            $display("STATE_C=%s HIT=%0d MISS=%0d",
                     state_name(vif.state_C), vif.hit_C, vif.miss_C);

            // Pass: any hit or miss was observed (transaction processed)
            if (vif.hit_A  || vif.hit_B  || vif.hit_C  ||
                vif.miss_A || vif.miss_B || vif.miss_C) begin
                pass_cnt++;
                $display("[PASS]");
            end else begin
                fail_cnt++;
                $display("[FAIL]");
            end
        end
    endtask
endclass


// =====================================================================
// ENVIRONMENT
// =====================================================================
class environment;
    generator  gen;
    driver     drv;
    monitor    mon;
    scoreboard scb;

    mailbox gen2drv;
    mailbox mon2scb;
    virtual mesi_if vif;

    function new(virtual mesi_if vif);
        this.vif = vif;
        gen2drv  = new();
        mon2scb  = new();
        gen      = new(gen2drv);
        drv      = new(vif, gen2drv);
        mon      = new(vif, mon2scb);
        scb      = new(vif, mon2scb);
    endfunction

    task run();
        fork
            gen.run();
            drv.run();
            mon.run();
            scb.run();
        join_none
    endtask
endclass


// =====================================================================
// TOP-LEVEL TESTBENCH MODULE
// =====================================================================
module tb;

    logic clk = 0;
    always #5 clk = ~clk;   // 10 ns period → 100 MHz

    mesi_if   vif (clk);
    environment env;

    // ---- DUT instantiation ----
    mesi_system dut (
        .clk     (clk),
        .rst     (vif.rst),
        .read_A  (vif.read_A),  .write_A (vif.write_A),
        .addr_A  (vif.addr_A),  .wdata_A (vif.wdata_A),
        .read_B  (vif.read_B),  .write_B (vif.write_B),
        .addr_B  (vif.addr_B),  .wdata_B (vif.wdata_B),
        .read_C  (vif.read_C),  .write_C (vif.write_C),
        .addr_C  (vif.addr_C),  .wdata_C (vif.wdata_C),
        .state_A (vif.state_A), .state_B (vif.state_B), .state_C (vif.state_C),
        .hit_A   (vif.hit_A),   .miss_A  (vif.miss_A),
        .hit_B   (vif.hit_B),   .miss_B  (vif.miss_B),
        .hit_C   (vif.hit_C),   .miss_C  (vif.miss_C),
        .rdata_A (vif.rdata_A), .rdata_B (vif.rdata_B), .rdata_C (vif.rdata_C)
    );

    // ---- Test ----
    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb);

        env     = new(vif);

        vif.rst = 1;
        #2;
        vif.rst = 0;

        env.run();

        #5000;

        $display("================================");
        $display("  MESI LAYERED TESTBENCH DONE  ");
        $display("  PASS: %0d   FAIL: %0d", env.scb.pass_cnt, env.scb.fail_cnt);
        $display("================================");
        $finish;
    end

endmodule
