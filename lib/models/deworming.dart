class Deworming {
  final String? id;
  final String petId;
  final String product;
  final DateTime date;
  final DateTime? nextDate;
  final String? type; // 'interna', 'externa', 'ambas'
  final int? frequencyMonths;
  final int reminderDaysAhead;
  /// Si es true, el recordatorio de este registro se auto-perpetúa cada
  /// [frequencyMonths] sin necesitar un registro nuevo por ciclo (ver
  /// [effectiveNextDate]). No aplica sin [frequencyMonths].
  final bool isRecurring;

  Deworming({
    this.id,
    required this.petId,
    required this.product,
    required this.date,
    this.nextDate,
    this.type,
    this.frequencyMonths,
    this.reminderDaysAhead = 0,
    this.isRecurring = false,
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
    bool? isRecurring,
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
      isRecurring: isRecurring ?? this.isRecurring,
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
      'isRecurring': isRecurring ? 1 : 0,
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
      isRecurring: json['isRecurring'] == 1,
    );
  }

  /// Fecha efectiva de "próxima desparasitación". Si [isRecurring] está
  /// activo y hay [frequencyMonths] configurado, avanza [nextDate] en
  /// múltiplos de esa frecuencia hasta que sea igual o posterior a [now]
  /// (por defecto `DateTime.now()`) -así el recordatorio nunca se ve
  /// "vencido para siempre" solo porque no se creó un registro nuevo en el
  /// ciclo anterior-. Si no es recurrente, devuelve [nextDate] tal cual
  /// (comportamiento sin cambios). Es la única función que calcula este
  /// avance: la usan ReminderScheduler, getEventsFromList (dashboard y
  /// calendario) y las pantallas de desparasitación, para no duplicar la
  /// lógica ni divergir entre ellas. Puro: nunca escribe en la base de datos.
  DateTime? effectiveNextDate({DateTime? now}) {
    if (nextDate == null) return null;
    if (!isRecurring || frequencyMonths == null || frequencyMonths! <= 0) {
      return nextDate;
    }

    final DateTime reference = now ?? DateTime.now();
    DateTime candidate = nextDate!;
    while (candidate.isBefore(reference)) {
      candidate = DateTime(candidate.year, candidate.month + frequencyMonths!, candidate.day);
    }
    return candidate;
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
      final effectiveNextDate = deworming.effectiveNextDate();
      if (effectiveNextDate != null) {
        events.add({
          'id': deworming.id,
          'petId': deworming.petId,
          'type': 'next_deworming',
          'title': 'Próxima desparasitación$typeSuffix: ${deworming.product}',
          'date': effectiveNextDate,
          'name': deworming.product,
        });
      }
    }
    return events;
  }
}