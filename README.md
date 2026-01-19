# Revani🍰
Powered by JeaFriday ♥

*(Revani is a traditional Turkish semolina cake with syrup.)*

**Ultra-Fast, Ultra-Secure, Actor-Model Based Modern NoSQL Database!**

Revani is a high-performance NoSQL engine developed to eliminate the cumbersome structures and security vulnerabilities of traditional database management systems. It operates on a **'Zero-Trust'** principle by shielding data not at the application layer, but directly at the heart of the communication protocol through mandatory encryption. Its primary goal is to combine ultra-low latency with maximum data security in a single, unified structure.

[![Install Revani](https://img.shields.io/badge/Install-Revani-FF69B4?style=for-the-badge&logo=rocket&logoColor=white)](./docs/06_installation_guide.md)

For more in-depth information about Revani, you can examine the following documentation:

| Section | Topic | Content |
| :--- | :--- | :--- |
| 01 | [Vision & Introduction](./docs/01_introduction.md) | Origins of the project and future goals. |
| 02 | [Architecture & Philosophy](./docs/02_architecture_and_philosophy.md) | Actor Model and the "Bakery" metaphor. |
| 03 | [Cryptographic Protocol](./docs/03_cryptographic_protocol.md) | AES-GCM, Argon2, and Zero-Trust details. |
| 04 | [Data Persistence](./docs/04_data_persistence.md) | BSON and Append-Only storage strategy. |
| 05 | [Garbage Collection (GC)](./docs/05_garbage_collection.md) | Incremental cleanup and memory management. |
| 06 | [Installation Guide](./docs/06_installation_guide.md) | Ubuntu setup and SSL configuration. |
| 07 | [SDK Usage](./docs/07_sdk_and_api_reference.md) | Coding examples via the Dart SDK. |
| 08 | [Endpoint Reference](./docs/08_endpoint_reference.md) | Raw protocol and command list. |

## Why Revani?
Revani is not limited to just the 'RevaniEngine' database motor. By design, it is a **'Technology Box'** and an API solution that offers all the fundamental building blocks a modern application might need through a single protocol.

### 📊 Stress Test & Performance Analysis

Revani offers microsecond response times even under heavy load. The results below are compiled from continuous 60-second stress test data with 5 concurrent threads.

| Processing Layer | Operation Type | Average Latency | Security Status |
| :--- | :--- | :--- | :--- |
| **Network Layer** | TCP/SSL Handshake | ~19.80 ms | 🔒 TLS v1.3 Secured |
| **Authentication** | Account Creation / Login | ~730.00 ms | 🛡️ Argon2id Hashing |
| **Protocol** | Session Key Derivation | < 1.00 ms | 🔑 AES-GCM Handshake |
| **Write** | Encrypted Data Packaging | **1.50 ms** | 🔒 End-to-End Encrypted |
| **Read** | Encrypted Data Decryption | **0.90 ms** | 🔒 End-to-End Encrypted |
| **Stability** | 30s Continuous Loop | **%100 Success** | ✅ No Packet Loss |

#### Analysis Summary
* **Sub-Millisecond Performance:** Data read speeds have dropped to the **0.90ms** level. This speed was achieved in the most secure mode, where every packet is AES-GCM encrypted and passes Replay Attack verification.
* **Linear Scaling:** Although 11 different Isolates were running simultaneously during the test, no memory locking occurred thanks to the Actor Model, and stability was maintained.
* **Efficiency:** Serialization load was minimized through the specialized `RevaniBson` engine, utilizing hardware resources at peak efficiency.

--------------------------

1. **Revani Makes Security Mandatory.**
Most databases view security as an external layer and leave it to the application developer. In Revani, security is not a choice; it is the foundation of the architecture. AES-GCM 256-bit encryption is directly embedded into the TCP protocol. This ensures every packet arriving at the database is armored and verified with Replay Attack protection before processing even begins.

2. **Revani is More than a Database: It is an Integrated Technology Ecosystem.**
By nature, RevaniEngine was developed as a database engine. However, Revani was designed as a 'Technology Box'. Aiming to collect everything under one tree, it solves not just database needs, but also Security Layers, File Storage, Livekit communication, and PubSub messaging.

## The 'Revani' Philosophy and the Bakery Metaphor 🍰🇹🇷
Revani explains complex data operations and concurrency management through a real-life "Bakery" metaphor. This naming symbolizes that the project is not just a tool, but a living system.

### Chefs (Revani Chefs - Isolates)
While traditional databases often have a single kitchen putting all orders in one queue, Revani assigns a "Pastry Chef" (Dart Isolate) to every CPU core.
* Each chef works independently at their own station.
* Chefs do not touch each other's ingredients; they communicate only via "order slips" (Ports).
This eliminates kitchen chaos and allows orders to be prepared concurrently.

### 🍰 Revani (The Resulting Data)
Every successful transaction resulting from the system is a meticulously prepared "Revani" dessert. The database engine, RevaniEngine, keeps the recipes, protects them in armored boxes, and delivers them to the customer.

### 🧹 Cleaning (Garbage Collector)
A bakery must always be spotless. Revani features a continuous "Sweeping the floor" cycle in the background. This cycle:
* Cleans unnecessary gaps in the database file.
* Incrementally discards "stale" data.
* Ensures the ovens always smell fresh and operate at high performance.

## Concurrency Model: Actor Model vs. Lock-Free Architecture
To ensure data consistency under high load, Revani has adopted the **Actor Model** principle instead of traditional "Lock-based" or complex "Lock-free" algorithms.

**Why Actor Model?**
Traditional databases use lock mechanisms like Mutex or Semaphore to prevent multiple processes from accessing the same piece of data. These locks lead to constant contention between processor cores and context-switching costs, creating performance bottlenecks.

In Revani, the process works as follows:
* **Shared-Nothing:** Each Isolate assigned to a CPU core has its own isolated memory area. Chefs never access each other's memory directly.
* **Communication via Messaging:** Data transfer is handled via messages sent through secure ports, not over shared memory.
* **Eliminating Deadlock Risks:** Each Chef processes tasks in their own queue sequentially but at a speed completely independent of other chefs. This architecture eliminates "Race Condition" risks at the architectural level rather than the software level.

## Cryptographic Protocol Design
Revani adopts a **"Defense in Depth"** strategy to ensure data confidentiality and integrity. Security is an inseparable part of the core protocol.

### 1. AES-GCM 256-bit: Confidentiality and Integrity Combined
AES-GCM, used at the communication layer, is the standard of modern cryptography.
* **Authenticated Encryption (AEAD):** Revani not only encrypts data but also mathematically verifies that it has not been altered in transit.
* **Nonce/Salt Dynamics:** Every request is derived with a unique Nonce and Salt. This ensures that even if the same data is sent twice, the encrypted outputs will be completely different, making "Dictionary Attacks" and "Pattern Analysis" impossible.

### 2. Timestamped Verification
Revani embeds a timestamp in every packet to prevent intercepted packets from being re-injected into the system.
* **30-Second Tolerance:** The server checks the timestamp of the incoming packet. If the packet is older than 30 seconds, the transaction is rejected even if the encryption is correct. This prevents an attacker listening to network traffic from copying and re-using packets.

### 3. Argon2id: Authentication with Memory Hardness
The **Argon2id** algorithm is used for storing user passwords.
* **Hardware Resistance:** Unlike traditional methods, Argon2 demands a massive memory area against GPU or ASIC-based brute-force attacks, keeping the attack cost at the theoretical limit.
* **Salting:** Every password goes through a unique salting process at the Argon2 level, rendering "Rainbow Table" attacks ineffective.

### 4. Layered Encryption Strategy
In Revani, data is armored twice:
* **Session Encryption:** Instant TCP traffic between the client and server.
* **Storage Encryption:** Sensitive data written to the database engine is also kept encrypted on disk using a server-side key.

## Data Persistence and Serialization
Revani uses an optimized storage architecture to balance high-performance read/write operations with long-term data security.

### 1. RevaniBson: Binary-Based High-Speed Serialization
While text-based formats like JSON are human-readable, they impose high CPU costs during serialization and parsing. Revani solves this with its native binary format, **RevaniBson**:
* **Low Memory Footprint:** Data is kept in its purest form—binary—on disk and over the wire. This minimizes data size and losses during type conversion.
* **Fast Access:** Because the data size is known in advance thanks to the binary structure, memory-address-based reading can be performed directly.

### 2. Append-Only Logging and Data Integrity
The database engine uses an **Append-Only** strategy for disk writes.
* **Write Speed:** Appending new data to the end of the file instead of updating existing data minimizes disk head movement and boosts write speeds to ultra levels.
* **Crash Recovery:** In the event of an unexpected power outage or crash, incomplete records at the end of the file are easily detected, and database consistency is preserved.

### 3. Smart Compaction Mechanism
The "append-only" strategy causes file sizes to swell over time. Revani handles this with the **"Kneading the dough"** process:
* **Background Compaction:** A background cycle scans the database file during periods of low system load or at periodic intervals.
* **Stale Data Cleanup:** It physically removes old copies of updated or deleted records from the disk and reorganizes the file to optimize disk space.

### 4. Atomic Flush and Sync Policy
Revani uses an **Atomic Flush** mechanism to ensure data is safely transferred from RAM to the physical disk. Thanks to the configurable `flushInterval`, the system maintains a perfect balance between speed and data safety.

## Garbage Collection Strategy
Traditional engines usually follow a "Stop-the-world" approach when cleaning memory. Revani overcomes this with the **Incremental Garbage Collector** (I call him the **Komi**🙃) algorithm.

### 1. Random Sampling
Instead of scanning the entire database in every cleaning cycle, Revani checks a specific number of randomly selected data groups. This ensures the processor load is spread over time.

### 2. Incremental Sweeping
The engine works in continuous, small steps to detect old data:
* **TTL (Time-to-Live) Control:** Every piece of data has an optional lifespan.
* **Smart Decision Mechanism:** If the stale data ratio in the randomly selected sample group is above **25%**, the system instantly increases "cleaning intensity." If the ratio is low, it goes to rest until the next cycle to avoid straining resources.

### 3. Micro-Task Management
Cleaning operations are added to Dart’s micro-task (`Future.microtask`) queue so as not to block main database operations. This allows cleanup to be performed during millisecond intervals when the processor is idle while processing user requests.

### 4. "Sweeping the Floor" Log Logic
The "Sweeping the floor" phrase seen in Revani's logs symbolizes that this smart algorithm is currently active. Thanks to this strategy, Revani offers a smooth and predictable latency even under gigabytes of data.