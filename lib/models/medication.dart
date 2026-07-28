import 'dart:convert';

class Medication {
  final String? id;
  final String petId;
  final String name;
  final String dosage;
  final String frequency;
  final String notes;
  final DateTime startDate;
  final DateTime? endDate;
  /// Horarios de toma en formato "HH:mm", uno por cada vez al día.
  /// Vacío significa que la medicación no tiene horarios definidos
  /// (medicaciones creadas antes de este campo, o aún no configuradas).
  final List<String> reminderTimes;

  Medication({
    this.id,
    required this.petId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.notes,
    required this.startDate,
    this.endDate,
    this.reminderTimes = const [],
  });

  // Método copyWith añadido
  Medication copyWith({
    String? id,
    String? petId,
    String? name,
    String? dosage,
    String? frequency,
    String? notes,
    DateTime? startDate,
    DateTime? endDate,
    List<String>? reminderTimes,
  }) {
    return Medication(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      notes: notes ?? this.notes,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      reminderTimes: reminderTimes ?? this.reminderTimes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'notes': notes,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'reminderTimes': jsonEncode(reminderTimes),
    };
  }

  factory Medication.fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as String?,
      petId: json['petId'] as String,
      name: json['name'] as String,
      dosage: json['dosage'] as String,
      frequency: json['frequency'] as String,
      notes: json['notes'] as String,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      reminderTimes: json['reminderTimes'] == null
          ? []
          : List<String>.from(jsonDecode(json['reminderTimes'])),
    );
  }

  static List<Map<String, dynamic>> getEventsFromList(List<Medication> medications) {
    List<Map<String, dynamic>> events = [];
    for (var medication in medications) {
      events.add({
        'id': medication.id,
        'petId': medication.petId,
        'type': 'medication',
        'title': 'Inicio de ${medication.name}',
        'date': medication.startDate,
      });
      if (medication.endDate != null) {
        events.add({
          'id': medication.id,
          'petId': medication.petId,
          'type': 'medication_end',
          'title': 'Fin de tratamiento: ${medication.name}',
          'date': medication.endDate!,
        });
      }
    }
    return events;
  }
}