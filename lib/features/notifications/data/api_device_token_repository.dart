import 'package:dio/dio.dart';

import 'device_token_repository.dart';

class ApiDeviceTokenRepository implements DeviceTokenRepository {
  ApiDeviceTokenRepository(this._dio);
  final Dio _dio;

  @override
  Future<void> register(String token, {required String platform}) async {
    await _dio.post<Map<String, dynamic>>(
      '/api/users/device-token',
      data: {'token': token, 'platform': platform},
    );
  }

  @override
  Future<void> revoke(String token) async {
    // Deletes only the specific token, not every device for the user — that
    // way logging out on the phone doesn't kill notifications on the iPad.
    await _dio.delete<Map<String, dynamic>>(
      '/api/users/device-token',
      data: {'token': token},
    );
  }
}
