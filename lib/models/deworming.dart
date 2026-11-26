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

  /// Los flags `clearNextDate`, `clearType` y `clearFrequency` permiten
  /// poner esos campos en null (con `??` solo no se podía).
  Deworming copyWith({
    String? id,
    String? petId,
    String? product,
    DateTime? date,
    DateTime? nextDate,
    bool clearNextDate = false,
    String? type,
    bool clearType = false,
    int? frequencyMonths,
    bool clearFrequency = false,
    int? reminderDaysAhead,
    bool? isRecurring,
  }) {
    return Deworming(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      product: product ?? this.product,
      date: date ?? this.date,
      nextDate: clearNextDate ? null : (nextDate ?? this.nextDate),
      type: clearType ? null : (type ?? this.type),
      frequencyMonths: clearFrequency ? null : (frequencyMonths ?? this.frequencyMonths),
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

  /// Fecha pendiente de "próxima desparasitación" para UI / eventos / PDF.
  /// Devuelve [nextDate] tal cual: una dosis recurrente vencida y no
  /// reemplazada sigue vencida. El avance de ciclo lo dispara un registro
  /// nuevo (_isSuperseded / idsWithVisibleNextDose), no el calendario.
  /// [now] se ignora (compatibilidad de call sites). Para preprogramar
  /// notificaciones de ciclos futuros, ver [schedulingCycleIndex].
  DateTime? effectiveNextDate({DateTime? now}) {
    return nextDate;
  }

  /// Índice desde el cual ReminderScheduler preprograma el horizonte de
  /// ciclos. Avanza mientras la ocurrencia sea anterior a hoy, para no
  /// intentar agendar pushes en el pasado. NO usar para la fecha pendiente
  /// mostrada — eso es [effectiveNextDate].
  int schedulingCycleIndex({DateTime? now}) {
    if (nextDate == null || !isRecurring || frequencyMonths == null || frequencyMonths! <= 0) {
      return 0;
    }
    final DateTime reference = now ?? DateTime.now();
    final DateTime today = DateTime(reference.year, reference.month, reference.day);
    int cycle = 0;
    while (occurrenceForCycle(cycle)!.isBefore(today)) {
      cycle++;
    }
    return cycle;
  }

  /// Fecha de la aplicación número [cycle] (0 = [nextDate]). Calcula desde
  /// [nextDate] original en cada caso, así el día del mes no se degrada
  /// (31 -> 30 -> 30 en vez de 31 -> 30 -> 28 acumulando).
  DateTime? occurrenceForCycle(int cycle) {
    if (nextDate == null) return null;
    if (!isRecurring || frequencyMonths == null || frequencyMonths! <= 0 || cycle == 0) {
      return nextDate;
    }
    return addMonths(nextDate!, cycle * frequencyMonths!);
  }

  /// Suma [months] meses a [date] sin desbordar: si el mes destino no tiene
  /// ese día (31/08 + 1 mes), usa el último día del mes (30/09) en vez de
  /// pasar al mes siguiente (1/10). Única función de suma de meses de la app.
  static DateTime addMonths(DateTime date, int months) {
    final int totalMonths = date.year * 12 + (date.month - 1) + months;
    final int year = totalMonths ~/ 12;
    final int month = totalMonths % 12 + 1;
    final int lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, date.day > lastDay ? lastDay : date.day);
  }

  static const Set<String> _coverageTypes = {'interna', 'externa', 'ambas'};

  /// Si el registro es legado (null) o tiene tipo conocido.
  bool get hasKnownCoverage => type != null && _coverageTypes.contains(type);

  /// Ids de los registros que deben mostrar "Próxima dosis" en la pantalla
  /// de desparasitaciones, según cobertura por tipo (interna/externa/ambas)
  /// en vez de solo por producto: cada tipo de parásito tiene su propio
  /// reloj de vigencia, salvo que el registro más reciente de todos cubra
  /// AMBOS -en cuyo caso resetea la cobertura completa y manda solo él-.
  ///
  /// Los registros sin [type] reconocido (legado) compiten como un grupo
  /// independiente (tipo "desconocido").
  static Set<String> idsWithVisibleNextDose(List<Deworming> dewormings) {
    if (dewormings.isEmpty) return {};

    final winners = <String>{};

    // 1. Ganadores con tipo reconocido
    final typed = dewormings
        .where((d) => d.id != null && d.hasKnownCoverage)
        .toList();
    if (typed.isNotEmpty) {
      Deworming mostRecentTyped = typed.first;
      for (final d in typed.skip(1)) {
        if (d.date.isAfter(mostRecentTyped.date)) mostRecentTyped = d;
      }

      if (mostRecentTyped.type == 'ambas') {
        winners.add(mostRecentTyped.id!);
      } else {
        winners.add(mostRecentTyped.id!);
        final String otherType =
            mostRecentTyped.type == 'interna' ? 'externa' : 'interna';
        final matchingOther =
            typed.where((d) => d.type == otherType || d.type == 'ambas');
        if (matchingOther.isNotEmpty) {
          Deworming mostRecentOther = matchingOther.first;
          for (final d in matchingOther.skip(1)) {
            if (d.date.isAfter(mostRecentOther.date)) mostRecentOther = d;
          }
          winners.add(mostRecentOther.id!);
        }
      }
    }

    // 2. Ganadores legados (independientes)
    final legacy = dewormings
        .where((d) => d.id != null && !d.hasKnownCoverage)
        .toList();
    if (legacy.isNotEmpty) {
      Deworming mostRecentLegacy = legacy.first;
      for (final d in legacy.skip(1)) {
        if (d.date.isAfter(mostRecentLegacy.date)) mostRecentLegacy = d;
      }
      
      // El legado es ganador si no está superado por cobertura completa
      if (!_isLegadoSuperseded(mostRecentLegacy, dewormings)) {
        winners.add(mostRecentLegacy.id!);
      }
    }

    return winners;
  }

  /// Tipos de cobertura ('interna'/'externa') que NUNCA tuvieron ni un solo
  /// registro -ni exclusivo ni combinado en 'ambas'- en todo el historial
  /// de la mascota. Los registros legados indican que hubo actividad,
  /// por lo que la cobertura es "desconocida", no ausente.
  static Set<String> neverRecordedCoverageTypes(List<Deworming> dewormings) {
    if (dewormings.any((d) => !d.hasKnownCoverage)) return {};

    final bool hasInterna =
        dewormings.any((d) => d.type == 'interna' || d.type == 'ambas');
    final bool hasExterna =
        dewormings.any((d) => d.type == 'externa' || d.type == 'ambas');

    final missing = <String>{};
    if (!hasInterna) missing.add('interna');
    if (!hasExterna) missing.add('externa');
    return missing;
  }

  /// Una aplicación queda superada si existe otra posterior que cubre lo
  /// mismo: 'ambas' cubre todo, el mismo tipo cubre su tipo, y un registro
  /// sin cobertura conocida (legado) lo supera cualquier aplicación más
  /// nueva. Mismo criterio que DashboardEvent._isSupersededDeworming.
  static bool _isSuperseded(Deworming deworming, List<Deworming> all) {
    if (!deworming.hasKnownCoverage) {
      return _isLegadoSuperseded(deworming, all);
    }
    return all.any((other) {
      if (identical(other, deworming) || !other.date.isAfter(deworming.date)) {
        return false;
      }
      return other.type == 'ambas' || other.type == deworming.type;
    });
  }

  static bool _isLegadoSuperseded(Deworming deworming, List<Deworming> all) {
    return all.any((other) {
      if (identical(other, deworming) || !other.date.isAfter(deworming.date)) {
        return false;
      }
      if (other.type == 'ambas') return true;
      
      // ¿Lo supera la unión interna+externa posterior?
      final newer = all.where((o) => o.date.isAfter(deworming.date));
      return newer.any((o) => o.type == 'interna') &&
             newer.any((o) => o.type == 'externa');
    });
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
        'coverage': deworming.type,
      });
      // La "próxima" de una aplicación ya reemplazada por otra más nueva no
      // es un pendiente real: mostrarla duplicaría el evento en el
      // calendario cuando ambas apuntan a la misma fecha.
      final effectiveNextDate = deworming.effectiveNextDate();
      if (effectiveNextDate != null && !_isSuperseded(deworming, dewormings)) {
        events.add({
          'id': deworming.id,
          'petId': deworming.petId,
          'type': 'next_deworming',
          'title': 'Próxima desparasitación$typeSuffix: ${deworming.product}',
          'date': effectiveNextDate,
          'name': deworming.product,
          'coverage': deworming.type,
        });
      }
    }
    return events;
  }
}