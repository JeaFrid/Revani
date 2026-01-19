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