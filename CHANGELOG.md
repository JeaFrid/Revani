## [1.0.0]

- Initial version.

## [1.1.0] - 2026-01-19

### Added
- **Automated Installer**: Introduced `server/install.sh` for one-click environment setup, including Dart SDK, Git configuration, and SSL generation.
- **Server Management Suite**: Added `server/run.dart`, a central control panel for managing server lifecycles (Live/Test modes, logs, updates, and factory resets).
- **CLI Infrastructure**: Created `cli/` directory with `console.dart` and `executive.dart` to handle advanced administrative tasks and system orchestration.
- **Self-Destruct Protocol**: Implemented a double-verified uninstall sequence within the management suite for total system cleanup.

### Security & Administration
- **Enhanced Admin Authority**: Strengthened administrative privileges and access control layers across the engine.
- **Zero-Trust SSL Workflow**: Automated the generation of self-signed certificates and simplified the integration for production-grade Let's Encrypt certificates.
- **Config Protection**: Update logic now automatically backs up and restores `lib/config.dart` and `.env` to prevent credential loss during repository syncs.

### Changed
- **Directory Restructuring**: Migrated server-side utility scripts to the new `server/` workspace for better isolation.
- **Client Refinement**: Optimized `client/dart/revani.dart` for more robust communication with the updated dispatcher.
- **Database Engine**: Improved `lib/core/database_engine.dart` for better handling of lock files and clearing procedures.

### Fixed
- **Cleanup Logic**: Resolved issues where `.dart_tool` and lock files could persist after a system reset.
- **Log Management**: Streamlined `nohup` log redirection and real-time monitoring via the new management console.

## [1.2.0] - 2026-01-21

### 🚀 Major Feature: BaaS Transformation
Revani has evolved from a NoSQL engine into a comprehensive **Backend-as-a-Service** platform. It now supports end-user management, social networking features, and instant messaging out of the box.

### Added
- **Identity System (`RevaniUser`)**:
  - Implementation of **End-User Registration & Login** within specific projects.
  - Secure profile management with automatic password hash stripping on retrieval.
  - `changePassword` and `editProfile` endpoints with old-password verification.
  
- **Social Graph Engine (`RevaniSocial`)**:
  - **Posts**: Support for text, images (max 10), videos, and document attachments.
  - **Interactions**: Native `toggleLike` logic for posts and comments.
  - **Comments**: Full commenting system with nested like support.
  - **Analytics**: Built-in view counting mechanism for posts.

- **Messaging Infrastructure (`RevaniChat`)**:
  - **Chat Management**: Creation of multi-participant chat rooms.
  - **Message Ops**: Send, edit, and delete messages with ownership verification.
  - **Reactions & Pinning**: Support for emoji reactions and pinning crucial messages in a chat.

- **High-Performance Batch Ops**:
  - Added `addAll` (Batch Write), `getAll` (Bulk Read), and `deleteAll` (Bulk Delete) commands to both Server Engine and Client SDKs.
  - Optimized for low-latency mass data ingestion.

### Security
- **Granular Ownership**: Implemented strict `sender_id` checks for message updates/deletions.
- **Double-Layer Hashing**: End-user passwords are hashed independently using Argon2id, keeping them invisible even to the project owner.

### Changed
- **Schema Consolidation**: Merged `User`, `Social`, and `Messaging` logic into `lib/schema/data_schema.dart` for unified index management.
- **Dispatcher Routing**: Expanded `processCommand` switch-case to handle new `user/*`, `social/*`, and `chat/*` namespaces.
- **Dart SDK**: `RevaniClient` now exposes dedicated accessors: `.user`, `.social`, `.chat`, `.data`, `.project`, `.account`.


## [2.0.0] - 2026-01-23
### ⚠️ MAJOR RELEASE / BREAKING CHANGES
### 🏗️ Hybrid Infrastructure & Architectural Changes
- **Storage Decoupling**: Migrated all file operations (Upload/Download) from the raw TCP socket layer to a dedicated **HTTP REST API** layer. This prevents large binary transfers from blocking the database command pipeline (Head-of-line blocking).
- **Side-Kitchen HTTP Server**: Integrated a high-performance HTTP service within `bin/server.dart` to handle stateless file requests and media streaming efficiently.

### 🔐 Security & Identity Management
- **Token-Based Authentication**: Transitioned from static session keys to a dynamic **Token** system for administrative and user logins.
- **Session Heating (Hot TTL)**: Implemented an active session management logic where tokens are stored in `sys_sessions` and their expiration is automatically renewed upon each successful verification.
- **Identity Mismatch Detection**: Added strict cross-verification between the `accountID` provided in encrypted packets and the owner ID of the active session to prevent impersonation attacks.

### 📦 Dart SDK / Client Refactoring
- **RevaniResponse Modernization**: The SDK now returns a type-safe `RevaniResponse` object instead of raw `Map` data, standardizing status codes and error messaging across the library.
- **Enhanced Error Handling**: Introduced `SuccessCallback` and `ErrorCallback` types for more declarative and robust asynchronous flow management.
- **Auto-Reconnect Mechanism**: Added an intelligent reconnection logic featuring an **Exponential Backoff** algorithm to handle unexpected socket disconnections.
- **Server Time Synchronization**: Implemented `_serverTimeOffset` to calculate the drift between client and server clocks. This ensures millisecond-precision timestamps for Replay Attack protection.

### ⚡ Performance & Optimization
- **Standardized Status Codes**: Responses now include standardized HTTP-compliant status codes (e.g., 200 OK, 401 Unauthorized, 403 Forbidden) for better debugging.
- **Optimized Payload Processing**: Refactored the `_onData` buffer logic to handle interleaved encrypted and plain-text packets more reliably.

### ⚠️ Breaking Changes
- The `execute` method now returns a `RevaniResponse` object.
- The `login` function now returns a `RevaniResponse` instead of a `bool`, providing detailed failure reasons.
- Storage-related commands are now handled via HTTP endpoints instead of the TCP `execute` command.

## [2.0.1] - 2026-01-23
### Fix

## [2.1.0] - 2026-01-23
### Security and improvements.