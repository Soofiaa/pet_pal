import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pet_pal/models/vaccination.dart';

/// Pregunta cuál de las vacunas [similar] reemplaza la nueva. Devuelve la
/// elegida, o null si el usuario dice que son independientes o cierra el
/// diálogo (en ambos casos no se reemplaza nada).
Future<Vaccination?> showReplaceVaccinationDialog(
  BuildContext context,
  List<Vaccination> similar,
) {
  return showDialog<Vaccination>(
    context: context,
    builder: (context) => SimpleDialog(
      title: const Text('¿Esta vacuna reemplaza a alguna anterior?'),
      children: [
        for (final v in similar)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(context, v),
            child: Text(
              '${v.vaccineName} · ${DateFormat('dd/MM/yyyy').format(v.date)}',
            ),
          ),
        SimpleDialogOption(
          onPressed: () => Navigator.pop(context),
          child: const Text('No, son independientes'),
        ),
      ],
    ),
  );
}
