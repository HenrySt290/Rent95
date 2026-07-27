import 'device_token_repository.dart';

/// No-op — the mock backend doesn't care about push tokens.
class MockDeviceTokenRepository implements DeviceTokenRepository {
  @override
  Future<void> register(String token, {required String platform}) async {}
  @override
  Future<void> revoke(String token) async {}
}
