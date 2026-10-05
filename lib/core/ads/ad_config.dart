/// Configuración de AdMob.
class AdConfig {
  /// App ID de Android. Formato `ca-app-pub-<publisher>~<app>`.
  /// Declarado también en AndroidManifest.xml (meta-data APPLICATION_ID).
  static const appId = 'ca-app-pub-7698436267091632~1435872104';

  /// Banner adaptativo. Formato `ca-app-pub-<publisher>/<unit>`.
  static const bannerAdUnitId = 'ca-app-pub-7698436267091632/7426565380';

  /// App ID de iOS, formato `ca-app-pub-<publisher>-<app>`. Vacío hasta que se
  /// cree la app en la consola de AdMob (evita el crash en iOS).
  static const iosAppId = 'ca-app-pub-7698436267091632~1435872104';

  /// Interruptor global: a false no se inicializa el SDK ni se pide ningún
  /// banner. Útil para builds sin anuncios.
  static const enabled = true;
}
