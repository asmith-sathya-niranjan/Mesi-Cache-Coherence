# Running on EDA Playground — Step-by-Step

> **Tool used:** EDA Playground (https://edaplayground.com)  
> **Simulator:** Synopsys VCS  
> **Language:** SystemVerilog

---

## Step 1 — Create an Account / Log In

1. Go to [https://edaplayground.com](https://edaplayground.com)
2. Click **Sign Up** (top right) or **Log In** if you already have an account
3. You can also sign in with Google

> You **must** be logged in to run simulations. Waveform viewing (EPWave) also requires login.

---

## Step 2 — Set Up the Simulator

On the left panel:

1. Under **"Simulators"**, select **Synopsys VCS**
2. Under **"Languages & Libraries"**, make sure **SystemVerilog** is selected
3. Check the box **"Open EPWave after run"** — this lets you view waveforms

---

## Step 3 — Paste the Design Code

Click on the **Design** tab (left editor pane).

Paste the contents of these files **in order** (or all in one file, top to bottom):

```
src/memory.sv
src/mesi_cache.sv
src/mesi_system.sv
```

The order matters because lower-level modules must be defined before they are instantiated.

---

## Step 4 — Paste the Testbench Code

Click on the **Testbench** tab (right editor pane).

Paste the entire contents of:

```
tb/tb_top.sv
```

This file contains the interface, all class definitions (transaction, generator, driver, monitor, scoreboard, environment), and the `tb` top module — everything in one file, which is the recommended approach for EDA Playground.

---

## Step 5 — Run the Simulation

Click the green **▶ Run** button at the top.

The simulation will:
- Compile both panels
- Run 150 randomised transactions
- Print `[PASS]` / `[FAIL]` for each transaction
- Print a final summary: `PASS: X   FAIL: Y`
- Finish at `$finish`

---

## Step 6 — View Waveforms

After the run completes, an **EPWave** window will open automatically (if you checked the box in Step 2).

1. Click **"Get Signals"** in EPWave
2. Select the signals you want (e.g., `clk`, `rst`, `state_A`, `hit_A`, `miss_A`, etc.)
3. Click **"Add Signals"**
4. Use the zoom controls to explore the waveform

---

## Step 7 — Save Your Playground (Optional)

Click **Save** (top bar) to get a permanent shareable URL for your playground. Share it with your team or faculty.

---

## Signals to Monitor in EPWave

| Signal | Description |
|---|---|
| `clk` | System clock |
| `rst` | Reset |
| `state_A[1:0]` | MESI state of Cache A |
| `state_B[1:0]` | MESI state of Cache B |
| `state_C[1:0]` | MESI state of Cache C |
| `hit_A / miss_A` | Hit/miss for CPU A |
| `hit_B / miss_B` | Hit/miss for CPU B |
| `hit_C / miss_C` | Hit/miss for CPU C |
| `rdata_A/B/C` | Read data returned to each CPU |

---

## Troubleshooting

| Problem | Fix |
|---|---|
| "Compilation error: undefined module" | Make sure all three `.sv` design files are pasted in the Design panel, in order |
| No waveform shown | Make sure "Open EPWave after run" was checked before running |
| Simulation runs but no PASS/FAIL printed | Check that the Testbench panel has the full `tb_top.sv` including the `initial` block |
| `$dumpfile` / `$dumpvars` not working | This is normal for some VCS versions on EDA Playground; the simulation still runs correctly |
