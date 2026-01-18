# Data Persistence and Storage Strategy

Revani utilizes an optimized storage layer to balance high-performance read/write operations with long-term data security. Our persistence strategy is derived from the most efficient approaches in modern database theory.

## 1. RevaniBson: Binary Serialization Engine
One of the biggest bottlenecks affecting database performance is the data serialization process. Revani uses its native binary format, **RevaniBson**, instead of cumbersome text formats like JSON.

**Type Safety:** Data is stored on disk in its purest form (Int64, Double, String, Binary).

**Minimization of Overhead:** The unnecessary character load brought by JSON (brackets, quotes, etc.) is eliminated, providing significant disk space savings.

**High-Speed Parsing:** Since the data structure is known in advance, the CPU accesses memory addresses directly instead of performing complex string parsing operations.



## 2. Append-Only Logging (AOL)
Revani adopts an **Append-Only** strategy for disk write operations. This approach offers three fundamental advantages:

**Sequential Write Performance:** It minimizes disk head movement (seek time) by appending data to the very end of the file. This maximizes write speed, especially in high-traffic systems.

**Data Integrity:** Since existing data is never overwritten, the risk of data corruption during a crash is minimized.

**Fast Recovery:** When the server restarts, it scans the file only once to quickly reload the most current state into memory.

## 3. Data Compaction
An Append-Only structure causes the file size to grow over time. Revani solves this with a periodically running **Compaction** cycle.

**"Kneading the Dough":** A background maintenance process reorganizes the database file.

**Stale Record Cleanup:** Older copies of updated or deleted records are physically removed from the disk.

**Atomic Swap:** Once the compaction process is complete, the old file is atomically replaced with the new, optimized file, ensuring that data flow is never interrupted.



## 4. Atomic Flush and Security Lock
Two additional mechanisms are in place to prevent data loss:

**Flush Interval:** Data in memory is synchronized to the physical disk at user-defined intervals (`flushInterval`).

**Database Lock:** A `.lock` file mechanism is used to prevent the same database file (`revani.db`) from being opened by two different processes simultaneously.

## Technical Note
Revani's storage architecture is designed for "High-Performance Write" intensive systems. The data's journey on disk begins with `RevaniBson` and becomes permanent through the `Append-Only` log.

---
The continuation of this documentation can be found in the *05_garbage_collection.md* file.