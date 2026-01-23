# SDK and API Reference Guide (v2.0.0>)

This document provides a technical overview of the Revani SDK for Dart. As of version 2.0.0, the SDK utilizes a type-safe response model and a hybrid communication architecture (TCP for stateful operations, HTTP for stateless file streaming).

## 1. Core Architecture: RevaniClient

All interactions with the Revani ecosystem are orchestrated via the `RevaniClient` class. This class manages persistent TCP connections, session negotiation, and automatic reconnection logic.

### Initialization and Connectivity

```dart
final client = RevaniClient(
  host: '127.0.0.1',
  port: 16897,
  secure: true, // Enables TLS/SSL
  autoReconnect: true
);

await client.connect();
```

## 2. Standardized Response Model (RevaniResponse)

Version 2.0.0 introduces the `RevaniResponse` object, replacing raw dictionary outputs. This ensures consistent error handling and status code verification across all modules.

| Property | Type | Description |
| :--- | :--- | :--- |
| `status` | int | Standard HTTP status code (200, 401, 403, etc.) |
| `isSuccess` | bool | Returns true if status is within the 200-299 range |
| `data` | dynamic | The primary payload returned by the server |
| `message` | String | Human-readable response or system message |
| `error` | String? | Technical error description if applicable |

## 3. Account and Session Management

Authentication now produces a short-lived, dynamically renewed token.

```dart
// Account Registration
await client.account.create(
  "user@example.com", 
  "secure_password",
  onSuccess: (data) => print("Account created: $data"),
  onError: (error) => print("Registration failed: $error")
);

// Authentication and Token Acquisition
RevaniResponse loginRes = await client.account.login("user@example.com", "password");

if (loginRes.isSuccess) {
  print("Authenticated with Token: ${client.isSignedIn}");
}
```

## 4. NoSQL Data Operations

Data operations are executed via the stateful TCP pipeline.

```dart
// Atomic Write Operation
RevaniResponse addRes = await client.data.add(
  bucket: "inventory",
  tag: "item_001",
  value: {"stock": 150, "location": "Warehouse A"}
);

// Advanced Query Execution
RevaniResponse queryRes = await client.data.query(
  bucket: "inventory",
  query: {
    "where": [{"field": "stock", "op": ">", "value": 100}]
  }
);
```

## 5. Storage and Media Management (HTTP Layer)

Unlike database operations, storage commands (upload/download) are processed through the HTTP Side-Kitchen layer to optimize throughput.

```dart
// File Ingestion via HTTP POST
await client.storage.upload(
  fileName: "document.pdf",
  bytes: fileBytes,
  compress: false,
  onSuccess: (data) => print("File ID: ${data['file_id']}")
);

// File Retrieval via HTTP GET
await client.storage.download(
  "file_id_string",
  onSuccess: (data) => saveToFile(data['bytes'])
);
```