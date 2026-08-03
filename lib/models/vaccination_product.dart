import 'package:uuid/uuid.dart';

class VaccinationProduct {
  final String id;
  final String name;
  final int defaultFrequencyMonths;

  VaccinationProduct({
    String? id,
    required this.name,
    required this.defaultFrequencyMonths,
  }) : id = id ?? const Uuid().v4();

  VaccinationProduct copyWith({
    String? id,
    String? name,
    int? defaultFrequencyMonths,
  }) {
    return VaccinationProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultFrequencyMonths: defaultFrequencyMonths ?? this.defaultFrequencyMonths,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'defaultFrequencyMonths': defaultFrequencyMonths,
    };
  }

  factory VaccinationProduct.fromJson(Map<String, dynamic> json) {
    return VaccinationProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      defaultFrequencyMonths: json['defaultFrequencyMonths'] as int,
    );
  }
}
