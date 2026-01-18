# Garbage Collection Strategy: Incremental GC

In high-performance systems, memory management is of critical importance. Instead of using bulky "Stop-the-world" cleaning mechanisms that suddenly freeze the system, Revani employs an **Incremental Garbage Collection** algorithm that spreads the workload over time.

## 1. Solution to the Stop-the-world Problem
Traditional databases may freeze all operations during cleanup (GC Pauses). This leads to unacceptable latency spikes in real-time applications. Revani eliminates this issue by breaking down cleaning tasks into small, manageable micro-tasks.

## 2. Working Principle: Smart Sampling
Revani's "Komi" (The Busboy - GC Actor) follows these steps:

**Random Sampling:** Not the entire database is scanned in every cleaning cycle. Instead, a specific number of randomly selected data groups (buckets) are put under the microscope.

**TTL (Time-To-Live) Check:** The lifespan of each piece of data within the sample is checked. Data that has expired (stale) is immediately marked for removal from both memory and disk.

**Density Analysis:** If the ratio of stale data in the selected sample is above **25%**, the system concludes that "there is too much trash here" and either moves the next cleaning cycle forward or increases the cleaning volume.



## 3. Hardware-Friendly Scheduling
Cleaning operations are performed in millisecond gaps when the main database engine is most idle:

**Micro-tasking:** Cleaning tasks are added to Dart's `Future.microtask` queue. This ensures that if there is a "write" or "read" request from a user, the cleaning process gives way to it.

**Isolate-Level GC:** Since each "Chef" (Isolate) is responsible for its own memory space, cleaning operations are carried out in parallel across cores without waiting for one another.

## 4. Sweeping vs. Compaction
Revani features two distinct cleaning layers:

**Sweeping (Incremental GC):** Clears expired data from memory. This process is extremely fast and takes only milliseconds.

**Compaction:** Closes physical gaps in the database file. This is a heavier operation and is executed in the background at periodic intervals.



## 5. Result: Predictable Performance
Thanks to this strategy, Revani does not consume system resources in bursts. No matter how much the data volume increases, latency remains predictable and low.

---
The continuation of this documentation can be found in the *06_installation_guide.md* file.