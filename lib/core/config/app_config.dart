import 'package:flutter/foundation.dart';

/// Connection settings, supplied at build/run time so nothing tenant-specific
/// is committed to source control:
///
/// ```
/// flutter run --dart-define-from-file=config.json
/// # or
/// flutter run --dart-define=API_ORIGIN=https://beemview.com \
///             --dart-define=TENANT_SUBDOMAIN=<your-subdomain>
/// ```
class AppConfig {
  const AppConfig({
    required this.apiOrigin,
    required this.tenantSubdomain,
    this.devLoginEmail = '',
    this.devLoginPassword = '',
  });

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiOrigin: String.fromEnvironment(
      'API_ORIGIN',
      defaultValue: 'https://beemview.com',
    ),
    tenantSubdomain: String.fromEnvironment('TENANT_SUBDOMAIN'),
    // Debug builds only: `kDebugMode` is a constant, so release builds drop
    // these strings entirely even when built from the same config file.
    devLoginEmail: kDebugMode ? String.fromEnvironment('DEV_LOGIN_EMAIL') : '',
    devLoginPassword: kDebugMode
        ? String.fromEnvironment('DEV_LOGIN_PASSWORD')
        : '',
  );

  /// Scheme + host, e.g. `https://beemview.com` (no trailing `/api`).
  final String apiOrigin;

  /// Tenant sent with every login request. Fixed per build; never entered by
  /// the user.
  final String tenantSubdomain;

  /// False when the build was made without `TENANT_SUBDOMAIN`; login can't
  /// work in that case.
  bool get isConfigured => tenantSubdomain.trim().isNotEmpty;

  /// Test account used to pre-fill the login form in debug builds. Empty
  /// unless set in the (gitignored) config file.
  final String devLoginEmail;
  final String devLoginPassword;

  /// All routes in the contract live under `/api`.
  String get apiBaseUrl => '${apiOrigin.replaceAll(RegExp(r'/+$'), '')}/api';
}
