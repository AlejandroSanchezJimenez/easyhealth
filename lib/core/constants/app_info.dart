/// Información pública de la app para compartir.
class AppInfo {
  const AppInfo._();

  static const name = 'Kinea';

  /// URL de la app en la App Store.
  ///
  /// ⚠️  PENDIENTE: la app aún no está publicada. Cuando lo esté, sustituye el
  /// `id0000000000` por el ID real (lo verás en App Store Connect, con el
  /// formato `id6807769925`). Hasta entonces el link no lleva a ninguna parte.
  static const shareUrl = 'https://apps.apple.com/es/app/kinea/id0000000000';

  /// Mensaje para WhatsApp / X / Instagram / etc.
  static String inviteMessage(String code) =>
      '¡Añádeme como amigo en $name! Usa mi código $code en la app. '
      'Descárgala aquí: $shareUrl';
}
