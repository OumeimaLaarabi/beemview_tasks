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
  const AppConfig({required this.apiOrigin, required this.tenantSubdomain});

  factory AppConfig.fromEnvironment() => const AppConfig(
    apiOrigin: String.fromEnvironment(
      'API_ORIGIN',
      defaultValue: 'https://beemview.com',
    ),
    tenantSubdomain: String.fromEnvironment('TENANT_SUBDOMAIN'),
  );

  /// Scheme + host, e.g. `https://beemview.com` (no trailing `/api`).
  final String apiOrigin;

  /// Tenant sent with every login request. Fixed per build; never entered by
  /// the user.
  final String tenantSubdomain;

  /// False when the build was made without `TENANT_SUBDOMAIN`; login can't
  /// work in that case.
  bool get isConfigured => tenantSubdomain.trim().isNotEmpty;

  /// All routes in the contract live under `/api`.
  String get apiBaseUrl => '${apiOrigin.replaceAll(RegExp(r'/+$'), '')}/api';
}
