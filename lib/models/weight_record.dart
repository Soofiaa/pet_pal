class WeightRecord {
  final int? id;
  final String petId;
  final double weight;
  final DateTime date;

  WeightRecord({
    this.id,
    required this.petId,
    required this.weight,
    required this.date,
  });

  WeightRecord copyWith({
    int? id,
    String? petId,
    double? weight,
    DateTime? date,
  }) {
    return WeightRecord(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      weight: weight ?? this.weight,
      date: date ?? this.date,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'weight': weight,
      'date': date.toIso8601String(),
    };
  }

  factory WeightRecord.fromJson(Map<String, dynamic> json) {
    return WeightRecord(
      id: json['id'] as int?,
      petId: json['petId'] as String,
      weight: (json['weight'] as num).toDouble(),
      date: DateTime.parse(json['date'] as String),
    );
  }

  static List<Map<String, dynamic>> getEventsFromList(List<WeightRecord> records) {
    List<Map<String, dynamic>> events = [];
    for (var record in records) {
      events.add({
        'id': record.id,
        'petId': record.petId,
        'date': record.date,
        'title': 'Peso: ${record.weight.toStringAsFixed(2)} kg',
        'type': 'weight_record',
      });
    }
    return events;
  }
}