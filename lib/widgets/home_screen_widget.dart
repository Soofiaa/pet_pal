import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:home_widget/home_widget.dart';
import 'package:intl/intl.dart';

class HomeScreenWidget extends StatelessWidget {
  const HomeScreenWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0F766E),
          brightness: Brightness.light,
        ),
      ),
      home: const _WidgetContent(),
    );
  }
}

class _WidgetContent extends StatelessWidget {
  const _WidgetContent();

  Future<Map<String, dynamic>?> _loadWidgetData() async {
    final raw = await HomeWidget.getWidgetData<String>('_petPalWidget');
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Center(
        child: FutureBuilder<Map<String, dynamic>?>(
          future: _loadWidgetData(),
          builder: (context, snapshot) {
            if (!snapshot.hasData || snapshot.data == null) {
              return _buildEmptyState(context);
            }

            final data = snapshot.data!;
            final reminders = data['reminders'] as List<dynamic>? ?? [];
            final lastUpdated = data['lastUpdated'] as String?;

            if (reminders.isEmpty) {
              return _buildNoReminders(context, lastUpdated);
            }

            return _buildRemindersList(context, reminders, lastUpdated);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.pets,
          size: 48,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          'PetPal',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'Abre la app para ver recordatorios',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }

  Widget _buildNoReminders(BuildContext context, String? lastUpdated) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.check_circle,
          size: 48,
          color: Colors.green,
        ),
        const SizedBox(height: 16),
        Text(
          '¡Todo al día!',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          'No hay recordatorios para hoy',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
        if (lastUpdated != null) ...[
          const SizedBox(height: 16),
          Text(
            'Actualizado: ${_formatTime(lastUpdated)}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 10,
                ),
          ),
        ],
      ],
    );
  }

  Widget _buildRemindersList(
    BuildContext context,
    List<dynamic> reminders,
    String? lastUpdated,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.pets,
                size: 24,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'PetPal',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Recordatorios de hoy',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              itemCount: reminders.length > 5 ? 5 : reminders.length,
              itemBuilder: (context, index) {
                final reminder = reminders[index] as Map<String, dynamic>;
                return _buildReminderCard(context, reminder);
              },
            ),
          ),
          if (reminders.length > 5) ...[
            const SizedBox(height: 8),
            Text(
              'Y ${reminders.length - 5} más...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
          if (lastUpdated != null) ...[
            const SizedBox(height: 8),
            Text(
              'Actualizado: ${_formatTime(lastUpdated)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 10,
                  ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildReminderCard(BuildContext context, Map<String, dynamic> reminder) {
    final petName = reminder['petName'] as String? ?? 'Mascota';
    final type = reminder['type'] as String? ?? '';
    final time = reminder['time'] as String? ?? '';
    final isUrgent = reminder['isUrgent'] as bool? ?? false;

    IconData icon;
    Color iconColor;

    switch (type.toLowerCase()) {
      case 'vacuna':
        icon = Icons.vaccines;
        iconColor = Colors.blue;
        break;
      case 'medicación':
        icon = Icons.medication;
        iconColor = Colors.purple;
        break;
      case 'cita':
        icon = Icons.calendar_today;
        iconColor = Colors.orange;
        break;
      case 'desparasitación':
        icon = Icons.healing;
        iconColor = Colors.teal;
        break;
      default:
        icon = Icons.notifications;
        iconColor = Theme.of(context).colorScheme.primary;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        dense: true,
        leading: Icon(icon, color: iconColor, size: 20),
        title: Text(
          petName,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Text(
          type,
          style: const TextStyle(fontSize: 12),
        ),
        trailing: Text(
          time,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isUrgent ? FontWeight.bold : FontWeight.normal,
            color: isUrgent ? Colors.red : null,
          ),
        ),
      ),
    );
  }

  String _formatTime(String isoString) {
    try {
      final date = DateTime.parse(isoString);
      return DateFormat('HH:mm').format(date);
    } catch (e) {
      return isoString;
    }
  }
}
