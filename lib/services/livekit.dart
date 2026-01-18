import 'package:livekit_server_sdk/livekit_server_sdk.dart';
// This package was incorrectly configured. Therefore, we need to pull it from the src folder.
// ignore: implementation_imports
import 'package:livekit_server_sdk/src/proto/livekit_models.pb.dart';

class LiveKitService {
  final String _host;
  final String _apiKey;
  final String _apiSecret;
  late final RoomServiceClient _client;

  LiveKitService({
    required String host,
    required String apiKey,
    required String apiSecret,
  }) : _host = host,
       _apiKey = apiKey,
       _apiSecret = apiSecret {
    _client = RoomServiceClient(
      host: _host,
      apiKey: _apiKey,
      secret: _apiSecret,
    );
  }

  String createJoinToken({
    required String roomName,
    required String participantIdentity,
    String? participantName,
    bool isAdmin = false,
  }) {
    final token = AccessToken(
      _apiKey,
      _apiSecret,
      options: AccessTokenOptions(
        identity: participantIdentity,
        name: participantName,
        ttl: const Duration(hours: 1),
      ),
    );

    final grant = VideoGrant(
      roomJoin: true,
      room: roomName,
      canPublish: true,
      canSubscribe: true,
      canPublishData: true,
      roomAdmin: isAdmin,
    );

    token.addGrant(grant);
    return token.toJwt();
  }

  Future<Room> createRoom(
    String roomName, {
    Duration emptyTimeout = const Duration(minutes: 10),
    int maxParticipants = 50,
  }) async {
    final options = CreateOptions(
      name: roomName,
      emptyTimeout: emptyTimeout,
      maxParticipants: maxParticipants,
    );

    return await _client.createRoom(options);
  }

  Future<List<Room>> getAllRooms() async {
    return await _client.listRooms(null);
  }

  Future<Room?> getRoom(String roomName) async {
    final rooms = await _client.listRooms([roomName]);
    if (rooms.isEmpty) {
      return null;
    }
    return rooms.first;
  }

  Future<void> deleteRoom(String roomName) async {
    await _client.deleteRoom(roomName);
  }

  Future<void> removeParticipant(String roomName, String identity) async {
    await _client.removeParticipant(roomName, identity);
  }

  Future<ParticipantInfo> getParticipant(
    String roomName,
    String identity,
  ) async {
    return await _client.getParticipant(roomName, identity);
  }

  Future<List<ParticipantInfo>> listParticipants(String roomName) async {
    return await _client.listParticipants(roomName);
  }

  Future<void> updateParticipant(
    String roomName,
    String identity, {
    String? metadata,
    ParticipantPermission? permission,
  }) async {
    await _client.updateParticipant(roomName, identity, metadata, permission);
  }

  Future<void> muteParticipantTrack(
    String roomName,
    String identity,
    String trackSid,
    bool muted,
  ) async {
    await _client.mutePublishedTrack(roomName, identity, trackSid, muted);
  }

  Future<void> updateRoomMetadata(String roomName, String metadata) async {
    await _client.updateRoomMetadata(roomName, metadata);
  }
}
