import 'dart:io';

import 'package:flutter/material.dart';
import 'package:pet_pal/models/pet.dart';

/// Tarjeta de una mascota para la pantalla "Mis Mascotas": la foto ocupa
/// toda la tarjeta y el nombre, la especie y la edad van encima, sobre un
/// degradado oscuro que asegura el contraste sin importar la foto. Sin foto
/// válida usa un fondo de color con el ícono de mascota.
class PetCard extends StatelessWidget {
  const PetCard({super.key, required this.pet, required this.onTap});

  final Pet pet;
  final VoidCallback onTap;

  bool get _hasValidImage {
    final path = pet.imageUrl;
    if (path == null || path.trim().isEmpty) return false;
    return File(path).existsSync();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final subtitle = '${pet.species} · ${pet.detailedAge}';

    return Semantics(
      button: true,
      label: '${pet.name}, $subtitle',
      excludeSemantics: true,
      onTap: onTap,
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 3,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_hasValidImage)
                Image.file(
                  File(pet.imageUrl!),
                  fit: BoxFit.cover,
                  cacheWidth: 600,
                  errorBuilder: (_, _, _) => _Placeholder(colorScheme: colorScheme),
                )
              else
                _Placeholder(colorScheme: colorScheme),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.transparent, Color(0xCC000000)],
                    stops: [0, 0.5, 1],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      pet.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.colorScheme});

  final ColorScheme colorScheme;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: colorScheme.primaryContainer,
      child: Center(
        child: Icon(Icons.pets, size: 64, color: colorScheme.onPrimaryContainer.withValues(alpha: 0.6)),
      ),
    );
  }
}
