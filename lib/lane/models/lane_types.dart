// Shared lane bridge value types: the persisted routing mode and the
// decoded backend verdict.

/// Persisted routing decision for the next launch.
///
/// • [shell]  — open the in-app web shell (returning attributed user).
/// • [arcade] — open the puzzle (organic / unattributed user).
/// • [unset]  — first launch, no decision yet — run the full pipeline.
enum LaneMode {
  shell,
  arcade,
  unset;

  String encode() {
    switch (this) {
      case LaneMode.shell:
        return 'shell';
      case LaneMode.arcade:
        return 'arcade';
      case LaneMode.unset:
        return 'unset';
    }
  }

  static LaneMode decode(String? raw) {
    switch (raw) {
      case 'shell':
      case 'web':
        return LaneMode.shell;
      case 'arcade':
      case 'game':
        return LaneMode.arcade;
      default:
        return LaneMode.unset;
    }
  }
}

/// Parsed response from the remote attribution endpoint.
///
/// Several alternative field names are accepted so the client tolerates
/// slightly different backend conventions without code changes.
class LaneVerdict {
  final bool approved;
  final String? target;
  final String? hint;
  final int? validUntil;

  const LaneVerdict._({
    required this.approved,
    this.target,
    this.hint,
    this.validUntil,
  });

  factory LaneVerdict.parse(Map<String, dynamic> raw) {
    final bool approved = (raw['ok'] as bool?) ??
        (raw['granted'] as bool?) ??
        (raw['accepted'] as bool?) ??
        false;

    final String? target = raw['url'] as String? ??
        raw['link'] as String? ??
        raw['target'] as String? ??
        raw['destination'] as String?;

    final String? hint = raw['message'] as String? ??
        raw['note'] as String? ??
        raw['reason'] as String?;

    final dynamic ttl =
        raw['expires'] ?? raw['expires_at'] ?? raw['valid_until'];
    int? until;
    if (ttl is int) {
      until = ttl;
    } else if (ttl is num) {
      until = ttl.toInt();
    } else if (ttl is String) {
      until = int.tryParse(ttl);
    }

    return LaneVerdict._(
      approved: approved,
      target: target,
      hint: hint,
      validUntil: until,
    );
  }

  factory LaneVerdict.refused(String why) =>
      LaneVerdict._(approved: false, hint: why);
}
