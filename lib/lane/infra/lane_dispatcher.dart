import 'dart:convert';

import '../config/lane_config.dart';
import '../models/lane_types.dart';
import 'branded_agent.dart';
import 'lane_stash.dart';

/// Sends the assembled lane payload to the remote attribution endpoint
/// and persists the resulting URL/expiry. Returns `LaneVerdict.refused`
/// when the endpoint isn't configured so the caller can route to the
/// arcade without crashing during development.
class LaneDispatcher {
  LaneDispatcher(this._stash);

  final LaneStash _stash;

  Future<LaneVerdict> submit(Map<String, dynamic> body) async {
    final String endpoint = LaneConfig.attributionEndpoint;
    if (endpoint.isEmpty) {
      return LaneVerdict.refused('endpoint_missing');
    }
    try {
      final Uri uri = Uri.parse(endpoint);
      final response = await brandedAgent.post(
        uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 9));

      if (response.statusCode != 200) {
        return LaneVerdict.refused('http_${response.statusCode}');
      }
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return LaneVerdict.refused('bad_json');
      }
      final LaneVerdict verdict = LaneVerdict.parse(decoded);
      if (verdict.approved && verdict.target != null) {
        await _stash.writeShellUrl(verdict.target!);
        if (verdict.validUntil != null) {
          await _stash.writeShellTtl(verdict.validUntil!);
        }
      }
      return verdict;
    } catch (err) {
      return LaneVerdict.refused(err.toString());
    }
  }
}
