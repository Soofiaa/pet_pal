class Deworming {
  final String? id;
  final String petId;
  final String product;
  final DateTime date;
  final DateTime? nextDate;
  final String? type; // 'interna', 'externa', 'ambas'
  final int? frequencyMonths;
  final int reminderDaysAhead;

  Deworming({
    this.id,
    required this.petId,
    required this.product,
    required this.date,
    this.nextDate,
    this.type,
    this.frequencyMonths,
    this.reminderDaysAhead = 0,
  });

  Deworming copyWith({
    String? id,
    String? petId,
    String? product,
    DateTime? date,
    DateTime? nextDate,
    String? type,
    int? frequencyMonths,
    int? reminderDaysAhead,
  }) {
    return Deworming(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      product: product ?? this.product,
      date: date ?? this.date,
      nextDate: nextDate ?? this.nextDate,
      type: type ?? this.type,
      frequencyMonths: frequencyMonths ?? this.frequencyMonths,
      reminderDaysAhead: reminderDaysAhead ?? this.reminderDaysAhead,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'product': product,
      'date': date.toIso8601String(),
      'nextDate': nextDate?.toIso8601String(),
      'type': type,
      'frequencyMonths': frequencyMonths,
      'reminderDaysAhead': reminderDaysAhead,
    };
  }

  factory Deworming.fromJson(Map<String, dynamic> json) {
    return Deworming(
      id: json['id'] as String?,
      petId: json['petId'] as String,
      product: json['product'] as String,
      date: DateTime.parse(json['date'] as String),
      nextDate: json['nextDate'] != null ? DateTime.parse(json['nextDate'] as String) : null,
      type: json['type'] as String?,
      frequencyMonths: json['frequencyMonths'] as int?,
      reminderDaysAhead: json['reminderDaysAhead'] as int? ?? 0,
    );
  }

  static List<Map<String, dynamic>> getEventsFromList(List<Deworming> dewormings) {
    List<Map<String, dynamic>> events = [];
    for (var deworming in dewormings) {
      String typeSuffix = '';
      if (deworming.type == 'interna') typeSuffix = ' (I)';
      if (deworming.type == 'externa') typeSuffix = ' (E)';
      if (deworming.type == 'ambas') typeSuffix = ' (I+E)';

      events.add({
        'id': deworming.id,
        'petId': deworming.petId,
        'type': 'deworming',
        'title': 'Desparasitación$typeSuffix: ${deworming.product}',
        'date': deworming.date,
        'name': deworming.product,
      });
      if (deworming.nextDate != null) {
        events.add({
          'id': deworming.id,
          'petId': deworming.petId,
          'type': 'next_deworming',
          'title': 'Próxima desparasitación$typeSuffix: ${deworming.product}',
          'date': deworming.nextDate!,
          'name': deworming.product,
        });
      }
    }
    return events;
  }
}