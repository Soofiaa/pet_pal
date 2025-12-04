import 'package:flutter/material.dart';

class Medication {
  final String? id;
  final String petId;
  final String name;
  final String dosage;
  final String frequency;
  final String notes;
  final DateTime startDate;
  final DateTime? endDate;

  Medication({
    this.id,
    required this.petId,
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.notes,
    required this.startDate,
    this.endDate,
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
    );
  }

  static List<Map<String, dynamic>> getEventsFromList(List<Medication> medications) {
    List<Map<String, dynamic>> events = [];
    for (var medication in medications) {
      events.add({
        'type': 'Medicación',
        'title': 'Inicio de ${medication.name}',
        'date': medication.startDate,
        'icon': Icons.medication_liquid,
        'color': Colors.blueGrey,
      });
      if (medication.endDate != null) {
        events.add({
          'type': 'Fin de medicación',
          'title': 'Fin de tratamiento: ${medication.name}',
          'date': medication.endDate!,
          'icon': Icons.check,
          'color': Colors.green,
        });
      }
    }
    return events;
  }
}