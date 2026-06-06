# MESI Cache Coherence Protocol — SystemVerilog Implementation
   
> **Simulated on:** [EDA Playground](https://edaplayground.com/) (Synopsys VCS / SystemVerilog)



##  Project Overview

This project implements and verifies the **MESI (Modified, Exclusive, Shared, Invalid) cache coherence protocol** for a 3-processor shared-memory multiprocessor system using **SystemVerilog**. The design is verified using a fully **layered testbench** (UVM-style: Generator → Driver → Monitor → Scoreboard).

The MESI protocol ensures that all processors always see a consistent view of memory, preventing stale or corrupted data when multiple caches hold copies of the same address.

---

##  MESI States

| State | Code | Meaning |
|---|---|---|
| **Modified (M)** | `2'b11` | Cache has the only copy; dirty (differs from main memory) |
| **Exclusive (E)** | `2'b10` | Cache has the only copy; clean (matches main memory) |
| **Shared (S)** | `2'b01` | Multiple caches may hold this block; all clean |
| **Invalid (I)** | `2'b00` | Cache block is not valid |

---

##  Repository Structure

```
mesi-cache-coherence/
│
├── src/
│   ├── memory.sv          # 32-entry main memory module
│   ├── mesi_cache.sv      # MESI cache controller (direct-mapped, write-back)
│   └── mesi_system.sv     # Top-level system: 3 caches + bus controller + memory
│
├── tb/
│   ├── mesi_if.sv         # SystemVerilog interface
│   ├── mesi_transaction.sv # Transaction (randomized stimulus) class
│   ├── generator.sv       # Generates random transactions
│   ├── driver.sv          # Drives DUT via virtual interface
│   ├── monitor.sv         # Observes DUT outputs
│   ├── scoreboard.sv      # Checks correctness; logs PASS/FAIL
│   ├── environment.sv     # Wraps all TB components
│   └── tb_top.sv          # Top-level testbench module
│
├── sim/
│   └── eda_playground_instructions.md  # How to run on EDA Playground
│
├── docs/
│   └── theory.md          # Theory, block diagram description, advantages/disadvantages
│
└── README.md
```

---

##  Design Architecture

The system consists of:
- **3 processors (A, B, C)**, each with its own **direct-mapped, write-back cache** (8 entries, 5-bit address space)
- A **shared bus** with a simple **priority arbiter** (A > B > C)
- A **bus controller** that manages snooping, cache-to-cache transfers, and write-back
- A **32-entry main memory** module

### Address Breakdown (5-bit)

```
addr[4:3] = tag   (2 bits)
addr[2:0] = index (3 bits → 8 cache lines)
```

---

## 🧪 Testbench Architecture (Layered TB)

```
┌─────────────┐     mailbox      ┌─────────────┐
│  Generator  │ ───────────────► │   Driver    │
│  (random    │                  │  (drives    │
│  stimulus)  │                  │   vif)      │
└─────────────┘                  └─────────────┘
                                        │ virtual interface
                                        ▼
                               ┌─────────────────┐
                               │    DUT (mesi_   │
                               │     system)     │
                               └─────────────────┘
                                        │
┌─────────────┐     mailbox      ┌─────────────┐
│ Scoreboard  │ ◄─────────────── │   Monitor   │
│ (PASS/FAIL  │                  │  (observes  │
│  logging)   │                  │   outputs)  │
└─────────────┘                  └─────────────┘
```

- **150 randomized transactions** are generated per simulation run
- Each transaction targets a random CPU (0/1/2), random address, and random read/write operation
- The scoreboard checks that every transaction results in either a hit or a miss (no silent failures)

---

##  How to Run on EDA Playground

> See [`sim/eda_playground_instructions.md`](sim/eda_playground_instructions.md) for full step-by-step instructions.

**Quick steps:**
1. Go to [edaplayground.com](https://edaplayground.com) and log in
2. Select **Synopsys VCS** as the simulator, language **SystemVerilog**
3. Paste `mesi_system.sv` (+ `memory.sv`, `mesi_cache.sv`) into the **Design** panel
4. Paste `tb_top.sv` (with all TB classes inlined or via `include`) into the **Testbench** panel
5. Enable **"Open EPWave after run"** for waveform viewing
6. Click **Run**

---

##  Expected Simulation Results

| Scenario | Expected Behaviour |
|---|---|
| Read Miss (cold) | State → E (if no other cache has it) or S |
| Read Hit | State unchanged, data returned immediately |
| Write Hit (E state) | Silent upgrade to M, no bus transaction |
| Write Hit (S state) | Invalidate signal sent to all other caches, state → M |
| Write Miss | Data fetched, written, state → M |
| Snoop Invalidate | Other caches transition to I |
| Write-back on eviction | Dirty block written back to memory |

---
## Team / Contributors

| Name | GitHub |
|------|--------|
| Asmitha Sathya Niranjan| [@Asmitha Sathya Niranjan](https://github.com/asmith-sathya-niranjan) | 
| Bindu Manasa Simhadri | [@Bindu Manasa Simhadri]( https://github.com/Bindu1508) |
| Vamsi | [@username](https://github.com/username) |
| Tommundrula Harsha Veena | [@Tommundrula Harsha Veena](https://github.com/HarshaVeena2706) |

##  References

1. Attada Sravanthi et al., "Implementation of MESI Protocol using Verilog," *IRJET*, Vol. 06, Issue 06, June 2019.
2. Kalyani D. Kohle et al., "Design of cache controller for multicore systems using parallelization method," *IRF International Conference*, June 2014.
3. Dubois & Briggs, "Effects of cache coherency in multiprocessors," *IEEE Transactions on Computers*, Vol. 31, Issue 11, Nov 1982.
4. David J. Lilja, "Cache coherence in large scale shared memory multiprocessors," *ACM Computing Surveys*, Vol. 25, No. 3, Sept. 1993.
5. Linda Null & Julia Lobur, *The Essentials of Computer Organisation and Architecture*, 3rd Ed., Jones and Bartlett Learning.

---


