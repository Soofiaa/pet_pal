import 'package:flutter/material.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

class CalendarScreen extends StatefulWidget {
  final Pet pet;

  const CalendarScreen({super.key, required this.pet});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  late Future<List<Map<String, dynamic>>> _allEvents;

  final Map<String, Map<String, dynamic>> _eventDetails = {
    'note': {'icon': Icons.description, 'color': Colors.blue},
    'appointment': {'icon': Icons.calendar_today, 'color': Colors.orange},
    'vaccination': {'icon': Icons.local_hospital, 'color': Colors.green},
    'medication': {'icon': Icons.medical_services, 'color': Colors.purple},
    'deworming': {'icon': Icons.bug_report, 'color': Colors.red},
    'allergy': {'icon': Icons.warning, 'color': Colors.yellow},
    'weight': {'icon': Icons.scale, 'color': Colors.teal},
    'peso': {'icon': Icons.scale, 'color': Colors.teal},
    'desparasitacion': {'icon': Icons.bug_report, 'color': Colors.red},
  };

  @override
  void initState() {
    super.initState();
    _allEvents = DatabaseHelper().getAllEventsForPet(widget.pet.id);
  }

  bool isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) {
      return false;
    }
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<Map<String, dynamic>> _getEventsForDay(DateTime day, List<Map<String, dynamic>> allEvents) {
    return allEvents.where((event) {
      final eventDate = event['date'];
      final DateTime? parsedDate = (eventDate is String) ? DateTime.tryParse(eventDate) : eventDate as DateTime?;

      if (parsedDate == null) return false;
      return isSameDay(parsedDate, day);
    }).toList();
  }

  List<Map<String, dynamic>> _getMonthlyEvents(List<Map<String, dynamic>> allEvents, DateTime focusedMonth) {
    final firstDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month, 1);
    final lastDayOfMonth = DateTime(focusedMonth.year, focusedMonth.month + 1, 0);

    final monthlyEvents = allEvents.where((event) {
      final eventDate = event['date'];
      final DateTime? parsedDate = (eventDate is String) ? DateTime.tryParse(eventDate) : eventDate as DateTime?;
      if (parsedDate == null) return false;

      return parsedDate.isAfter(firstDayOfMonth.subtract(const Duration(days: 1))) &&
          parsedDate.isBefore(lastDayOfMonth.add(const Duration(days: 1)));
    }).toList();

    monthlyEvents.sort((a, b) {
      final dateA = (a['date'] is String) ? DateTime.tryParse(a['date'] as String) : a['date'] as DateTime?;
      final dateB = (b['date'] is String) ? DateTime.tryParse(b['date'] as String) : b['date'] as DateTime?;

      if (dateA == null || dateB == null) return 0;
      return dateA.compareTo(dateB);
    });

    return monthlyEvents;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Calendario de ${widget.pet.name}'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _allEvents,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No hay eventos registrados para esta mascota.'));
          } else {
            final allEvents = snapshot.data!;
            final monthlyEvents = _getMonthlyEvents(allEvents, _focusedDay);

            return Column(
              children: [
                TableCalendar(
                  locale: 'es_ES',
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,
                  selectedDayPredicate: (day) {
                    return isSameDay(_selectedDay, day);
                  },
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: null,
                  onPageChanged: (focusedDay) {
                    setState(() {
                      _focusedDay = focusedDay;
                    });
                  },
                  eventLoader: (day) => _getEventsForDay(day, allEvents),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                  startingDayOfWeek: StartingDayOfWeek.monday, // <-- La semana empieza en lunes
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, date, events) {
                      if (events.isNotEmpty) {
                        return Positioned(
                          right: 1,
                          bottom: 1,
                          child: _buildEventsMarker(date, events),
                        );
                      }
                      return null;
                    },
                  ),
                ),
                const Divider(),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Eventos de ${DateFormat('MMMM yyyy', 'es').format(_focusedDay)}',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: monthlyEvents.isEmpty
                              ? const Center(child: Text('No hay eventos en este mes.'))
                              : ListView.builder(
                            itemCount: monthlyEvents.length,
                            itemBuilder: (context, index) {
                              final event = monthlyEvents[index];
                              final eventDate = (event['date'] is String) ? DateTime.tryParse(event['date'] as String) : event['date'] as DateTime?;

                              if (eventDate == null) return const SizedBox.shrink();
                              final isPast = eventDate.isBefore(DateTime.now());

                              final eventType = event['type'] as String? ?? 'Desconocido';
                              final eventIcon = _eventDetails[eventType.toLowerCase()]?['icon'] as IconData? ?? Icons.help_outline;
                              final eventColor = _eventDetails[eventType.toLowerCase()]?['color'] as Color? ?? Colors.grey;

                              return Card(
                                color: isPast ? Colors.grey[300] : Colors.white,
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                child: ListTile(
                                  leading: Icon(
                                    eventIcon,
                                    color: eventColor,
                                  ),
                                  title: Text(
                                    event['title'] as String,
                                    style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: isPast ? Colors.grey[600] : Colors.black
                                    ),
                                  ),
                                  subtitle: Text(
                                    DateFormat('dd/MM/yyyy').format(eventDate),
                                    style: TextStyle(
                                        color: isPast ? Colors.grey[500] : Colors.grey[600]
                                    ),
                                  ),
                                  trailing: isPast
                                      ? const Icon(Icons.check_circle_outline, color: Colors.green)
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }
        },
      ),
    );
  }

  Widget _buildEventsMarker(DateTime date, List events) {
    return Container(
      width: 16.0,
      height: 16.0,
      decoration: BoxDecoration(
        color: Colors.blue[300],
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        '${events.length}',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12.0,
        ),
      ),
    );
  }
}