import 'package:pet_pal/models/vital_sign_config.dart';

class VitalSignRecord {
  final int? id;
  final String petId;
  final VitalSignType type;
  final double value;
  final DateTime date;

  VitalSignRecord({
    this.id,
    required this.petId,
    required this.type,
    required this.value,
    required this.date,
  });

  VitalSignRecord copyWith({
    int? id,
    String? petId,
    VitalSignType? type,
    double? value,
    DateTime? date,
  }) {
    return VitalSignRecord(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      type: type ?? this.type,
      value: value ?? this.value,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'type': type.name,
      'value': value,
      'date': date.toIso8601String(),
    };
  }

  factory VitalSignRecord.fromJson(Map<String, dynamic> json) {
    return VitalSignRecord(
      id: json['id'] as int?,
      petId: json['petId'] as String,
      type: VitalSignType.values.firstWhere(
        (t) => t.name == json['type'],
        orElse: () => VitalSignType.temperature,
      ),
      value: (json['value'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }

  static List<Map<String, dynamic>> getEventsFromList(
    List<VitalSignRecord> records,
  ) {
    final List<Map<String, dynamic>> events = [];

    for (final record in records) {
      final config = vitalSignConfigs[record.type];
      final label = config?.label ?? record.type.name;
      final unit = config?.unit ?? '';

      events.add({
        'id': record.id,
        'petId': record.petId,
        'date': record.date,
        'title': '$label: ${record.value.toStringAsFixed(1)}$unit',
        'type': 'vital_sign',
      });
    }

    return events;
  }
}
