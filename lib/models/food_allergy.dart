class FoodAllergy {
  final int? id; // El ID ahora es int y puede ser nulo al crear
  final String petId;
  final String food; // Corregido según tu pantalla de edición, que usa 'food'
  final String? notes; // Corregido según tu pantalla de edición
  final DateTime dateRecorded; // Añadido para consistencia con tu DatabaseHelper

  FoodAllergy({
    this.id,
    required this.petId,
    required this.food,
    this.notes,
    required this.dateRecorded,
  });

  // Método copyWith añadido
  FoodAllergy copyWith({
    int? id,
    String? petId,
    String? food,
    String? notes,
    DateTime? dateRecorded,
  }) {
    return FoodAllergy(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      food: food ?? this.food,
      notes: notes ?? this.notes,
      dateRecorded: dateRecorded ?? this.dateRecorded,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'food': food,
      'notes': notes,
      'dateRecorded': dateRecorded.toIso8601String(),
    };
  }

  factory FoodAllergy.fromJson(Map<String, dynamic> json) {
    return FoodAllergy(
      id: json['id'] as int?,
      petId: json['petId'] as String,
      food: json['food'] as String,
      notes: json['notes'] as String?,
      dateRecorded: DateTime.parse(json['dateRecorded'] as String),
    );
  }
}