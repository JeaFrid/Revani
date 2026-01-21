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