class PetFoodConfig {
  final String petId;
  final double dailyGrams;
  final int portions;
  final double? foodKcalPerKg; // Opcional para cálculo avanzado

  PetFoodConfig({
    required this.petId,
    required this.dailyGrams,
    required this.portions,
    this.foodKcalPerKg,
  });

  Map<String, dynamic> toJson() {
    return {
      'petId': petId,
      'dailyGrams': dailyGrams,
      'portions': portions,
      'foodKcalPerKg': foodKcalPerKg,
    };
  }

  factory PetFoodConfig.fromJson(Map<String, dynamic> json) {
    return PetFoodConfig(
      petId: json['petId'] as String,
      dailyGrams: (json['dailyGrams'] as num).toDouble(),
      portions: json['portions'] as int,
      foodKcalPerKg: json['foodKcalPerKg'] != null ? (json['foodKcalPerKg'] as num).toDouble() : null,
    );
  }
}
