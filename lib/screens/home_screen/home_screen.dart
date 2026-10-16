import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/screens/add_edit_pet_screen/add_edit_pet_screen.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/pets_providers.dart';
import 'package:pet_pal/screens/pet_detail_screen/pet_detail_screen.dart';
import 'package:pet_pal/screens/emergency_contacts_screen/emergency_contacts_screen.dart';
import 'package:pet_pal/screens/vaccination_products_screen/vaccination_products_screen.dart';
import 'package:pet_pal/screens/deworming_products_screen/deworming_products_screen.dart';
import 'package:pet_pal/screens/location_entries_screen/location_entries_screen.dart';
import 'package:pet_pal/screens/backup_settings_screen/backup_settings_screen.dart';
import 'package:pet_pal/screens/guide_screen/guide_screen.dart';
import 'package:pet_pal/screens/search_screen/search_screen.dart';
import 'package:pet_pal/providers/theme_mode_provider.dart';
import 'package:pet_pal/utils/layout_constants.dart';
import 'package:pet_pal/widgets/empty_state.dart';
import 'package:pet_pal/widgets/pet_card.dart';
import 'package:pet_pal/widgets/today_dashboard_section.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'Claro';
      case ThemeMode.dark:
        return 'Oscuro';
      case ThemeMode.system:
        return 'Sistema';
    }
  }

  void _showThemeModeDialog(BuildContext context) {
    final current = ref.read(themeModeProvider);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Apariencia'),
        content: RadioGroup<ThemeMode>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) {
              ref.read(themeModeProvider.notifier).setThemeMode(value);
            }
            Navigator.of(dialogContext).pop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: ThemeMode.values.map((mode) {
              return RadioListTile<ThemeMode>(
                title: Text(_themeModeLabel(mode)),
                value: mode,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _drawerSection(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }

  Widget _drawerLink(IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      onTap: () {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (context) => page));
      },
    );
  }

  Future<void> _openPet(Pet pet) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => PetDetailScreen(pet: pet)),
    );
    ref.read(petsProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final petsAsync = ref.watch(petsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Mascotas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            ),
            tooltip: 'Buscar',
          ),
          IconButton(
            icon: const Icon(Icons.contact_phone),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const EmergencyContactsScreen()),
            ),
            tooltip: 'Contactos de Emergencia',
          ),
        ],
      ),
      drawer: Drawer(
        child: Column(
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
              ),
              child: const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.pets, size: 50),
                    SizedBox(height: 10),
                    Text(
                      'PetPal Manager',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
            _drawerSection('Ajustes'),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Apariencia'),
              subtitle: Text(_themeModeLabel(ref.watch(themeModeProvider))),
              onTap: () => _showThemeModeDialog(context),
            ),
            _drawerLink(
              Icons.notifications,
              'Notificaciones',
              const BackupSettingsScreen(section: BackupSettingsSection.notifications),
            ),
            _drawerLink(
              Icons.settings_backup_restore,
              'Respaldo y restauración',
              const BackupSettingsScreen(section: BackupSettingsSection.backup),
            ),
            const Divider(),
            _drawerSection('Catálogos'),
            _drawerLink(Icons.bug_report, 'Desparasitantes', const DewormingProductsScreen()),
            _drawerLink(Icons.location_on, 'Ubicaciones', const LocationEntriesScreen()),
            _drawerLink(Icons.vaccines, 'Vacunas', const VaccinationProductsScreen()),
            const Divider(),
            _drawerSection('Ayuda'),
            _drawerLink(Icons.menu_book, 'Guía de PetPal', const GuideScreen()),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Versión 1.0.0 (v26)',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
      body: petsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Error al cargar mascotas: $error')),
        data: (pets) {
          if (pets.isEmpty) {
            return const EmptyState(
              icon: Icons.pets,
              message: 'Aún no tienes mascotas',
              actionHint: 'Presiona "+" para añadir la primera.',
            );
          }

          final single = pets.length == 1;
          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(child: TodayDashboardSection()),
              SliverPadding(
                padding: kFabListPadding.copyWith(left: 16, right: 16, top: 8),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: single ? 1 : 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: single ? 1.5 : 0.85,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final pet = pets[index];
                      return PetCard(pet: pet, onTap: () => _openPet(pet));
                    },
                    childCount: pets.length,
                  ),
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Añadir mascota',
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const AddEditPetScreen(),
            ),
          );
          ref.read(petsProvider.notifier).refresh();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
