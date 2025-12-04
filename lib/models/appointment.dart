import 'package:uuid/uuid.dart';

class Appointment {
  final String id;
  final String petId;
  final DateTime dateTime;
  final String title;
  final String? description;
  final String? location;
  final String? type;
  final bool isCompleted;

  Appointment({
    String? id,
    required this.petId,
    required this.dateTime,
    required this.title,
    this.description,
    this.location,
    this.type,
    this.isCompleted = false,
  }) : id = id ?? const Uuid().v4();

  // El método copyWith ya está en tu código, por lo que no necesita cambios.
  // Es la forma correcta de actualizar el 'petId' al importar.
  Appointment copyWith({
    String? id,
    String? petId,
    DateTime? dateTime,
    String? title,
    String? description,
    String? location,
    String? type,
    bool? isCompleted,
  }) {
    return Appointment(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      dateTime: dateTime ?? this.dateTime,
      title: title ?? this.title,
      description: description ?? this.description,
      location: location ?? this.location,
      type: type ?? this.type,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'dateTime': dateTime.toIso8601String(),
      'title': title,
      'description': description,
      'location': location,
      'type': type,
      'isCompleted': isCompleted ? 1 : 0,
    };
  }

  factory Appointment.fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String,
      petId: json['petId'] as String,
      dateTime: DateTime.parse(json['dateTime'] as String),
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      type: json['type'] as String?,
      isCompleted: (json['isCompleted'] as int?) == 1,
    );
  }

  // AÑADIDO: Método para convertir una lista de citas en una lista de eventos para el calendario
  static List<Map<String, dynamic>> getEventsFromList(List<Appointment> appointments) {
    List<Map<String, dynamic>> events = [];
    for (var appointment in appointments) {
      events.add({
        'id': appointment.id,
        'petId': appointment.petId,
        'date': appointment.dateTime,
        'title': 'Cita: ${appointment.title}',
        'type': 'appointment',
        'isCompleted': appointment.isCompleted,
      });
    }
    return events;
  }
}