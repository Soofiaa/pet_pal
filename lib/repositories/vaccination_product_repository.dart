import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/vaccination_product.dart';

class VaccinationProductRepository {
  final DatabaseHelper _dbHelper;

  VaccinationProductRepository(this._dbHelper);

  Future<List<VaccinationProduct>> getProducts() async {
    return _dbHelper.getVaccinationProducts();
  }

  Future<void> insertProduct(VaccinationProduct product) async {
    await _dbHelper.insertVaccinationProduct(product);
  }

  Future<void> updateProduct(VaccinationProduct product) async {
    await _dbHelper.updateVaccinationProduct(product);
  }

  Future<void> deleteProduct(String id) async {
    await _dbHelper.deleteVaccinationProduct(id);
  }
}
