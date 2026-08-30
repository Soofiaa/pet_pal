class FoodRecord {
  final int? id;
  final String petId;
  final String foodName;

  /// Null cuando la usuaria no recuerda cuándo empezó a darle este alimento.
  final DateTime? startDate;

  /// Null = lo sigue comiendo (ver [isOngoing]).
  final DateTime? endDate;
  final String notes;

  FoodRecord({
    this.id,
    required this.petId,
    required this.foodName,
    this.startDate,
    this.endDate,
    this.notes = '',
  });

  bool get isOngoing => endDate == null;

  FoodRecord copyWith({
    int? id,
    String? petId,
    String? foodName,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    return FoodRecord(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      foodName: foodName ?? this.foodName,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'foodName': foodName,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'notes': notes,
    };
  }

  factory FoodRecord.fromJson(Map<String, dynamic> json) {
    return FoodRecord(
      id: json['id'] as int?,
      petId: json['petId'] as String,
      foodName: json['foodName'] as String,
      startDate: json['startDate'] != null ? DateTime.parse(json['startDate'] as String) : null,
      endDate: json['endDate'] != null ? DateTime.parse(json['endDate'] as String) : null,
      notes: json['notes'] as String? ?? '',
    );
  }

  /// Cada evento se genera de forma independiente según su propia fecha
  /// esté o no presente -mismo criterio que [Medication.getEventsFromList]
  /// con startDate/endDate-: si falta la fecha de inicio pero se conoce la
  /// de fin, igual se genera el evento de fin (es un dato real y preciso
  /// que sí se tiene), y viceversa.
  static List<Map<String, dynamic>> getEventsFromList(List<FoodRecord> records) {
    final List<Map<String, dynamic>> events = [];
    for (final record in records) {
      if (record.startDate != null) {
        events.add({
          'id': record.id,
          'petId': record.petId,
          'type': 'food_record',
          'title': 'Inicio de alimento: ${record.foodName}',
          'date': record.startDate,
        });
      }
      if (record.endDate != null) {
        events.add({
          'id': record.id,
          'petId': record.petId,
          'type': 'food_record_end',
          'title': 'Fin de alimento: ${record.foodName}',
          'date': record.endDate,
        });
      }
    }
    return events;
  }
}
