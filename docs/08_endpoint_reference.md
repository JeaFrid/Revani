# Endpoint and Protocol Reference (v2.0.0>)

Revani v2.0.0 employs a hybrid communication protocol. Stateful database transactions occur over a binary TCP stream, while stateless media operations utilize a RESTful HTTP interface.

## 1. TCP Protocol Specification (Port: 16897)

### Frame Structure
All TCP packets must be prefixed with a 4-byte header.

1. **Header (4 Bytes):** Uint32 Big Endian, representing the payload length.
2. **Payload (Variable):** UTF-8 encoded JSON string.

### Encryption Protocol (AES-GCM-256)
Encrypted envelopes must follow the serialized format: `salt:iv:ciphertext` (all Base64 encoded).

## 2. HTTP Side-Kitchen Specification (Port: 16898)

The HTTP server facilitates high-bandwidth operations and stateless API execution.

### A. File Ingestion (Media Upload)
**Endpoint:** `POST /upload`  
**Headers:**
- `x-account-id`: The unique identifier of the account.
- `x-project-name`: The target project namespace.
- `x-file-name`: The original filename (optional).

**Body:** Raw binary data.

### B. File Retrieval (Media Access)
**Endpoint:** `GET /file/:projectID/:fileID`  
**Description:** Serves the raw binary content of the specified file. Supports browser caching and CDN integration.

### C. Stateless Command Execution
**Endpoint:** `POST /api/execute`  
**Description:** Allows execution of database commands via HTTP for clients unable to maintain a persistent TCP socket.
**Body:** JSON command payload.

## 3. Command Registry (TCP/HTTP Execute)

| Command (`cmd`) | Namespace | Authorization | Description |
| :--- | :--- | :--- | :--- |
| `auth/verify-token` | Session | Plaintext | Validates and renews an active session token. |
| `data/add` | Database | Encrypted | Persists an object to the append-only log. |
| `data/query` | Database | Encrypted | Executes complex filters on a specific bucket. |
| `user/register` | Identity | Encrypted | Registers an end-user within a project scope. |
| `admin/system/force-gc` | System | Admin-Only | Manually triggers the Incremental Garbage Collector. |

## 4. Status Code Definitions

Revani uses standardized integer status codes to indicate the outcome of a request:

- **200 (OK):** Request completed successfully.
- **201 (Created):** Resource successfully persisted.
- **401 (Unauthorized):** Invalid credentials or expired token.
- **403 (Forbidden):** Identity mismatch or insufficient role permissions.
- **429 (Too Many Requests):** Rate limit exceeded for the current identifier.
- **500 (Internal Error):** Server-side exception or database corruption.