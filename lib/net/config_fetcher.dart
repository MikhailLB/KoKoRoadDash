import 'dart:convert';
import '../core/models/config_result.dart';
import '../net/road_net_client.dart';
import '../net/vault_service.dart';
import '../setup/road_settings.dart';

/// POSTs attribution body to the config endpoint and receives the backend
/// decision: show WebView (ok=true, url=...) or show game (ok=false).
class ConfigFetcher {
  final VaultService _vault;

  ConfigFetcher(this._vault);

  Future<ConfigResult> fetchConfig(Map<String, dynamic> body) async {
    if (RoadSettings.apiEndpoint.isEmpty) {
      return ConfigResult.failure('Endpoint not configured');
    }

    try {
      final uri = Uri.parse(RoadSettings.apiEndpoint);
      final response = await roadNetClient
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final result = ConfigResult.fromJson(json);

        if (result.ok && result.url != null) {
          await _vault.setSavedUrl(result.url!);
          if (result.expires != null) {
            await _vault.setUrlExpires(result.expires!);
          }
        }

        return result;
      } else {
        return ConfigResult.failure('HTTP ${response.statusCode}');
      }
    } catch (e) {
      return ConfigResult.failure(e.toString());
    }
  }

  Future<String?> getCachedUrl() => _vault.getSavedUrl();
}
