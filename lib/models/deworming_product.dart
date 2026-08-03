import 'package:uuid/uuid.dart';

class DewormingProduct {
  final String id;
  final String name;
  final int defaultFrequencyMonths;
  final String? defaultType; // 'interna', 'externa', 'ambas'

  DewormingProduct({
    String? id,
    required this.name,
    required this.defaultFrequencyMonths,
    this.defaultType,
  }) : id = id ?? const Uuid().v4();

  DewormingProduct copyWith({
    String? id,
    String? name,
    int? defaultFrequencyMonths,
    String? defaultType,
  }) {
    return DewormingProduct(
      id: id ?? this.id,
      name: name ?? this.name,
      defaultFrequencyMonths: defaultFrequencyMonths ?? this.defaultFrequencyMonths,
      defaultType: defaultType ?? this.defaultType,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'defaultFrequencyMonths': defaultFrequencyMonths,
      'defaultType': defaultType,
    };
  }

  factory DewormingProduct.fromJson(Map<String, dynamic> json) {
    return DewormingProduct(
      id: json['id'] as String,
      name: json['name'] as String,
      defaultFrequencyMonths: json['defaultFrequencyMonths'] as int,
      defaultType: json['defaultType'] as String?,
    );
  }
}
