import 'package:uuid/uuid.dart';

class VaccinationProduct {
  final String id;
  final String name;
  final int defaultFrequencyMonths;

  /// Grupo de equivalencia: las vacunas del catálogo con el mismo grupo se
  /// reemplazan entre sí (ej. "Triple felina" y "Cuádruple felina" en
  /// "Felina múltiple"). Null o vacío = sin grupo.
  final String? groupName;

  VaccinationProduct({
    String? id,
    required this.name,
    required this.defaultFrequencyMonths,
    this.groupName,
  }) : id = id ?? const Uuid().v4();

  VaccinationProduct copyWith({
    String? id,
    String? name,
    int? defaultFrequencyMonths,
    String? groupName,
    bool clearGroup = false,
  }) {
    return VaccinationProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultFrequencyMonths: defaultFrequencyMonths ?? this.defaultFrequencyMonths,
      groupName: clearGroup ? null : (groupName ?? this.groupName),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'defaultFrequencyMonths': defaultFrequencyMonths,
      'groupName': groupName,
    };
  }

  factory VaccinationProduct.fromJson(Map<String, dynamic> json) {
    return VaccinationProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      defaultFrequencyMonths: json['defaultFrequencyMonths'] as int,
      groupName: json['groupName'] as String?,
    );
  }
}
