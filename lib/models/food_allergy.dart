class FoodAllergy {
  final int? id; // El ID ahora es int y puede ser nulo al crear
  final String petId;
  final String food; // Se persiste en la columna 'allergies' de la tabla
  final DateTime dateRecorded; // Añadido para consistencia con tu DatabaseHelper

  FoodAllergy({
    this.id,
    required this.petId,
    required this.food,
    required this.dateRecorded,
  });

  // Método copyWith añadido
  FoodAllergy copyWith({
    int? id,
    String? petId,
    String? food,
    DateTime? dateRecorded,
  }) {
    return FoodAllergy(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      food: food ?? this.food,
      dateRecorded: dateRecorded ?? this.dateRecorded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'allergies': food,
      'dateRecorded': dateRecorded.toIso8601String(),
    };
  }

  factory FoodAllergy.fromJson(Map<String, dynamic> json) {
    return FoodAllergy(
      id: json['id'] as int?,
      petId: json['petId'] as String,
      food: json['allergies'] as String,
      dateRecorded: DateTime.parse(json['dateRecorded'] as String),
    );
  }

  static List<Map<String, dynamic>> getEventsFromList(
    List<FoodAllergy> allergies,
  ) {
    final List<Map<String, dynamic>> events = [];

    for (final allergy in allergies) {
      events.add({
        'id': allergy.id,
        'petId': allergy.petId,
        'date': allergy.dateRecorded,
        'title': 'Alergia registrada: ${allergy.food}',
        'type': 'food_allergy',
      });
    }

    return events;
  }
}