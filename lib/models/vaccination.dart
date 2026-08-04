import 'package:uuid/uuid.dart';

class Vaccination {
  final String id;
  final String petId;
  final String vaccineName;
  final DateTime date;
  final DateTime? nextDueDate;
  final String? stickerPhotoPath;
  final String? extraPhotoPath;
  final int reminderDaysAhead;

  Vaccination({
    String? id,
    required this.petId,
    required this.vaccineName,
    required this.date,
    this.nextDueDate,
    this.stickerPhotoPath,
    this.extraPhotoPath,
    this.reminderDaysAhead = 0,
  }) : id = id ?? const Uuid().v4();

  Vaccination copyWith({
    String? id,
    String? petId,
    String? vaccineName,
    DateTime? date,
    DateTime? nextDueDate,
    String? stickerPhotoPath,
    String? extraPhotoPath,
    int? reminderDaysAhead,
  }) {
    return Vaccination(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      vaccineName: vaccineName ?? this.vaccineName,
      date: date ?? this.date,
      nextDueDate: nextDueDate ?? this.nextDueDate,
      stickerPhotoPath: stickerPhotoPath ?? this.stickerPhotoPath,
      extraPhotoPath: extraPhotoPath ?? this.extraPhotoPath,
      reminderDaysAhead: reminderDaysAhead ?? this.reminderDaysAhead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'vaccineName': vaccineName,
      'date': date.toIso8601String(),
      'nextDueDate': nextDueDate?.toIso8601String(),
      'stickerPhotoPath': stickerPhotoPath,
      'extraPhotoPath': extraPhotoPath,
      'reminderDaysAhead': reminderDaysAhead,
    };
  }

  factory Vaccination.fromJson(Map<String, dynamic> json) {
    return Vaccination(
      id: json['id'] as String,
      petId: json['petId'] as String,
      vaccineName: json['vaccineName'] as String,
      date: DateTime.parse(json['date'] as String),
      nextDueDate: json['nextDueDate'] != null
          ? DateTime.parse(json['nextDueDate'] as String)
          : null,
      stickerPhotoPath: json['stickerPhotoPath'] as String?,
      extraPhotoPath: json['extraPhotoPath'] as String?,
      reminderDaysAhead: json['reminderDaysAhead'] as int? ?? 0,
    );
  }

  static List<Map<String, dynamic>> getEventsFromList(
    List<Vaccination> vaccinations,
  ) {
    final List<Map<String, dynamic>> events = [];

    for (final vaccination in vaccinations) {
      events.add({
        'id': vaccination.id,
        'petId': vaccination.petId,
        'date': vaccination.date,
        'title': 'Vacunación: ${vaccination.vaccineName}',
        'type': 'vaccination',
        'name': vaccination.vaccineName,
      });

      if (vaccination.nextDueDate != null) {
        events.add({
          'id': '${vaccination.id}_next',
          'petId': vaccination.petId,
          'date': vaccination.nextDueDate,
          'title': 'Próxima Dosis: ${vaccination.vaccineName}',
          'type': 'next_vaccination',
          'name': vaccination.vaccineName,
        });
      }
    }

    return events;
  }
}
