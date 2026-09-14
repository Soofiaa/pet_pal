import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/models/appointment.dart';
import 'package:pet_pal/models/location_entry.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/providers/appointment_providers.dart';
import 'package:pet_pal/providers/location_entry_providers.dart';
import 'package:url_launcher/url_launcher.dart';

/// Abre un enlace (el de Google Maps pegado por la persona). Firma
/// compartida entre [launchUrl] (uso real, default en producción) y un fake
/// inyectado desde tests de widget, para no golpear url_launcher de verdad
/// en `flutter test`.
typedef LinkLauncher = Future<bool> Function(Uri uri);

class AddEditAppointmentScreen extends ConsumerStatefulWidget {
  final String petId;
  final Appointment? appointment;
  final LinkLauncher? urlLauncher;

  const AddEditAppointmentScreen({
    super.key,
    required this.petId,
    this.appointment,
    this.urlLauncher,
  });

  @override
  ConsumerState<AddEditAppointmentScreen> createState() => _AddEditAppointmentScreenState();
}

class _AddEditAppointmentScreenState extends ConsumerState<AddEditAppointmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _locationMapsUrlController = TextEditingController();
  final _typeController = TextEditingController();
  late DateTime _selectedDateTime;
  int _reminderDaysBefore = 1;
  bool _isSaving = false;

  /// Selector "guardados"/"nuevo" del lugar. Siempre arranca en "nuevo"
  /// -incluso editando una cita existente-: sus controllers ya llegan
  /// precargados con location/locationMapsUrl (ver initState), así que no
  /// hay ninguna entrada del catálogo que preseleccionar de entrada.
  bool _useCatalogLocation = false;
  String? _selectedCatalogEntryId;

  /// Solo aplica en modo "nuevo": si la persona tipeó un lugar a mano y
  /// marca esto, _saveAppointment además crea una entrada nueva en el
  /// catálogo de ubicaciones al guardar la cita.
  bool _saveToCatalog = false;

  @override
  void initState() {
    super.initState();
    if (widget.appointment != null) {
      _titleController.text = widget.appointment!.title;
      _selectedDateTime = widget.appointment!.dateTime;
      _descriptionController.text = widget.appointment!.description ?? '';
      _locationController.text = widget.appointment!.location ?? '';
      _locationMapsUrlController.text = widget.appointment!.locationMapsUrl ?? '';
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
    _locationMapsUrlController.dispose();
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

  /// "Parece una URL" a propósito laxo (solo el esquema): no vale la pena
  /// validar que sea específicamente un link de Google Maps ni que el link
  /// funcione de verdad -sería sobre-ingeniería para un campo opcional que
  /// de todos modos nunca bloquea el guardado-.
  bool get _mapsUrlLooksValid {
    final String text = _locationMapsUrlController.text.trim();
    return text.startsWith('http://') || text.startsWith('https://');
  }

  /// Abre el link de Maps pegado por la persona. Nunca lanza hacia la UI:
  /// un link roto, sin esquema, o sin ninguna app que lo maneje en el
  /// dispositivo terminan todos en el mismo SnackBar discreto -el campo es
  /// una ayuda opcional, no algo que deba interrumpir el flujo de la cita-.
  Future<void> _openInMaps() async {
    final String url = _locationMapsUrlController.text.trim();
    if (url.isEmpty) return;

    bool opened = false;
    try {
      final Uri uri = Uri.parse(url);
      final LinkLauncher launcher = widget.urlLauncher ?? launchUrl;
      opened = await launcher(uri);
    } catch (e) {
      debugPrint('Error al abrir el enlace de Maps ("$url"): $e');
      opened = false;
    }

    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo abrir el enlace.')),
      );
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
          locationMapsUrl:
              _locationMapsUrlController.text.trim().isEmpty ? null : _locationMapsUrlController.text.trim(),
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
          locationMapsUrl:
              _locationMapsUrlController.text.trim().isEmpty ? null : _locationMapsUrlController.text.trim(),
        );
        await notifier.addAppointment(newAppointment);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cita añadida con éxito.')),
          );
        }
      }

      // Solo en modo "nuevo" (eligiendo del catálogo no hay nada que
      // agregar: la entrada ya existe ahí). Copia congelada: esta entrada
      // nueva no tiene ninguna relación con la cita recién guardada -que ya
      // quedó persistida arriba con su propio name/mapsUrl-, así que
      // editarla después no la afecta.
      if (!_useCatalogLocation && _saveToCatalog) {
        final String catalogName = _locationController.text.trim();
        if (catalogName.isNotEmpty) {
          await ref.read(locationEntriesProvider.notifier).addEntry(
                LocationEntry(
                  name: catalogName,
                  mapsUrl: _locationMapsUrlController.text.trim(),
                ),
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

  /// Dropdown con las entradas del catálogo (locationEntriesProvider). Elegir
  /// una copia su name/mapsUrl a los controllers de siempre en ese mismo
  /// instante -copia congelada-: _saveAppointment no distingue de dónde
  /// vino el texto, así que editar o borrar esta entrada del catálogo
  /// después nunca afecta a la cita ya guardada.
  Widget _buildCatalogLocationPicker(BuildContext context) {
    final AsyncValue<List<LocationEntry>> entriesAsync = ref.watch(locationEntriesProvider);

    return entriesAsync.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Text(
            'Todavía no tienes lugares guardados. Ingresa uno nuevo y marca '
            '"Guardar en mi catálogo de lugares" para que quede disponible acá.',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
          );
        }

        final bool selectionStillValid = entries.any((e) => e.id == _selectedCatalogEntryId);

        return DropdownButtonFormField<String>(
          initialValue: selectionStillValid ? _selectedCatalogEntryId : null,
          decoration: const InputDecoration(
            labelText: 'Elige un lugar guardado',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.bookmark),
          ),
          items: entries
              .map((entry) => DropdownMenuItem(value: entry.id, child: Text(entry.name)))
              .toList(),
          onChanged: (value) {
            setState(() {
              _selectedCatalogEntryId = value;
              final LocationEntry selected = entries.firstWhere((e) => e.id == value);
              _locationController.text = selected.name;
              _locationMapsUrlController.text = selected.mapsUrl;
            });
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error al cargar el catálogo: $e'),
    );
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
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                    value: true,
                    label: Text('Elegir de mis lugares guardados'),
                    icon: Icon(Icons.bookmark),
                  ),
                  ButtonSegment(
                    value: false,
                    label: Text('Ingresar uno nuevo'),
                    icon: Icon(Icons.edit_location_alt),
                  ),
                ],
                selected: {_useCatalogLocation},
                onSelectionChanged: (selection) => setState(() {
                  _useCatalogLocation = selection.first;
                  // Cambiar a "guardados" sin nada elegido todavía: se
                  // limpia lo que hubiera tipeado a mano antes, para que un
                  // guardado accidental sin elegir nada no arrastre ese
                  // texto viejo (_saveAppointment siempre lee de estos
                  // controllers, sea cual sea el modo).
                  if (_useCatalogLocation && _selectedCatalogEntryId == null) {
                    _locationController.clear();
                    _locationMapsUrlController.clear();
                  }
                }),
              ),
              const SizedBox(height: 16.0),
              if (_useCatalogLocation)
                _buildCatalogLocationPicker(context)
              else ...[
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Lugar (Opcional)',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.location_on),
                  ),
                ),
                const SizedBox(height: 8.0),
                Text(
                  'Busca el lugar en Google Maps, toca Compartir, y pega el enlace aquí.',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8.0),
                TextFormField(
                  controller: _locationMapsUrlController,
                  decoration: InputDecoration(
                    labelText: 'Enlace de Google Maps (opcional)',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.link),
                    helperText: _locationMapsUrlController.text.isNotEmpty && !_mapsUrlLooksValid
                        ? 'Pega el enlace que compartiste desde Google Maps.'
                        : null,
                  ),
                  keyboardType: TextInputType.url,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8.0),
                CheckboxListTile(
                  value: _saveToCatalog,
                  onChanged: (checked) => setState(() => _saveToCatalog = checked ?? false),
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Guardar en mi catálogo de lugares'),
                ),
              ],
              if (_locationMapsUrlController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 8.0),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    onPressed: _openInMaps,
                    icon: const Text('📍'),
                    label: const Text('Abrir en Maps'),
                  ),
                ),
              ],
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
