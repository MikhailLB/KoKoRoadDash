enum RunMode {
  online,
  offline,
  pending;

  static RunMode fromString(String? value) {
    switch (value) {
      case 'online':
        return RunMode.online;
      case 'offline':
        return RunMode.offline;
      default:
        return RunMode.pending;
    }
  }

  String toKey() {
    switch (this) {
      case RunMode.online:
        return 'online';
      case RunMode.offline:
        return 'offline';
      case RunMode.pending:
        return 'pending';
    }
  }
}
