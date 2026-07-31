import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';
import 'package:pet_pal/services/data_backup_service.dart';
import 'package:pet_pal/services/notification_service.dart';
import 'package:pet_pal/utils/backup_password_dialog.dart';

class BackupSettingsScreen extends StatefulWidget {
  const BackupSettingsScreen({super.key});

  @override
  State<BackupSettingsScreen> createState() => _BackupSettingsScreenState();
}

class _BackupSettingsScreenState extends State<BackupSettingsScreen>
    with WidgetsBindingObserver {
  final DataBackupService _backupService = DataBackupService();
  bool _isWorking = false;
  String? _lastMessage;

  bool? _notificationsEnabled;
  bool? _exactAlarmsEnabled;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadNotificationStatus();
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
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Restaurar respaldo'),
          content: const Text(
            'Esto reemplazará toda la información actual de PetPal por la información del respaldo seleccionado. Esta acción no se puede deshacer. ¿Deseas continuar?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Restaurar', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    final String? password = await promptForBackupPassword(
      context,
      title: 'Contraseña del respaldo',
      confirmLabel: 'Importar',
    );
    if (password == null || !mounted) return;

    setState(() {
      _isWorking = true;
      _lastMessage = null;
    });

    final String result = await _backupService.importAllData(password: password);

    if (!mounted) return;
    setState(() {
      _isWorking = false;
      _lastMessage = result;
    });

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Respaldo'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Notificaciones', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 8),
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
          ),
          const SizedBox(height: 12),
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
          if (_isWorking)
            const Center(child: CircularProgressIndicator()),
          if (_lastMessage != null) ...[
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_lastMessage!),
              ),
            ),
          ],
          const SizedBox(height: 24),
          const Text(
            'Pendiente futuro: respaldo opcional en nube. Por ahora se mantiene fuera del alcance.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
    );
  }
}
