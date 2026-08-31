import 'package:intl/intl.dart';

/// Texto del estado de un [FoodRecord], cubriendo los tres casos reales:
/// sigue comiendo, dejó de comerlo en fecha desconocida, dejó de comerlo en
/// una fecha conocida. Función pura y top-level -no depende de widgets- para
/// que la lista (food_record_screen.dart) y el buscador global
/// (search_service.dart) muestren siempre el mismo texto y no queden
/// inconsistentes entre sí.
String foodRecordStatusText(FoodRecord record) {
  if (record.isOngoing) return 'Sigue comiendo';
  if (record.endDate == null) return 'Dejó de comerlo (fecha desconocida)';
  return 'Hasta ${DateFormat('dd/MM/yyyy').format(record.endDate!)}';
}

class FoodRecord {
  final int? id;
  final String petId;
  final String foodName;

  /// Null cuando la usuaria no recuerda cuándo empezó a darle este alimento.
  final DateTime? startDate;

  /// Fecha en la que dejó de comerlo, si se conoce. Puede ser null tanto si
  /// lo sigue comiendo ([isOngoing] true) como si dejó de comerlo pero no se
  /// recuerda cuándo ([isOngoing] false) -son dos estados distintos, no
  /// inferibles el uno del otro-.
  final DateTime? endDate;
  final String notes;

  /// Campo real y persistido, no calculado. Invariante: si es true, [endDate]
  /// debe ser null (no tiene sentido "sigue comiendo" con una fecha de fin
  /// concreta).
  final bool isOngoing;

  /// [isOngoing] es opcional: si no se pasa, se infiere de [endDate] -mismo
  /// criterio implícito que tenía el getter viejo `endDate == null`-, lo que
  /// mantiene el comportamiento existente para cualquier código que no lo
  /// setee explícitamente. Pasarlo explícito es lo que permite distinguir
  /// "dejó de comerlo, fecha desconocida" (isOngoing: false, endDate: null)
  /// de "lo sigue comiendo" (isOngoing: true, endDate: null), algo que antes
  /// era indistinguible.
  FoodRecord({
    this.id,
    required this.petId,
    required this.foodName,
    this.startDate,
    this.endDate,
    this.notes = '',
    bool? isOngoing,
  }) : isOngoing = isOngoing ?? (endDate == null),
       assert(
         endDate == null || isOngoing != true,
         'isOngoing=true es incompatible con un endDate concreto',
       );

  FoodRecord copyWith({
    int? id,
    String? petId,
    String? foodName,
    DateTime? startDate,
    DateTime? endDate,
    String? notes,
    bool? isOngoing,
    bool clearStartDate = false,
    bool clearEndDate = false,
  }) {
    // Si se pasa un endDate nuevo y no se especifica isOngoing, se infiere
    // false: fijar una fecha de fin concreta implica dejar de estar
    // "ongoing" sin que el caller tenga que acordarse de setearlo aparte.
    // Si no se toca endDate ni isOngoing, se preserva this.isOngoing tal
    // cual -evita que un copyWith que solo cambia, por ejemplo, notes,
    // pise en silencio un isOngoing=false explícito (endDate null) de
    // vuelta a true-.
    final resolvedIsOngoing = isOngoing ?? (endDate != null ? false : this.isOngoing);
    return FoodRecord(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      foodName: foodName ?? this.foodName,
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      notes: notes ?? this.notes,
      isOngoing: resolvedIsOngoing,
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
      'isOngoing': isOngoing ? 1 : 0,
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
      // Si falta la clave (ej. un JSON de antes de que este campo
      // existiera), se infiere del endDate -mismo criterio de backfill que
      // usa la migración de base de datos-.
      isOngoing: json['isOngoing'] != null ? (json['isOngoing'] as int) == 1 : null,
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
