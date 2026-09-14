/// Conssent record repository (POST + GET /consent).
library;

import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';

class ConsentRepository {
  ConsentRepository(this._api);
  final ApiClient _api;

  String get _prefix => '${AppConstants.apiV1Prefix}/consent';

  Future<void> record(String dataType, bool given) async {
    await _api.post(_prefix, body: {'data_type': dataType, 'consent_given': given});
  }

  /// Server-side consent status (mirrors `ConsentStatus` schema:
  /// steps / sleep / activity / screen_time / demographic_optional).
  Future<Map<String, bool>> status() async {
    final data = await _api.get(_prefix) as Map<String, dynamic>;
    return data.map((k, v) => MapEntry(k, v == true));
  }
}