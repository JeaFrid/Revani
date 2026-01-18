# 🔌 Endpoint and Protocol Reference

This document is prepared for developers who wish to communicate with the Revani server directly via TCP without using an SDK. Revani uses a custom protocol with a binary packet structure instead of a standard HTTP interface to ensure low latency.

## 1. Communication Protocol (The Wire Format)

When communicating with the Revani server, you must adhere to these three rules:
1.  **Connection:** Establishing a connection over a TCP socket (Default Port: `16897`).
2.  **Security:** If the server is in `secure: true` mode, an SSL/TLS handshake is mandatory.
3.  **Frame Structure:** Every message consists of a "Header" and a "Payload."

### Frame Structure
Before sending any message, you must prepend a 4-byte header indicating the size of the payload.

| Section | Size | Type | Description |
| :--- | :--- | :--- | :--- |
| **Header** | 4 Bytes | Uint32 (Big Endian) | The length of the payload in bytes. |
| **Payload** | Variable | UTF-8 JSON | The actual request or response body. |



---

## 2. Security Implementation (Encryption Algorithm)

After receiving the `session_key` from the `auth/login` operation, you must armor all your requests.

**Request Packaging Steps:**
1.  **Create Wrapper:** Place the command you want to send inside this JSON:
    `{"payload": "COMMAND_JSON_STRING", "ts": TIMESTAMP_MS}`
2.  **Key Derivation:** Generate a 16-byte random `salt`. Key = `SHA256(session_key + salt_base64)`.
3.  **Encryption:** Using AES-GCM (256-bit), encrypt the wrapper with a 16-byte random `iv`.
4.  **Final String:** Construct a string in the format: `salt_base64 : iv_base64 : ciphertext_base64`.
5.  **Envelope:** The final JSON to be sent to the server: `{"encrypted": "FINAL_STRING"}`.

---

## 3. Command (Endpoint) List

All commands are specified using the `cmd` key within the JSON payload.

### A. Account and Authentication
| Command (`cmd`) | Parameters | Description |
| :--- | :--- | :--- |
| `account/create` | `email`, `password`, `data` | Creates a new account (Plaintext). |
| `auth/login` | `email`, `password` | Returns a `session_key` (Plaintext). |
| `account/get-id` | `email`, `password` | Returns the account's unique ID. |
| `account/get-data`| `id` | Retrieves additional account data. |

### B. Project Management
| Command (`cmd`) | Parameters | Description |
| :--- | :--- | :--- |
| `project/create` | `accountID`, `projectName` | Creates a new project and database file. |
| `project/exist` | `accountID`, `projectName` | Verifies project existence and returns its ID. |

### C. NoSQL Data Operations (RevaniEngine)
*All parameters must be sent within an encrypted packet.*

| Command (`cmd`) | Key Parameters | Function |
| :--- | :--- | :--- |
| `data/add` | `bucket`, `tag`, `value` | Adds new data (Append-only). |
| `data/get` | `bucket`, `tag`, `projectID` | Retrieves a specific data entry. |
| `data/update` | `bucket`, `tag`, `newValue` | Updates data (via appending). |
| `data/delete` | `bucket`, `tag` | Marks data as deleted. |
| `data/query` | `bucket`, `query` | Executes logical queries ($gt, $lt, etc.). |

### D. Storage and Media (RevaniStorage & Livekit)
| Command (`cmd`) | Description |
| :--- | :--- |
| `storage/upload` | Uploads a file using `bytes` (List<int>) and `fileName`. |
| `livekit/init` | Configures the Livekit API on the server side. |
| `livekit/create-token`| Generates an access token for a specific room. |
| `pubsub/publish` | Publishes data over a specific `topic`. |

---

## 4. Status Codes and Response Format

Every response from the server follows a standardized structure:
```json
{
  "status": 200,      // 200: OK, 400: Error, 401: Unauthorized
  "data": { ... },    // Data returned if the operation is successful
  "msg": "Description"// Error message in case of failure
}
```

> 💡 **Important:** If the server sends an encrypted response, it will arrive as `{"encrypted": "..."}`. You must decrypt this payload on the client side using the same AES-GCM logic.