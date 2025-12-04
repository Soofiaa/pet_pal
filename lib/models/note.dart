import 'dart:convert';
import 'package:uuid/uuid.dart';

class Note {
  final String id;
  final String petId;
  final String title;
  final String content;
  final DateTime date;
  final List<String> photoPaths;

  Note({
    String? id,
    required this.petId,
    required this.title,
    required this.content,
    required this.date,
    this.photoPaths = const [],
  }) : id = id ?? const Uuid().v4();

  // Método copyWith añadido
  Note copyWith({
    String? id,
    String? petId,
    String? title,
    String? content,
    DateTime? date,
    List<String>? photoPaths,
  }) {
    return Note(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      title: title ?? this.title,
      content: content ?? this.content,
      date: date ?? this.date,
      photoPaths: photoPaths ?? this.photoPaths,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'title': title,
      'content': content,
      'date': date.toIso8601String(),
      'photoPaths': jsonEncode(photoPaths),
    };
  }

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] as String,
      petId: json['petId'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      date: DateTime.parse(json['date'] as String),
      photoPaths: json['photoPaths'] == null
          ? []
          : List<String>.from(jsonDecode(json['photoPaths'])),
    );
  }

  // AÑADIDO: Método para convertir una lista de notas en una lista de eventos para el calendario
  static List<Map<String, dynamic>> getEventsFromList(List<Note> notes) {
    List<Map<String, dynamic>> events = [];
    for (var note in notes) {
      events.add({
        'id': note.id,
        'petId': note.petId,
        'date': note.date,
        'title': 'Nota: ${note.title}',
        'type': 'note', // Indicador para identificar el tipo de evento
      });
    }
    return events;
  }
}