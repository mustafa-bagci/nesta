/// Derleme zamanı ayarları.
library;

abstract final class AppConfig {
  /// `--dart-define=NESTA_DEMO=true` ile Firebase olmadan demo modunda açılır.
  /// Firebase yapılandırılmamışsa uygulama demo moduna kendiliğinden geçer.
  static const forceDemo = bool.fromEnvironment('NESTA_DEMO');

  /// Gizlilik politikasının yayınlandığı adres (mağaza ve Health Connect için).
  static const privacyPolicyUrl = String.fromEnvironment(
    'NESTA_PRIVACY_URL',
    defaultValue: 'https://nesta-app.web.app/gizlilik',
  );

  static const emergencyNumber = '112';
}
