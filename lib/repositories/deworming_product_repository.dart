import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/deworming_product.dart';

class DewormingProductRepository {
  final DatabaseHelper _dbHelper;

  DewormingProductRepository(this._dbHelper);

  Future<List<DewormingProduct>> getProducts() async {
    return _dbHelper.getDewormingProducts();
  }

  Future<void> insertProduct(DewormingProduct product) async {
    await _dbHelper.insertDewormingProduct(product);
  }

  Future<void> updateProduct(DewormingProduct product) async {
    await _dbHelper.updateDewormingProduct(product);
  }

  Future<void> deleteProduct(String id) async {
    await _dbHelper.deleteDewormingProduct(id);
  }
}
