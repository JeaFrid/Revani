# Revani: Your Dart-Based Backend, Simplified

`revani` is a powerful Dart package that acts as a client-side API for interacting with a Revani server. It's designed to be intuitive and to streamline the process of making requests to the server's various services and handling responses. Whether you're building a Flutter application or a Dart-based backend, `revani` provides the tools you need to get up and running quickly.

## Features

-   **Comprehensive Client Classes:** `revani` provides a suite of client classes for each of the Revani server's services, including account management, data storage, file galleries, real-time events, and more.
-   **Simplified Authentication:** The package handles authentication and session management for you, so you can focus on building your application.
-   **Consistent API:** `revani` provides a consistent interface for all API calls, making it easy to learn and use.
-   **Real-time Capabilities:** With `revani`, you can subscribe to real-time events from the server and even open a tunnel to your local machine for seamless development and debugging.

## Getting Started

To use this package, you'll need to have a Revani server running. If you don't have one, you can follow the instructions in the [Revani server documentation](https://github.com/JeaFrid/Revani) to set one up.

### Installation

To add `revani` to your project, run the following command:

```bash
flutter pub add revani
```

or, if you're not using Flutter:

```bash
dart pub add revani
```

This will add the following line to your `pubspec.yaml` file:

```yaml
dependencies:
  revani: ^1.0.0 # Replace with the latest version
```

### Importing the Package

Once you've added the package to your project, you can import it into your Dart code:

```dart
import 'package:revani/revani.dart';
```

This will give you access to all of the client classes and other features of the `revani` package.

## A Scenario-Based Guide to Using `revani`

Let's walk through a common scenario to see how you can use `revani` to build a full-featured application. In this scenario, we'll build a simple photo gallery application that allows users to create an account, upload photos, and view them in a gallery.

### 1. Setting Up the Clients

First, we'll need to create instances of the client classes that we'll be using. For this scenario, we'll need `RevaniAccountClient` and `RevaniGalleryClient`.

```dart
final String serverUrl = 'http://localhost:8080'; // Replace with your server's URL

final accountClient = RevaniAccountClient(serverUrl);
final galleryClient = RevaniGalleryClient(serverUrl);
```

### 2. Creating an Account

Before a user can upload photos, they'll need to create an account. We can use the `createAccount` method of `RevaniAccountClient` to do this:

```dart
try {
  final response = await accountClient.createAccount('John Doe', 'john.doe@example.com', 'password123');
  if (response['success']) {
    print('Account created successfully!');
  } else {
    print('Failed to create account: ${response['message']}');
  }
} catch (e) {
  print('An error occurred: $e');
}
```

### 3. Logging In and Getting an Authentication Token

Once the user has created an account, they can log in to get an authentication token. This token is required to access protected resources, such as the photo gallery.

```dart
try {
  final String token = await accountClient.getAuthToken('john.doe@example.com', 'password123');
  print('Logged in successfully! Token: $token');

  // We'll need to set the auth token on the gallery client so that it can
  // make authenticated requests.
  galleryClient.setAuthToken(token);
} catch (e) {
  print('An error occurred: $e');
}
```

### 4. Uploading a Photo

Now that the user is logged in, they can upload a photo to the gallery. To do this, we'll use the `uploadFile` method of `RevaniGalleryClient`.

```dart
import 'dart:io';

// ...

try {
  final file = File('path/to/photo.jpg');
  final fileBytes = await file.readAsBytes();

  final response = await galleryClient.uploadFile(
    projectID: 'my-project-id', // Replace with your project ID
    fileName: 'photo.jpg',
    fileBytes: fileBytes,
  );

  if (response['success']) {
    print('Photo uploaded successfully! File ID: ${response['fileID']}');
  } else {
    print('Failed to upload photo: ${response['message']}');
  }
} catch (e) {
  print('An error occurred: $e');
}
```

### 5. Listing Photos in the Gallery

To display the photos in the gallery, we can use the `listFiles` method of `RevaniGalleryClient`.

```dart
try {
  final response = await galleryClient.listFiles(
    projectID: 'my-project-id', // Replace with your project ID
  );

  if (response['success']) {
    final List<dynamic> files = response['files'];
    for (final file in files) {
      print('File ID: ${file['fileID']}, Name: ${file['fileName']}');
    }
  } else {
    print('Failed to list files: ${response['message']}');
  }
} catch (e) {
  print('An error occurred: $e');
}
```

### 6. Subscribing to Real-time Events

If you want to update the gallery in real-time as new photos are uploaded, you can use the `subscribeToEvents` method of `RevaniEventsClient`.

```dart
final eventsClient = RevaniEventsClient(serverUrl);
eventsClient.setAuthToken(token); // Use the same token from before

final stream = eventsClient.subscribeToEvents('my-project-id');
stream.listen((event) {
  print('Received event: $event');
});
```

## API Client Classes

The `revani` package includes the following client classes:

-   `RevaniAccountClient`: Handles user account management, such as creating accounts, logging in, and getting authentication tokens.
-   `RevaniDataClient`: Provides access to the server's data storage service.
-   `RevaniGalleryClient`: Interacts with the server's gallery service to manage images and other media.
-   `RevaniEventsClient`: Subscribes to real-time events from the server.
-   `RevaniTunnelClient`: A client for the server's tunnel service.
-   `RevaniUserClient`: Manages user-related operations.

For a complete list of available methods and their parameters, please refer to the source code of each client class.

## Best Practices

-   **Error Handling:** Always wrap your API calls in a `try-catch` block to handle potential network errors or server-side issues.
-   **Secure Connection:** When deploying your application, always use a secure connection (HTTPS) to protect sensitive data.
-   **API Response:** The `Map<String, dynamic>` object returned by each method contains information about the success of the operation, a message, and the data returned by the server. Always check the `success` key before attempting to use the data.

## Contributing

Contributions are welcome! If you find a bug or have a feature request, please open an issue on the [GitHub repository](https://github.com/JeaFriday/Revani_dart/issues).

## Additional Information

For more information about the Revani server and its API, please refer to the main [project documentation](https://github.com/JeaFriday/Revani).
