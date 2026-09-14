import 'package:uuid/uuid.dart';

/// Un lugar guardado en el catálogo de ubicaciones, compartido entre todas
/// las mascotas. Al elegir uno desde una cita, la cita copia name/mapsUrl en
/// ese momento -no guarda una referencia a este id-, así que editar o
/// eliminar una entrada acá nunca afecta a las citas que ya la usaron.
class LocationEntry {
  final String id;
  final String name;
  final String mapsUrl;

  LocationEntry({
    String? id,
    required this.name,
    required this.mapsUrl,
  }) : id = id ?? const Uuid().v4();

  LocationEntry copyWith({
    String? id,
    String? name,
    String? mapsUrl,
  }) {
    return LocationEntry(
      id: id ?? this.id,
      name: name ?? this.name,
      mapsUrl: mapsUrl ?? this.mapsUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'mapsUrl': mapsUrl,
    };
  }

  factory LocationEntry.fromJson(Map<String, dynamic> json) {
    return LocationEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      mapsUrl: json['mapsUrl'] as String,
    );
  }
}
