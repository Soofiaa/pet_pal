import 'dart:convert';

/// Id de notificación estable a partir de una clave de texto.
///
/// Reemplaza a `String.hashCode`, que Dart no garantiza que sea igual entre
/// versiones del SDK ni entre plataformas: si cambiara, los ids de los
/// recordatorios ya programados dejarían de coincidir con los que se
/// calculan después de actualizar, y cancelarlos fallaría en silencio.
///
/// Usa FNV-1a de 32 bits sobre los bytes UTF-8 de [key] (algoritmo fijo y
/// publicado) y recorta el resultado a 31 bits para que quepa en el entero
/// con signo de 32 bits que Android usa como id de notificación.
///
/// Un hash de 31 bits sigue sin ser libre de colisiones por construcción:
/// con unos pocos cientos de ids simultáneos la probabilidad es
/// despreciable, pero no cero. Los tests cubren los volúmenes realistas con
/// claves deterministas.
int stableNotificationId(String key) {
  int hash = 0x811C9DC5;
  for (final int byte in utf8.encode(key)) {
    hash ^= byte;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash & 0x7FFFFFFF;
}
