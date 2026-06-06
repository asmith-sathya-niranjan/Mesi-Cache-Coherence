// =====================================================================
// Module  : mesi_cache
// Project : MESI Cache Coherence Protocol
// Course  : 23ECE333 — Functional Verification
// Batch   : 12 | AY 2025-2026
// =====================================================================
// Description:
//   Direct-mapped, write-back MESI cache controller.
//   8 cache lines, 5-bit address space (tag=addr[4:3], index=addr[2:0]).
//
//   State encoding:
//     2'b00 = Invalid (I)
//     2'b01 = Shared  (S)
//     2'b10 = Exclusive (E)
//     2'b11 = Modified  (M)
//
//   Snooping:
//     snoop_write: another CPU wrote → invalidate matching line
//     snoop_read : another CPU read  → downgrade M/E to S
//
//   Write-back:
//     wb_req is asserted when a miss evicts a dirty line.
//     The bus controller must write wb_data to wb_addr in memory.
// =====================================================================

module mesi_cache (
    input  logic        clk,
    input  logic        rst,

    // CPU-side
    input  logic        cpu_read,
    input  logic        cpu_write,
    input  logic [4:0]  cpu_addr,
    input  logic [7:0]  cpu_wdata,

    // Bus-side (snooping)
    input  logic        snoop_read,
    input  logic        snoop_write,
    input  logic [4:0]  bus_addr,
    input  logic        shared_line,   // '1' if another cache already holds the block
    input  logic [7:0]  fill_data,     // data from memory or another cache

    // Write-back request
    output logic        wb_req,
    output logic [4:0]  wb_addr,
    output logic [7:0]  wb_data,

    // CPU read result
    output logic        hit,
    output logic        miss,
    output logic [7:0]  cpu_rdata,

    // Expose internals for bus controller / scoreboard
    output logic [1:0]  state_out,
    output logic        valid_out,
    output logic [1:0]  tag_out,
    output logic [7:0]  data_out
);

    // ---- Internal storage ----
    logic        dirty [0:7];
    logic        valid [0:7];
    logic [1:0]  tag   [0:7];
    logic [7:0]  data  [0:7];
    logic [1:0]  state [0:7];   // MESI state per line

    // ---- Address decode ----
    logic [1:0]  cpu_tag;
    logic [2:0]  cpu_idx;
    logic [1:0]  bus_tag;
    logic [2:0]  bus_idx;

    assign cpu_tag = cpu_addr[4:3];
    assign cpu_idx = cpu_addr[2:0];
    assign bus_tag = bus_addr[4:3];
    assign bus_idx = bus_addr[2:0];

    // ---- Hit/miss logic ----
    wire cpu_hit = valid[cpu_idx] && (tag[cpu_idx] == cpu_tag);
    wire bus_hit = valid[bus_idx] && (tag[bus_idx] == bus_tag);

    assign hit       = cpu_hit;
    assign miss      = (cpu_read || cpu_write) && !cpu_hit;
    assign cpu_rdata = cpu_hit ? data[cpu_idx] : 8'h0;
    assign state_out = valid[cpu_idx] ? state[cpu_idx] : 2'b00;
    assign valid_out = valid[cpu_idx];
    assign tag_out   = tag[cpu_idx];
    assign data_out  = data[cpu_idx];

    // Write-back on eviction of dirty line
    assign wb_req  = miss && valid[cpu_idx] && dirty[cpu_idx];
    assign wb_addr = {tag[cpu_idx], cpu_idx};
    assign wb_data = data[cpu_idx];

    // ---- Sequential logic ----
    integer i;
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (i = 0; i < 8; i = i + 1) begin
                dirty[i] <= 0;
                valid[i] <= 0;
                tag[i]   <= 0;
                data[i]  <= 0;
                state[i] <= 2'b00;  // Invalid
            end
        end else begin

            // --- Snooping: another CPU wrote → invalidate our copy ---
            if (snoop_write && bus_hit) begin
                valid[bus_idx] <= 0;
                state[bus_idx] <= 2'b00;  // I
                dirty[bus_idx] <= 0;
            end

            // --- Snooping: another CPU read → downgrade M/E to S ---
            if (snoop_read && bus_hit && !snoop_write) begin
                if (state[bus_idx] == 2'b11 || state[bus_idx] == 2'b10) begin
                    state[bus_idx] <= 2'b01;  // S
                    dirty[bus_idx] <= 0;
                end
            end

            // --- CPU Read ---
            if (cpu_read) begin
                if (!cpu_hit) begin
                    valid[cpu_idx] <= 1;
                    tag[cpu_idx]   <= cpu_tag;
                    dirty[cpu_idx] <= 0;
                    data[cpu_idx]  <= fill_data;
                    // E if only this cache has it, S if shared
                    state[cpu_idx] <= shared_line ? 2'b01 : 2'b10;
                end
                // hit: no state change needed
            end

            // --- CPU Write ---
            if (cpu_write) begin
                valid[cpu_idx] <= 1;
                tag[cpu_idx]   <= cpu_tag;
                data[cpu_idx]  <= cpu_wdata;
                dirty[cpu_idx] <= 1;
                state[cpu_idx] <= 2'b11;  // Modified
            end

        end
    end

endmodule
