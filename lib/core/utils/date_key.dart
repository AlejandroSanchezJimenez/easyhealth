/// Clave de día "yyyy-MM-dd" en HORA LOCAL del usuario.
/// Decisión: el "día de ejercicio" es el día local del dispositivo.
String dateKey(DateTime d) {
  final l = d.toLocal();
  return '${l.year.toString().padLeft(4, '0')}-'
      '${l.month.toString().padLeft(2, '0')}-'
      '${l.day.toString().padLeft(2, '0')}';
}

/// Fecha UTC a medianoche: evita errores por cambio horario al restar días.
DateTime parseDateKey(String key) {
  final p = key.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}
