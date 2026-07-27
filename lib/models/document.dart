import 'package:path/path.dart' as p;
import 'package:uuid/uuid.dart';

/// Categorías disponibles para un documento clínico.
const List<String> kDocumentCategories = [
  'Examen de laboratorio',
  'Cirugía',
  'Radiografía/Imagenología',
  'Receta',
  'Otro',
];

class Document {
  final String id;
  final String petId;
  final String categoria;
  final String titulo;
  final DateTime fecha;
  final String filePath;
  final String? notas;

  Document({
    String? id,
    required this.petId,
    required this.categoria,
    required this.titulo,
    required this.fecha,
    required this.filePath,
    this.notas,
  }) : id = id ?? const Uuid().v4();

  /// El tipo de archivo se deriva siempre de la extensión de [filePath],
  /// nunca se guarda como campo aparte (evita que quede desincronizado).
  static const List<String> _imageExtensions = ['.jpg', '.jpeg', '.png', '.heic'];

  bool get isImage =>
      _imageExtensions.contains(p.extension(filePath).toLowerCase());

  bool get isPdf => p.extension(filePath).toLowerCase() == '.pdf';

  Document copyWith({
    String? id,
    String? petId,
    String? categoria,
    String? titulo,
    DateTime? fecha,
    String? filePath,
    String? notas,
  }) {
    return Document(
      id: id ?? this.id,
      petId: petId ?? this.petId,
      categoria: categoria ?? this.categoria,
      titulo: titulo ?? this.titulo,
      fecha: fecha ?? this.fecha,
      filePath: filePath ?? this.filePath,
      notas: notas ?? this.notas,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'petId': petId,
      'categoria': categoria,
      'titulo': titulo,
      'fecha': fecha.toIso8601String(),
      'filePath': filePath,
      'notas': notas,
    };
  }

  factory Document.fromJson(Map<String, dynamic> json) {
    return Document(
      id: json['id'] as String,
      petId: json['petId'] as String,
      categoria: json['categoria'] as String,
      titulo: json['titulo'] as String,
      fecha: DateTime.parse(json['fecha'] as String),
      filePath: json['filePath'] as String,
      notas: json['notas'] as String?,
    );
  }
}
