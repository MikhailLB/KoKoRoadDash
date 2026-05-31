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
    // ignore: avoid_print
    print('[DBG][LD] endpoint="${endpoint.isEmpty ? 'EMPTY!' : endpoint}"');
    // ignore: avoid_print
    print('[DBG][LD] payload af_status=${body['af_status']} media=${body['media_source']}');
    if (endpoint.isEmpty) {
      // ignore: avoid_print
      print('[DBG][LD] endpoint empty → refused');
      return LaneVerdict.refused('endpoint_missing');
    }
    try {
      final Uri uri = Uri.parse(endpoint);
      final response = await brandedAgent.post(
        uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 9));

      // ignore: avoid_print
      print('[DBG][LD] HTTP ${response.statusCode} body=${response.body.length > 300 ? response.body.substring(0, 300) : response.body}');
      if (response.statusCode != 200) {
        return LaneVerdict.refused('http_${response.statusCode}');
      }
      final dynamic decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return LaneVerdict.refused('bad_json');
      }
      final LaneVerdict verdict = LaneVerdict.parse(decoded);
      // ignore: avoid_print
      print('[DBG][LD] verdict approved=${verdict.approved} target=${verdict.target}');
      if (verdict.approved && verdict.target != null) {
        await _stash.writeShellUrl(verdict.target!);
        if (verdict.validUntil != null) {
          await _stash.writeShellTtl(verdict.validUntil!);
        }
      }
      return verdict;
    } catch (err) {
      // ignore: avoid_print
      print('[DBG][LD] ERROR: $err');
      return LaneVerdict.refused(err.toString());
    }
  }
}
