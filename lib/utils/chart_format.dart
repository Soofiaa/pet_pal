/// Formatea el valor de una etiqueta del eje Y con los decimales que exige el
/// intervalo entre marcas: con un intervalo menor a 1 redondear a entero
/// repite etiquetas ("26 kg", "26 kg", "25 kg", "25 kg").
String formatAxisValue(double value, double interval) {
  final int decimals;
  if (interval >= 1) {
    decimals = 0;
  } else if (interval >= 0.1) {
    decimals = 1;
  } else {
    decimals = 2;
  }
  return value.toStringAsFixed(decimals);
}
