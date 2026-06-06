# Theory — MESI Cache Coherence Protocol

## 1. Introduction

In recent years, multiprocessors have gained importance because they offer better performance and reliability than single-processor systems. Multiprocessors with shared memory enable processors to communicate using the same address space. This sharing creates the **cache coherence problem**: when one processor writes to a shared memory location, other processors may still hold stale copies of that data in their local caches.

The **MESI Protocol** is an invalidation-based cache coherence protocol that extends the simpler MSI protocol by introducing an **Exclusive** state. This allows a cache to silently upgrade from Exclusive to Modified on a write, avoiding unnecessary bus transactions.

---

## 2. MESI States

Each cache block can be in exactly one of four states at any time:

| State | Abbr | Description |
|---|---|---|
| **Modified** | M | Data in this cache differs from main memory. Only this cache holds a copy. Write-back required before eviction. |
| **Exclusive** | E | Data matches main memory. Only this cache holds a copy. No write-back needed on eviction. |
| **Shared** | S | Data matches main memory. Multiple caches may hold copies. |
| **Invalid** | I | Cache block is not valid. No read or write operations are permitted. |

### State Encoding (used in this implementation)

```
2'b11 = Modified  (M)
2'b10 = Exclusive (E)
2'b01 = Shared    (S)
2'b00 = Invalid   (I)
```

---

## 3. Block Diagram

```
  ┌──────────┐    ┌──────────┐    ┌──────────┐
  │  CPU A   │    │  CPU B   │    │  CPU C   │
  └────┬─────┘    └────┬─────┘    └────┬─────┘
       │               │               │
  ┌────▼─────┐    ┌────▼─────┐    ┌────▼─────┐
  │ Cache A  │    │ Cache B  │    │ Cache C  │
  │ (MESI)  │    │ (MESI)  │    │ (MESI)  │
  └────┬─────┘    └────┬─────┘    └────┬─────┘
       │               │               │
  ═════╧═══════════════╧═══════════════╧══════  ← Shared Bus
                        │
                 ┌──────▼──────┐
                 │ Main Memory  │
                 │  (32 × 8b)  │
                 └─────────────┘
```

The bus controller snoops all transactions. When a write is detected, it broadcasts an **invalidate** signal to all other caches that hold the same address.

---

## 4. Cache Design

- **Mapping:** Direct-mapped (index = addr[2:0], tag = addr[4:3])
- **Policy:** Write-back with dirty bit
- **Size:** 8 lines per cache, 1 byte per line
- **Address:** 5 bits (32 addresses)

---

## 5. Key Operations

### Read Hit
Address found in cache; data is returned immediately. MESI state is unchanged.

### Read Miss
Address not found in cache (Invalid state).
- Bus broadcasts a read request
- If another cache holds the block in Modified state → it writes back to memory and the new cache receives the data; both transition to Shared (S)
- If another cache holds it in Exclusive/Shared → data forwarded; both go to Shared (S)
- If no other cache holds it → data fetched from main memory; new cache enters Exclusive (E)

### Write Hit (Exclusive → Modified)
No bus transaction required. The cache silently updates the data and transitions E → M.

### Write Hit (Shared → Modified)
Bus broadcasts an **invalidate** signal. All other caches holding the block transition to Invalid (I). The writing cache transitions to Modified (M).

### Write Miss
Data is fetched (if needed) and written. All other copies are invalidated. State → Modified (M).

### Write-back on Eviction
When a Modified line must be evicted (replaced by a new block on a miss), the dirty data is written back to main memory before the new block is loaded.

---

## 6. Advantages

- Reduces unnecessary bus traffic by distinguishing Exclusive from Shared state
- Exclusive state allows silent E → M upgrade without a bus transaction
- Maintains data consistency across all processors
- Write-back policy reduces memory write frequency compared to write-through

---

## 7. Disadvantages

- Requires more clock cycles when a Modified line must be written back before a new cache entry is loaded
- For every shared write, the Modified data must be written back to main memory, increasing latency
- Implementation complexity increases with the number of processors
- Requires snooping logic on the shared bus, which does not scale well to large systems (NUMA architectures prefer directory-based protocols)

---

## 8. Base Paper

**Title:** Implementation of MESI Protocol using Verilog  
**Authors:** Attada Sravanthi, Ch. Rajasekhara Rao, K. Krishnam Raju, L. Rambabu  
**Published in:** International Research Journal of Engineering and Technology (IRJET)  
**Volume:** 06, Issue 06, June 2019
