class ConfigResult {
  final bool ok;
  final String? url;
  final String? message;
  final int? expires;

  ConfigResult({
    required this.ok,
    this.url,
    this.message,
    this.expires,
  });

  factory ConfigResult.fromJson(Map<String, dynamic> json) {
    return ConfigResult(
      ok: json['ok'] as bool? ?? false,
      url: json['url'] as String?,
      message: json['message'] as String?,
      expires: json['expires'] as int?,
    );
  }

  factory ConfigResult.failure(String message) {
    return ConfigResult(ok: false, message: message);
  }
}
