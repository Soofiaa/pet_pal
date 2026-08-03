import 'package:uuid/uuid.dart';

class EmergencyContact {
  final String id;
  final String name;
  final String phone;
  final String? category; // 'Veterinario', 'Urgencias', 'Paseador', 'Otros'
  final String? notes;

  EmergencyContact({
    String? id,
    required this.name,
    required this.phone,
    this.category,
    this.notes,
  }) : id = id ?? const Uuid().v4();

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phone,
    String? category,
    String? notes,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      category: category ?? this.category,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'category': category,
      'notes': notes,
    };
  }

  factory EmergencyContact.fromJson(Map<String, dynamic> json) {
    return EmergencyContact(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      category: json['category'] as String?,
      notes: json['notes'] as String?,
    );
  }
}
