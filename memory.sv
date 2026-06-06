// =====================================================================
// Module  : memory
// Project : MESI Cache Coherence Protocol
// Course  : 23ECE333 — Functional Verification
// Batch   : 12 | AY 2025-2026
// =====================================================================
// Description:
//   32-entry, byte-wide main memory. Pre-initialised with known values
//   at specific addresses so simulation results are deterministic.
//   Supports synchronous read and write (posedge clk).
// =====================================================================

module memory (
    input  logic        clk,
    input  logic        mem_read,
    input  logic        mem_write,
    input  logic [4:0]  addr,
    input  logic [7:0]  wdata,
    output logic [7:0]  rdata
);

    logic [7:0] mem [0:31];
    integer k;

    initial begin
        // Default: mem[i] = i
        for (k = 0; k < 32; k = k + 1)
            mem[k] = k;

        // Override specific addresses for test scenarios
        mem[0]  = 8'b00000100;
        mem[4]  = 8'b00000101;
        mem[7]  = 8'b00010100;
        mem[6]  = 8'b00011110;
        mem[9]  = 8'b10001000;
    end

    always_ff @(posedge clk) begin
        if (mem_write) mem[addr] <= wdata;
        if (mem_read)  rdata     <= mem[addr];
    end

endmodule
