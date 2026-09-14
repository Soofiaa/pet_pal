import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/location_entry.dart';

/// Capa de acceso a datos, pura, para el catálogo de ubicaciones (mismo
/// patrón que VaccinationProductRepository): a diferencia de
/// AppointmentRepository, acá no hay nada que orquestar (ni recordatorios ni
/// archivos), así que se puede llamar directo desde cualquier pantalla.
class LocationEntryRepository {
  LocationEntryRepository(this._dbHelper);

  final DatabaseHelper _dbHelper;

  Future<List<LocationEntry>> getEntries() {
    return _dbHelper.getLocationEntries();
  }

  Future<void> insertEntry(LocationEntry entry) {
    return _dbHelper.insertLocationEntry(entry);
  }

  Future<void> updateEntry(LocationEntry entry) {
    return _dbHelper.updateLocationEntry(entry);
  }

  Future<void> deleteEntry(String id) {
    return _dbHelper.deleteLocationEntry(id);
  }
}
