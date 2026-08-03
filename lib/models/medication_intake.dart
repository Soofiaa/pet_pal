import 'package:uuid/uuid.dart';

class MedicationIntake {
  final String id;
  final String petId;
  final String medicationId;
  final DateTime intakeDateTime;
  final String medicationName;

  MedicationIntake({
    String? id,
    required this.petId,
    required this.medicationId,
    required this.intakeDateTime,
    required this.medicationName,
  }) : id = id ?? const Uuid().v4();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'medicationId': medicationId,
      'intakeDateTime': intakeDateTime.toIso8601String(),
      'medicationName': medicationName,
    };
  }

  factory MedicationIntake.fromJson(Map<String, dynamic> json) {
    return MedicationIntake(
      id: json['id'] as String,
      petId: json['petId'] as String,
      medicationId: json['medicationId'] as String,
      intakeDateTime: DateTime.parse(json['intakeDateTime'] as String),
      medicationName: json['medicationName'] as String,
    );
  }
}
