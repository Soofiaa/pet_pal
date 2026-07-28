class Deworming {
  final String? id; // Cambiado a String
  final String petId;
  final String product;
  final DateTime date;
  final DateTime? nextDate;

  Deworming({
    this.id,
    required this.petId,
    required this.product,
    required this.date,
    this.nextDate,
  });

  // Método copyWith añadido
  Deworming copyWith({
    String? id,
    String? petId,
    String? product,
    DateTime? date,
    DateTime? nextDate,
  }) {
    return Deworming(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      product: product ?? this.product,
      date: date ?? this.date,
      nextDate: nextDate ?? this.nextDate,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'product': product,
      'date': date.toIso8601String(),
      'nextDate': nextDate?.toIso8601String(),
    };
  }

  factory Deworming.fromJson(Map<String, dynamic> json) {
    return Deworming(
      id: json['id'] as String?, // Cambiado a String
      petId: json['petId'] as String,
      product: json['product'] as String,
      date: DateTime.parse(json['date'] as String),
      nextDate: json['nextDate'] != null ? DateTime.parse(json['nextDate'] as String) : null,
    );
  }

  static List<Map<String, dynamic>> getEventsFromList(List<Deworming> dewormings) {
    List<Map<String, dynamic>> events = [];
    for (var deworming in dewormings) {
      events.add({
        'id': deworming.id,
        'petId': deworming.petId,
        'type': 'deworming',
        'title': 'Desparasitación: ${deworming.product}',
        'date': deworming.date,
      });
      if (deworming.nextDate != null) {
        events.add({
          'id': deworming.id,
          'petId': deworming.petId,
          'type': 'next_deworming',
          'title': 'Próxima desparasitación: ${deworming.product}',
          'date': deworming.nextDate!,
        });
      }
    }
    return events;
  }
}