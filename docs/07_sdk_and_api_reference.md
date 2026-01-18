# 📚 SDK and API Reference Guide

Revani uses a standardized protocol across all clients. The structures, method names, and parameters explained here using the Dart SDK are identical across Python, PHP, and other Revani libraries.

## 1. Introduction: RevaniClient Structure
All your interactions with Revani begin with the `RevaniClient` class. This class automatically manages the TCP connection to the server, the handshake process, and the encrypted packet traffic.

### Establishing a Connection
To connect to the server, simply provide the host and port information. The `secure` parameter determines whether the TLS/SSL layer is active.

```dart
final client = RevaniClient(
  host: '127.0.0.1', 
  port: 16897, 
  secure: true
);

await client.connect();
```

---

## 2. Account and Authentication (RevaniAccount)
In Revani, every operation is tied to an account and a project. For security, all traffic except for `create` and `login` methods flows under heavy encryption.

### Account Creation and Login
```dart
// Create a new account (One-time)
await client.account.create("admin@revani.com", "strong_password");

// Log in (Handshake and Session Key retrieval happen automatically)
bool success = await client.account.login("admin@revani.com", "strong_password");
```
*Note: Once login is successful, the `session_key` is automatically set, and all subsequent requests are armored with AES-GCM.*

---

## 3. Project Management (RevaniProject)
Revani features a **Multi-Tenant** architecture. Data is isolated under specific projects.

```dart
// Create a new project
await client.project.create("SmartHome_System");

// Activate an existing project
await client.project.use("SmartHome_System");
```

---

## 4. NoSQL Data Operations (RevaniData)
The heart of Revani, the NoSQL RevaniEngine, operates on a `bucket`, `tag`, and `value` hierarchy.

### Adding and Updating Data
```dart
await client.data.add(
  bucket: "sensor_data",
  tag: "livingroom_temp",
  value: {"temp": 24.5, "unit": "C"}
);

await client.data.update(
  bucket: "sensor_data",
  tag: "livingroom_temp",
  newValue: {"temp": 22.0}
);
```

### Reading and Querying Data
```dart
// Retrieve single data entry
var res = await client.data.get(bucket: "sensor_data", tag: "livingroom_temp");

// Advanced querying
var queryRes = await client.data.query(
  bucket: "sensor_data",
  query: {"temp": {"$gt": 20}} // Get values greater than 20
);
```

---

## 5. Object Storage (RevaniStorage)
Allows you to store your files on disk in an encrypted and optimized manner.

```dart
// Upload a file
await client.storage.upload(
  fileName: "profile_photo.jpg",
  bytes: fileBytes,
  compress: true // Automatic image optimization
);

// Download a file
var file = await client.storage.download("file_id_here");
```

---

## 6. Real-Time Services (Livekit & PubSub)
Revani is more than just a database; it is a communication bridge.

### PubSub (Publish/Subscribe)
Used for instant messaging or event-driven systems.
```dart
// Subscribe to a topic
await client.pubsub.subscribe("home_alarm", "client_id_01");

// Publish a message to the topic
await client.pubsub.publish("home_alarm", {"status": "triggered"});
```

### Livekit Integration
Secures the management of audio and video rooms on the server side.
```dart
await client.livekit.createRoom("Meeting_Room_1");
var token = await client.livekit.createToken(
  roomName: "Meeting_Room_1",
  userID: "user_123",
  userName: "JeaFriday"
);
```

---

## 🛡️ Security Note: Protocol Compliance
Regardless of the language you use (Python, PHP, C#, etc.), Revani SDKs implement the following standards in the background:
1.  **Frame Header:** Each packet starts with a 4-byte (Uint32) length information.
2.  **Encryption:** Uses AES-GCM encryption in the format `salt:iv:ciphertext`.
3.  **Timestamp:** Every encrypted packet contains a `ts` (timestamp) for Replay Attack protection.

---
The continuation of this documentation can be found in the *08_endpoint_reference.md* file.