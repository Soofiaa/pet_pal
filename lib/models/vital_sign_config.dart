import 'package:flutter/material.dart';

/// Extensible: agregar un valor nuevo acá y su entrada correspondiente en
/// [vitalSignConfigs] es lo único necesario para soportar un signo vital
/// nuevo (temperatura, frecuencia cardíaca, etc.) — el modelo, repository,
/// provider y pantalla ya son genéricos sobre este enum.
enum VitalSignType { temperature }

class VitalSignConfig {
  const VitalSignConfig({
    required this.label,
    required this.unit,
    required this.normalMin,
    required this.normalMax,
    required this.chartColor,
    required this.icon,
  });

  final String label;
  final String unit;
  final double normalMin;
  final double normalMax;
  final Color chartColor;
  final IconData icon;

  bool isAbnormal(double value) => value < normalMin || value > normalMax;
}

/// Rango normal de referencia para perros/gatos adultos en reposo. No varía
/// por especie/edad por ahora — ver BACKLOG.md ítem 4.
const Map<VitalSignType, VitalSignConfig> vitalSignConfigs = {
  VitalSignType.temperature: VitalSignConfig(
    label: 'Temperatura',
    unit: '°C',
    normalMin: 37.5,
    normalMax: 39.2,
    chartColor: Colors.orange,
    icon: Icons.thermostat,
  ),
};
