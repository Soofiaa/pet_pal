import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

class Pet {
  final String id;
  final String name;
  final String species;
  final String breed;
  final DateTime dob;
  final String color;
  final String? imageUrl;

  Pet({
    String? id,
    required this.name,
    required this.species,
    required this.breed,
    required this.dob,
    required this.color,
    this.imageUrl,
  }) : id = id ?? const Uuid().v4();

  // Método para calcular la edad de forma precisa y detallada
  String get detailedAge {
    final now = DateTime.now();
    int years = now.year - dob.year;
    int months = now.month - dob.month;
    int days = now.day - dob.day;

    if (days < 0) {
      months--;
      final lastMonth = DateTime(now.year, now.month, 0);
      days = lastMonth.day + days;
    }
    if (months < 0) {
      years--;
      months += 12;
    }

    if (years > 0) {
      return '$years año${years > 1 ? 's' : ''}${months > 0 ? ', $months mes${months > 1 ? 'es' : ''}' : ''}';
    } else if (months > 0) {
      return '$months mes${months > 1 ? 'es' : ''}${days > 0 ? ', $days día${days > 1 ? 's' : ''}' : ''}';
    } else {
      return '$days día${days > 1 ? 's' : ''}';
    }
  }

  String get formattedDob {
    return DateFormat('dd/MM/yyyy').format(dob);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'species': species,
      'breed': breed,
      'dob': dob.toIso8601String(),
      'color': color,
      'imageUrl': imageUrl,
    };
  }

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] as String,
      name: json['name'] as String,
      species: json['species'] as String,
      breed: json['breed'] as String,
      dob: DateTime.parse(json['dob'] as String),
      color: json['color'] as String,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}