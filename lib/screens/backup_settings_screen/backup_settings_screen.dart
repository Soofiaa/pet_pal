import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pet_pal/providers/appointment_providers.dart';
import 'package:pet_pal/providers/deworming_providers.dart';
import 'package:pet_pal/providers/document_providers.dart';
import 'package:pet_pal/providers/emergency_contact_providers.dart';
import 'package:pet_pal/providers/food_allergy_providers.dart';
import 'package:pet_pal/providers/medication_providers.dart';
import 'package:pet_pal/providers/note_providers.dart';
import 'package:pet_pal/providers/pets_providers.dart';
import 'package:pet_pal/providers/vaccination_providers.dart';
import 'package:pet_pal/providers/vital_sign_providers.dart';
import 'package:pet_pal/providers/weight_record_providers.dart';
import 'package:pet_pal/services/biometric_service.dart';
import 'package:pet_pal/services/data_backup_service.dart';
import 'package:pet_pal/services/notification_service.dart';
import 'package:pet_pal/services/orphan_cleanup_service.dart';
import 'package:pet_pal/utils/backup_password_dialog.dart';

enum BackupSettingsSection { notifications, backup }

class BackupSettingsScreen extends ConsumerStatefulWidget {
  final BackupSettingsSection section;

  const BackupSettingsScreen({super.key, required this.section});

  @override
  ConsumerState<BackupSettingsScreen> createState() =>
      _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends ConsumerState<BackupSettingsScreen>
    with WidgetsBindingObserver {
  final DataBackupService _backupService = DataBackupService();
  bool _isWorking = false;
  String? _lastMessage;

  bool? _notificationsEnabled;
  bool? _exactAlarmsEnabled;
  QuarantineSummary? _quarantine;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotificationStatus();
    if (widget.section == BackupSettingsSection.backup) {
      _loadQuarantine();
    }
  }

  Future<void> _loadQuarantine() async {
    QuarantineSummary? summary;
    try {
      summary = await OrphanCleanupService.quarantineSummary();
    } catch (_) {
      // Es información secundaria: si no se puede leer, no se muestra la tarjeta.
    }
    if (!mounted) return;
    setState(() => _quarantine = summary);
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _confirmDeleteQuarantine() async {
    final summary = _quarantine;
    if (summary == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar archivos antiguos'),
        content: Text(
          'Se borrarán definitivamente ${summary.fileCount} archivos '
          '(${_formatBytes(summary.totalBytes)}). Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await OrphanCleanupService.deleteQuarantine();
      if (!mounted) return;
      setState(() => _lastMessage = 'Archivos antiguos eliminados.');
    } catch (e) {
      if (!mounted) return;
      setState(() => _lastMessage = 'No se pudieron eliminar los archivos antiguos: $e');
    }
    await _loadQuarantine();
  }

  Widget _buildQuarantineCard(QuarantineSummary summary) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Archivos antiguos sin uso', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Una limpieza anterior apartó ${summary.fileCount} archivos '
              '(${_formatBytes(summary.totalBytes)}) que ninguna mascota, nota, '
              'vacuna o documento usaba. Puedes eliminarlos para liberar espacio.',
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isWorking ? null : _confirmDeleteQuarantine,
                icon: const Icon(Icons.delete_sweep),
                label: const Text('Eliminar archivos antiguos'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // El usuario puede haber cambiado el permiso desde Ajustes del sistema
    // y vuelto a la app, así que refrescamos el estado al reanudar.
    if (state == AppLifecycleState.resumed) {
      _loadNotificationStatus();
    }
  }

  Future<void> _loadNotificationStatus() async {
    final notificationsEnabled =
        await NotificationService().areNotificationsEnabled();
    final exactAlarmsEnabled =
        await NotificationService().canScheduleExactAlarms();

    if (!mounted) return;
    setState(() {
      _notificationsEnabled = notificationsEnabled;
      _exactAlarmsEnabled = exactAlarmsEnabled;
    });
  }

  Future<void> _fixNotificationsPermission() async {
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  }

  Future<void> _fixExactAlarmsPermission() async {
    await NotificationService().requestExactAlarmsPermission();
    await _loadNotificationStatus();
  }

  Future<void> _exportBackup() async {
    // Verificar autenticación biométrica antes de proceder
    final bool authenticated = await BiometricService.authenticate(
      localizedReason: 'Autentícate para crear un respaldo de tus datos',
    );

    if (!authenticated || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Autenticación requerida para crear respaldo')),
        );
      }
      return;
    }

    final String? password = await promptForBackupPassword(
      context,
      title: 'Contraseña del respaldo',
      confirmLabel: 'Exportar',
      requireConfirmation: true,
    );
    if (password == null || !mounted) return;

    setState(() {
      _isWorking = true;
      _lastMessage = null;
    });

    final String result = await _backupService.exportAllData(password);

    if (!mounted) return;
    setState(() {
      _isWorking = false;
      _lastMessage = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  Future<void> _importBackup() async {
    // Verificar autenticación biométrica antes de proceder
    final bool authenticated = await BiometricService.authenticate(
      localizedReason: 'Autentícate para restaurar un respaldo de datos',
    );

    if (!authenticated || !mounted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Autenticación requerida para restaurar respaldo')),
        );
      }
      return;
    }

    // La contraseña se pide primero porque hace falta descifrar el ZIP para
    // poder mostrarle al usuario de qué respaldo se trata (fecha, cantidad
    // de mascotas) antes de pedirle que confirme el reemplazo destructivo.
    final String? password = await promptForBackupPassword(
      context,
      title: 'Contraseña del respaldo',
      confirmLabel: 'Continuar',
    );
    if (password == null || !mounted) return;

    setState(() {
      _isWorking = true;
      _lastMessage = null;
    });

    final BackupLoadResult loadResult =
        await _backupService.loadBackupForRestore(password: password);

    if (!mounted) return;
    setState(() {
      _isWorking = false;
    });

    if (loadResult.error != null) {
      setState(() {
        _lastMessage = loadResult.error;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(loadResult.error!)));
      return;
    }

    final BackupRestorePreview preview = loadResult.preview!;
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        final String petsSummary = _describePets(preview.petNames);
        final String backupDescription = preview.timestamp != null
            ? 'Respaldo del ${DateFormat('dd/MM/yyyy HH:mm').format(preview.timestamp!.toLocal())}. $petsSummary'
            : 'Este respaldo no incluye fecha (es de un formato anterior). $petsSummary';

        return AlertDialog(
          title: const Text('Restaurar respaldo'),
          content: Text(
            '$backupDescription\n\n'
            'Esto reemplazará toda la información actual de PetPal por la información de este respaldo. Esta acción no se puede deshacer. ¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
                foregroundColor: Theme.of(context).colorScheme.onError,
              ),
              child: const Text('Restaurar'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() {
      _isWorking = true;
    });

    final String result = await _backupService.applyRestoredBackup(preview.restoredData);

    if (!mounted) return;

    // applyRestoredBackup no distingue éxito/error con un tipo de resultado
    // (devuelve un String para ambos casos); "Error" es el único prefijo
    // que usa en sus mensajes de falla, así que es la única señal
    // disponible sin tocar data_backup_service.dart.
    if (!result.startsWith('Error')) {
      _invalidateAllDataProviders();
    }

    setState(() {
      _isWorking = false;
      _lastMessage = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }

  /// Tras restaurar un respaldo, TODOS los datos de TODAS las mascotas
  /// fueron reemplazados en la base de datos. Riverpod (2.6.1, la versión
  /// de este proyecto) no ofrece una forma de invalidar todo el estado
  /// cacheado de una sola vez -solo permite invalidar providers puntuales
  /// por su referencia-, así que hay que enumerar explícitamente cada
  /// provider raíz que lee la base de datos directamente. Los providers
  /// derivados que solo hacen ref.watch de estos (p. ej.
  /// todayDashboardProvider, que depende de petsProvider) no hace falta
  /// listarlos: Riverpod los invalida en cascada automáticamente.
  ///
  /// Los .family de abajo se invalidan SIN pasarles el petId: invalidar un
  /// family provider así invalida todas las instancias ya creadas para
  /// cualquier mascota, no solo una -comportamiento documentado de
  /// Riverpod-, así que cubre también los providers .family que hayan
  /// quedado cacheados con datos de mascotas que ya no existen tras la
  /// restauración.
  void _invalidateAllDataProviders() {
    ref.invalidate(petsProvider);
    ref.invalidate(emergencyContactsProvider);

    ref.invalidate(notesProvider);
    ref.invalidate(weightRecordsProvider);
    ref.invalidate(appointmentsProvider);
    ref.invalidate(vaccinationsProvider);
    ref.invalidate(foodAllergiesProvider);
    ref.invalidate(medicationsProvider);
    ref.invalidate(dewormingsProvider);
    ref.invalidate(documentsProvider);
    ref.invalidate(vitalSignRecordsProvider);
  }

  /// Describe las mascotas de un [BackupRestorePreview] para el diálogo de
  /// confirmación: nombres reales en vez de solo la cantidad, truncando si
  /// son muchas y avisando explícitamente si el backup no trae ninguna
  /// -señal de que puede tratarse del archivo equivocado-.
  static String _describePets(List<String> petNames) {
    if (petNames.isEmpty) {
      return 'Este respaldo parece estar vacío: no contiene ninguna mascota. '
          'Verifica que sea el archivo correcto antes de continuar.';
    }

    const int maxShown = 5;
    if (petNames.length <= maxShown) {
      return 'Incluye a: ${petNames.join(', ')}.';
    }

    final String shown = petNames.take(maxShown).join(', ');
    final int remaining = petNames.length - maxShown;
    return 'Incluye a: $shown... y $remaining más.';
  }

  Widget _buildPermissionStatusRow({
    required String label,
    required bool? granted,
    required VoidCallback onFix,
  }) {
    final bool isGranted = granted == true;
    return Row(
      children: [
        Icon(
          isGranted ? Icons.check_circle : Icons.error,
          color: isGranted ? Colors.green : Colors.red,
        ),
        const SizedBox(width: 12),
        Expanded(child: Text(label)),
        if (!isGranted)
          TextButton(
            onPressed: onFix,
            child: const Text('Activar'),
          ),
      ],
    );
  }

  Widget _buildNotificationsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Estado de los permisos necesarios para recibir los recordatorios de medicación, vacunas, desparasitaciones y citas.',
            ),
            const SizedBox(height: 16),
            _buildPermissionStatusRow(
              label: 'Notificaciones habilitadas',
              granted: _notificationsEnabled,
              onFix: _fixNotificationsPermission,
            ),
            const SizedBox(height: 12),
            _buildPermissionStatusRow(
              label: 'Alarmas exactas habilitadas',
              granted: _exactAlarmsEnabled,
              onFix: _fixExactAlarmsPermission,
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildBackupCards() {
    return [
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Copia de seguridad completa', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Exporta mascotas, vacunas, notas, citas, peso, alergias, medicación, desparasitaciones e imágenes asociadas en un archivo ZIP.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isWorking ? null : _exportBackup,
                  icon: const Icon(Icons.archive),
                  label: const Text('Crear respaldo ZIP'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 12),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Restaurar respaldo', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              const Text(
                'Selecciona un respaldo ZIP válido de PetPal. Antes de importar, la app valida que tenga versión, backup.json, mascotas y archivos internos.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isWorking ? null : _importBackup,
                  icon: const Icon(Icons.restore),
                  label: const Text('Restaurar respaldo'),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 16),
      if (_quarantine != null && _quarantine!.fileCount > 0) ...[
        _buildQuarantineCard(_quarantine!),
        const SizedBox(height: 16),
      ],
      if (_isWorking) const Center(child: CircularProgressIndicator()),
      if (_lastMessage != null) ...[
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(_lastMessage!),
          ),
        ),
      ],
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isNotifications = widget.section == BackupSettingsSection.notifications;
    return Scaffold(
      appBar: AppBar(
        title: Text(isNotifications ? 'Notificaciones' : 'Respaldo y restauración'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: isNotifications ? [_buildNotificationsCard()] : _buildBackupCards(),
      ),
    );
  }
}
