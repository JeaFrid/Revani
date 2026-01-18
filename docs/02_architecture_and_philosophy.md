# Architecture and Philosophy: "The Bakery"

Revani's architecture is built upon the **Actor Model**, one of the most robust concurrency models in computer science. To make this complex system more understandable and manageable, the entire infrastructure is designed around a "Bakery" metaphor.

## 1. Actor Model and "Shared-Nothing" Approach
Traditional databases use shared memory and complex locking mechanisms to control data access. Revani, however, operates on the **"Shared-Nothing"** principle.

**Isolation:** Each work unit has its own isolated memory space.

**Messaging:** Communication between units occurs only through secure message channels (Ports).

**Side-Effect-Free:** An error or latency in one unit does not affect the rest of the system or its overall stability.



## 2. The Bakery Metaphor
The operating logic of the system consists of the following components:

**👨‍🍳 Chefs (Pastry Chefs - Isolates)**
Dart's **Isolate** structure represents Revani's "Chefs." When the server starts, a number of "Chefs" equal to your CPU core count take their places at the oven. Each chef works independently at their own counter.

No locking occurs because each chef only processes the "order slips" (Requests) that come directly to them.

**🍰 Revani (Final Data - The Result)**
*(Revani is a traditional semolina cake with syrup in Turkey.)*

Revani is a meticulously prepared result. Once data is processed in the server, it is packaged in the **RevaniBson** format and delivered to the outside world in a "fortified box" (AES-GCM encryption).

**🧹 Hygiene and Maintenance (Sweeping the Floor)**
The efficiency of a bakery depends on its cleanliness. Revani ensures this through background maintenance loops:

**Compaction:** It optimizes disk usage by removing physical gaps in the database file.

**Sweeping:** It keeps the memory fresh by removing expired (stale) data.



## 3. Why This Architecture?
This structure is not just an aesthetic choice; it is a strategy to utilize hardware resources at peak efficiency. The multi-core power of modern processors is utilized concurrently without bottlenecks, thanks to Revani's independent "Chefs."

---
The continuation of this documentation can be found in the *03_cryptographic_protocol.md* file.