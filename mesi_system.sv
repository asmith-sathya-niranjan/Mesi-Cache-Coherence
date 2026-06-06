// =====================================================================
// Module  : mesi_system
// Project : MESI Cache Coherence Protocol
// Course  : 23ECE333 — Functional Verification
// Batch   : 12 | AY 2025-2026
// =====================================================================
// Description:
//   Top-level system integrating three mesi_cache instances (A, B, C),
//   one shared memory, and a bus controller.
//
//   Bus arbitration: fixed priority  A > B > C
//   Cache-to-cache transfer: if a Modified copy exists in another cache,
//   its data is forwarded directly (avoids stale-memory read).
//   Write-back: handled by the bus controller before new data is loaded.
// =====================================================================

module mesi_system (
    input  logic        clk,
    input  logic        rst,

    // Processor A
    input  logic        read_A,  write_A,
    input  logic [4:0]  addr_A,
    input  logic [7:0]  wdata_A,

    // Processor B
    input  logic        read_B,  write_B,
    input  logic [4:0]  addr_B,
    input  logic [7:0]  wdata_B,

    // Processor C
    input  logic        read_C,  write_C,
    input  logic [4:0]  addr_C,
    input  logic [7:0]  wdata_C,

    // Outputs
    output logic [1:0]  state_A, state_B, state_C,
    output logic        hit_A,   miss_A,
    output logic        hit_B,   miss_B,
    output logic        hit_C,   miss_C,
    output logic [7:0]  rdata_A, rdata_B, rdata_C
);

    // ---- Bus arbitration (priority A > B > C) ----
    logic grant_A, grant_B, grant_C;
    assign grant_A = (read_A | write_A);
    assign grant_B = ~grant_A & (read_B | write_B);
    assign grant_C = ~grant_A & ~grant_B & (read_C | write_C);

    logic [4:0] bus_addr;
    assign bus_addr = grant_A ? addr_A :
                      grant_B ? addr_B : addr_C;

    logic snoop_read, snoop_write;
    assign snoop_read  = (grant_A & read_A)  | (grant_B & read_B)  | (grant_C & read_C);
    assign snoop_write = (grant_A & write_A) | (grant_B & write_B) | (grant_C & write_C);

    // ---- Cache internal state (exposed for bus logic) ----
    logic        valid_A, valid_B, valid_C;
    logic [1:0]  tag_A,   tag_B,   tag_C;
    logic [7:0]  data_A,  data_B,  data_C;

    logic        wb_A,  wb_B,  wb_C;
    logic [4:0]  wba_A, wba_B, wba_C;
    logic [7:0]  wbd_A, wbd_B, wbd_C;

    // ---- Memory interface ----
    logic        mem_read_en, mem_write_en;
    logic [4:0]  mem_addr;
    logic [7:0]  mem_wdata, mem_rdata;

    assign mem_read_en  = grant_A | grant_B | grant_C;
    assign mem_write_en = wb_A | wb_B | wb_C;
    assign mem_addr     = wb_A ? wba_A :
                          wb_B ? wba_B :
                          wb_C ? wba_C : bus_addr;
    assign mem_wdata    = wb_A ? wbd_A :
                          wb_B ? wbd_B : wbd_C;

    memory mem_unit (
        .clk       (clk),
        .mem_read  (mem_read_en),
        .mem_write (mem_write_en),
        .addr      (mem_addr),
        .wdata     (mem_wdata),
        .rdata     (mem_rdata)
    );

    // ---- Shared-line detection ----
    logic shared_A, shared_B, shared_C;
    assign shared_A = grant_A & ((valid_B & (tag_B == addr_A[4:3])) |
                                  (valid_C & (tag_C == addr_A[4:3])));
    assign shared_B = grant_B & ((valid_A & (tag_A == addr_B[4:3])) |
                                  (valid_C & (tag_C == addr_B[4:3])));
    assign shared_C = grant_C & ((valid_A & (tag_A == addr_C[4:3])) |
                                  (valid_B & (tag_B == addr_C[4:3])));

    // ---- Cache-to-cache fill data ----
    // Priority: Modified copy > Exclusive/Shared copy > main memory
    logic [7:0] c2c_A, c2c_B, c2c_C;

    assign c2c_A = (valid_B & (tag_B == addr_A[4:3]) & (state_B == 2'b11)) ? data_B :
                   (valid_C & (tag_C == addr_A[4:3]) & (state_C == 2'b11)) ? data_C :
                   (valid_B & (tag_B == addr_A[4:3]))                        ? data_B :
                   (valid_C & (tag_C == addr_A[4:3]))                        ? data_C : mem_rdata;

    assign c2c_B = (valid_A & (tag_A == addr_B[4:3]) & (state_A == 2'b11)) ? data_A :
                   (valid_C & (tag_C == addr_B[4:3]) & (state_C == 2'b11)) ? data_C :
                   (valid_A & (tag_A == addr_B[4:3]))                        ? data_A :
                   (valid_C & (tag_C == addr_B[4:3]))                        ? data_C : mem_rdata;

    assign c2c_C = (valid_A & (tag_A == addr_C[4:3]) & (state_A == 2'b11)) ? data_A :
                   (valid_B & (tag_B == addr_C[4:3]) & (state_B == 2'b11)) ? data_B :
                   (valid_A & (tag_A == addr_C[4:3]))                        ? data_A :
                   (valid_B & (tag_B == addr_C[4:3]))                        ? data_B : mem_rdata;

    // ---- Cache instances ----
    mesi_cache cache_A (
        .clk(clk), .rst(rst),
        .cpu_read(grant_A & read_A),  .cpu_write(grant_A & write_A),
        .cpu_addr(addr_A),             .cpu_wdata(wdata_A),
        .snoop_read(snoop_read  & ~grant_A),
        .snoop_write(snoop_write & ~grant_A),
        .bus_addr(bus_addr), .shared_line(shared_A), .fill_data(c2c_A),
        .wb_req(wb_A), .wb_addr(wba_A), .wb_data(wbd_A),
        .hit(hit_A), .miss(miss_A), .cpu_rdata(rdata_A),
        .state_out(state_A), .valid_out(valid_A), .tag_out(tag_A), .data_out(data_A)
    );

    mesi_cache cache_B (
        .clk(clk), .rst(rst),
        .cpu_read(grant_B & read_B),  .cpu_write(grant_B & write_B),
        .cpu_addr(addr_B),             .cpu_wdata(wdata_B),
        .snoop_read(snoop_read  & ~grant_B),
        .snoop_write(snoop_write & ~grant_B),
        .bus_addr(bus_addr), .shared_line(shared_B), .fill_data(c2c_B),
        .wb_req(wb_B), .wb_addr(wba_B), .wb_data(wbd_B),
        .hit(hit_B), .miss(miss_B), .cpu_rdata(rdata_B),
        .state_out(state_B), .valid_out(valid_B), .tag_out(tag_B), .data_out(data_B)
    );

    mesi_cache cache_C (
        .clk(clk), .rst(rst),
        .cpu_read(grant_C & read_C),  .cpu_write(grant_C & write_C),
        .cpu_addr(addr_C),             .cpu_wdata(wdata_C),
        .snoop_read(snoop_read  & ~grant_C),
        .snoop_write(snoop_write & ~grant_C),
        .bus_addr(bus_addr), .shared_line(shared_C), .fill_data(c2c_C),
        .wb_req(wb_C), .wb_addr(wba_C), .wb_data(wbd_C),
        .hit(hit_C), .miss(miss_C), .cpu_rdata(rdata_C),
        .state_out(state_C), .valid_out(valid_C), .tag_out(tag_C), .data_out(data_C)
    );

endmodule
