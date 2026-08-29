import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/models/deworming.dart';
import 'package:pet_pal/models/document.dart';
import 'package:pet_pal/models/food_allergy.dart';
import 'package:pet_pal/models/medication.dart';
import 'package:pet_pal/models/note.dart';
import 'package:pet_pal/models/search_result.dart';
import 'package:pet_pal/models/vaccination.dart';
import 'package:pet_pal/providers/pets_providers.dart';
import 'package:pet_pal/providers/search_providers.dart';
import 'package:pet_pal/screens/add_edit_appointment_screen/add_edit_appointment_screen.dart';
import 'package:pet_pal/screens/add_edit_deworming_screen/add_edit_deworming_screen.dart';
import 'package:pet_pal/screens/add_edit_document_screen/add_edit_document_screen.dart';
import 'package:pet_pal/screens/add_edit_food_allergy_screen/add_edit_food_allergy_screen.dart';
import 'package:pet_pal/screens/add_edit_medications_screen/add_edit_medications_screen.dart';
import 'package:pet_pal/screens/add_edit_note_screen/add_edit_note_screen.dart';
import 'package:pet_pal/screens/add_edit_vaccination_screen/add_edit_vaccination_screen.dart';
import 'package:pet_pal/screens/pet_detail_screen/pet_detail_screen.dart';
import 'package:pet_pal/widgets/empty_state.dart';

/// Buscador global de texto libre entre todas las mascotas -ver
/// SearchService para qué entidades y campos cubre-. Entrada desde el
/// ícono de lupa en el AppBar de home_screen.dart.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _isSearching = false;
  List<SearchResult> _results = [];

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Debounce manual (Timer, sin paquetes nuevos): evita relanzar la
  /// búsqueda -que consulta 8 tablas por cada mascota- en cada tecla.
  void _onQueryChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    final String trimmed = value.trim();

    if (trimmed.isEmpty) {
      setState(() {
        _query = '';
        _results = [];
        _isSearching = false;
      });
      return;
    }

    setState(() {
      _query = trimmed;
      _isSearching = true;
    });

    final results = await ref.read(searchServiceProvider).search(trimmed);

    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
    });
  }

  Widget _screenForResult(SearchResult result) {
    switch (result.type) {
      case SearchEntityType.pet:
        return PetDetailScreen(pet: result.pet);
      case SearchEntityType.foodAllergy:
        return AddEditFoodAllergyScreen(
          petId: result.pet.id,
          foodAllergy: result.record as FoodAllergy,
        );
      case SearchEntityType.appointment:
        return AddEditAppointmentScreen(
          petId: result.pet.id,
          appointment: result.record as Appointment,
        );
      case SearchEntityType.document:
        // A la pantalla de edición del documento (título/categoría/notas,
        // que es donde ocurrió el match), no al archivo en sí.
        return AddEditDocumentScreen(pet: result.pet, document: result.record as Document);
      case SearchEntityType.deworming:
        return AddEditDewormingScreen(pet: result.pet, deworming: result.record as Deworming);
      case SearchEntityType.medication:
        return AddEditMedicationScreen(pet: result.pet, medication: result.record as Medication);
      case SearchEntityType.note:
        return AddEditNoteScreen(pet: result.pet, note: result.record as Note);
      case SearchEntityType.vaccination:
        return AddEditVaccinationScreen(
          petId: result.pet.id,
          vaccination: result.record as Vaccination,
        );
    }
  }

  Future<void> _openResult(SearchResult result) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => _screenForResult(result)),
    );
  }

  String _resultSubtitle(SearchResult result, bool showPetName) {
    final parts = <String>[
      if (result.subtitle != null && result.subtitle!.isNotEmpty) result.subtitle!,
      if (result.date != null) DateFormat('dd/MM/yyyy').format(result.date!),
      if (showPetName) result.pet.name,
    ];
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final int petsCount = ref.watch(petsProvider).value?.length ?? 0;
    final bool showPetName = petsCount > 1;
    final grouped = groupSearchResults(_results);

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Buscar entre todas las mascotas...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: _onQueryChanged,
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                _controller.clear();
                _onQueryChanged('');
              },
            ),
        ],
      ),
      body: _buildBody(showPetName, grouped),
    );
  }

  Widget _buildBody(bool showPetName, Map<SearchEntityType, List<SearchResult>> grouped) {
    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_query.isEmpty) {
      return const EmptyState(
        icon: Icons.search,
        message: 'Escribe algo para buscar.',
        actionHint: 'Busca entre mascotas, vacunas, medicaciones, notas y más.',
      );
    }

    if (_results.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        message: 'No se encontraron resultados para "$_query".',
      );
    }

    return ListView(
      padding: const EdgeInsets.only(bottom: 16),
      children: [
        for (final entry in grouped.entries) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              '${searchEntityTypeConfigs[entry.key]!.label} (${entry.value.length})',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[700],
                  ),
            ),
          ),
          for (final result in entry.value)
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              child: ListTile(
                leading: Icon(searchEntityTypeConfigs[entry.key]!.icon),
                title: Text(result.title),
                subtitle: Text(_resultSubtitle(result, showPetName)),
                onTap: () => _openResult(result),
              ),
            ),
        ],
      ],
    );
  }
}
