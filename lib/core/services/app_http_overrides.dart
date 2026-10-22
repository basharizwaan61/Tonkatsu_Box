import 'dart:io';

/// AniList 403s the anonymous default `Dart/x.x` user agent, so a descriptive
/// one is installed via [HttpOverrides.global] to cover every transport.
class AppHttpOverrides extends HttpOverrides {
  static const String userAgent =
      'Mediabox (https://github.com/basharizwaan61/Tonkatsu_Box)';

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return super.createHttpClient(context)..userAgent = userAgent;
  }
}
