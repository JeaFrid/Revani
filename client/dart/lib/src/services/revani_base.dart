import '../source/api.dart';

class RevaniBase {
  static final RevaniBase _instance = RevaniBase._internal();
  factory RevaniBase() => _instance;
  RevaniBase._internal();

  late RevaniClient revani;

  static Future<void> init({
    required String email,
    required String password,
    String host = "revani.jeafriday.com",
    int port = 16897,
    bool secure = true,
    bool autoReconnect = true,
  }) async {
    try {
      _instance.revani = RevaniClient(
        host: host,
        secure: secure,
        autoReconnect: autoReconnect,
        port: port,
      );
      await _instance.revani.connect();
      RevaniResponse loginRes = await _instance.revani.account.login(
        email,
        password,
      );
      if (!loginRes.isSuccess) {
        throw Exception("Login failed: ${loginRes.message}");
      }
      RevaniResponse projectRes = await _instance.revani.project.use(
        "jeafriday_web",
      );

      if (!projectRes.isSuccess) {
        RevaniResponse createRes = await _instance.revani.project.create(
          "jeafriday_web",
        );

        if (!createRes.isSuccess) {
          throw Exception("Failed to create project: ${createRes.message}");
        }
        RevaniResponse finalUseRes = await _instance.revani.project.use(
          "jeafriday_web",
        );

        if (!finalUseRes.isSuccess) {
          throw Exception("Failed to connect to new project");
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}
