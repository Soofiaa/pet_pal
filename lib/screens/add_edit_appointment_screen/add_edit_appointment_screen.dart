import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/providers/appointment_providers.dart';
import 'package:pet_pal/providers/search_country_provider.dart';
import 'package:pet_pal/services/geocoding_service.dart';

/// Busca direcciones para el diálogo de ubicación. Firma compartida entre
/// [GeocodingService().searchAddresses] (uso real, default en producción) y
/// un fake inyectado desde tests de widget, para no golpear la red real de
/// Nominatim en `flutter test`.
typedef AddressSearcher = Future<List<String>> Function(String query);

class AddEditAppointmentScreen extends ConsumerStatefulWidget {
  final String petId;
  final Appointment? appointment;
  final AddressSearcher? addressSearcher;

  const AddEditAppointmentScreen({
    super.key,
    required this.petId,
    this.appointment,
    this.addressSearcher,
  });

  @override
  ConsumerState<AddEditAppointmentScreen> createState() => _AddEditAppointmentScreenState();
}

class _AddEditAppointmentScreenState extends ConsumerState<AddEditAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _typeController = TextEditingController();
  late DateTime _selectedDateTime;
  int _reminderDaysBefore = 1;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.appointment != null) {
      _titleController.text = widget.appointment!.title;
      _selectedDateTime = widget.appointment!.dateTime;
      _descriptionController.text = widget.appointment!.description ?? '';
      _locationController.text = widget.appointment!.location ?? '';
      _typeController.text = widget.appointment!.type ?? '';
      _reminderDaysBefore = widget.appointment!.reminderDaysBefore;
    } else {
      _selectedDateTime = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _typeController.dispose();
    super.dispose();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _selectedDateTime) {
      setState(() {
        _selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          _selectedDateTime.hour,
          _selectedDateTime.minute,
        );
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (picked != null) {
      setState(() {
        _selectedDateTime = DateTime(
          _selectedDateTime.year,
          _selectedDateTime.month,
          _selectedDateTime.day,
          picked.hour,
          picked.minute,
        );
      });
    }
  }

  void _searchLocation() async {
    // El país sesga la búsqueda hacia ese país en Nominatim -sin esto, una
    // dirección poco específica (ej. sin ciudad) puede devolver una
    // coincidencia de otro país antes que la correcta, o ninguna del país
    // esperado, ver SearchCountryNotifier-. Se lee una sola vez acá (no
    // watch): si la persona lo cambia en el Drawer mientras este diálogo ya
    // está abierto, no vale la pena rehacer la búsqueda en curso por eso.
    final String countryCode = ref.read(searchCountryProvider);

    final String? selectedAddress = await showDialog<String>(
      context: context,
      builder: (context) => _AddressSearchDialog(
        searchAddresses: widget.addressSearcher ??
            (query) => GeocodingService().searchAddresses(
                  query,
                  countryCode: countryCode,
                ),
      ),
    );

    if (selectedAddress != null && selectedAddress.isNotEmpty) {
      setState(() {
        _locationController.text = selectedAddress;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ubicación actualizada con el lugar buscado.')),
        );
      }
    }
  }

  Future<void> _saveAppointment() async {
    if (_isSaving) return;

    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Revisa los campos marcados en rojo antes de guardar.')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final notifier = ref.read(appointmentsProvider(widget.petId).notifier);
      // Se recalcula siempre contra la fecha/hora elegida, en vez de
      // preservar el valor viejo: isCompleted no tiene otro toggle manual
      // en esta app, es puramente "esta cita ya pasó" -el mismo criterio
      // que aplica el auto-completado al cargar la lista-. Preservar el
      // valor viejo sin recalcularlo era el bug: editar una cita marcada
      // completada (por vencida) y ponerle una fecha futura la dejaba
      // "completada" para siempre, tachada en la lista y sin volver a
      // agendarse en el próximo reinicio del dispositivo (ver
      // ReminderScheduler.scheduleAppointmentReminder, que sí respeta
      // isCompleted).
      final bool isCompleted = _selectedDateTime.isBefore(DateTime.now());

      if (widget.appointment != null) {
        final Appointment draft = Appointment(
          id: widget.appointment!.id,
          petId: widget.petId,
          dateTime: _selectedDateTime,
          title: _titleController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          location: _locationController.text.isEmpty ? null : _locationController.text,
          type: _typeController.text.isEmpty ? null : _typeController.text,
          isCompleted: isCompleted,
          reminderDaysBefore: _reminderDaysBefore,
        );
        await notifier.updateAppointment(widget.appointment!, draft);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cita actualizada con éxito.')),
          );
        }
      } else {
        final Appointment newAppointment = Appointment(
          petId: widget.petId,
          dateTime: _selectedDateTime,
          title: _titleController.text,
          description: _descriptionController.text.isEmpty ? null : _descriptionController.text,
          location: _locationController.text.isEmpty ? null : _locationController.text,
          type: _typeController.text.isEmpty ? null : _typeController.text,
          isCompleted: isCompleted,
          reminderDaysBefore: _reminderDaysBefore,
        );
        await notifier.addAppointment(newAppointment);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cita añadida con éxito.')),
          );
        }
      }

      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('Error al guardar la cita: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la cita: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.appointment == null ? 'Añadir Nueva Cita' : 'Editar Cita'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(
                  labelText: 'Título de la Cita',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.event_note),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Por favor, introduce un título para la cita.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16.0),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Fecha',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: DateFormat('dd/MM/yyyy').format(_selectedDateTime),
                      ),
                      onTap: () => _selectDate(context),
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Expanded(
                    child: TextFormField(
                      decoration: const InputDecoration(
                        labelText: 'Hora',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.access_time),
                      ),
                      readOnly: true,
                      controller: TextEditingController(
                        text: DateFormat('HH:mm').format(_selectedDateTime),
                      ),
                      onTap: () => _selectTime(context),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Descripción (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _locationController,
                decoration: InputDecoration(
                  labelText: 'Lugar (Opcional)',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.location_on),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.map),
                    onPressed: _searchLocation,
                    tooltip: 'Buscar en el mapa',
                  ),
                ),
              ),
              const SizedBox(height: 16.0),
              TextFormField(
                controller: _typeController,
                decoration: const InputDecoration(
                  labelText: 'Tipo de Cita (Opcional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.local_hospital),
                ),
              ),
              const SizedBox(height: 16.0),
              DropdownButtonFormField<int>(
                initialValue: _reminderDaysBefore,
                decoration: const InputDecoration(
                  labelText: 'Avisarme con anticipación',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.notification_important),
                ),
                items: const [
                  DropdownMenuItem(value: 0, child: Text('El mismo día')),
                  DropdownMenuItem(value: 1, child: Text('1 día antes')),
                  DropdownMenuItem(value: 3, child: Text('3 días antes')),
                  DropdownMenuItem(value: 7, child: Text('1 semana antes')),
                ],
                onChanged: (value) {
                  if (value != null) setState(() => _reminderDaysBefore = value);
                },
              ),
              const SizedBox(height: 24.0),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveAppointment,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(widget.appointment == null ? 'Guardar Cita' : 'Actualizar Cita'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  textStyle: const TextStyle(fontSize: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo de búsqueda de direcciones, con debounce (Timer, ~500ms) sobre
/// [searchAddresses] para no disparar una request por cada tecla -importante
/// por el rate limit de 1 req/seg de Nominatim, ver GeocodingService-. Nunca
/// bloquea: sin resultados o con error de red (searchAddresses ya devuelve
/// lista vacía en ambos casos, ver su doc) solo muestra "Sin sugerencias";
/// el usuario siempre puede cerrar el diálogo y seguir escribiendo la
/// ubicación a mano en el campo de la pantalla principal.
class _AddressSearchDialog extends StatefulWidget {
  const _AddressSearchDialog({required this.searchAddresses});

  final AddressSearcher searchAddresses;

  @override
  State<_AddressSearchDialog> createState() => _AddressSearchDialogState();
}

class _AddressSearchDialogState extends State<_AddressSearchDialog> {
  final TextEditingController _controller = TextEditingController();
  Timer? _debounce;
  List<String> _results = [];
  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() {
        _results = [];
        _isSearching = false;
        _hasSearched = false;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 500), () => _runSearch(value));
  }

  Future<void> _runSearch(String value) async {
    setState(() => _isSearching = true);
    final List<String> results = await widget.searchAddresses(value);
    if (!mounted) return;
    setState(() {
      _results = results;
      _isSearching = false;
      _hasSearched = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Buscar Ubicación'),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _controller,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Introduce un lugar o dirección',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: _onQueryChanged,
            ),
            const SizedBox(height: 12),
            if (_isSearching)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (_hasSearched && _results.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Sin sugerencias', style: TextStyle(color: Colors.grey)),
              )
            else if (_results.isNotEmpty)
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _results.length,
                  itemBuilder: (context, index) {
                    final String address = _results[index];
                    return ListTile(
                      leading: const Icon(Icons.location_on_outlined),
                      title: Text(address),
                      onTap: () => Navigator.of(context).pop(address),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}