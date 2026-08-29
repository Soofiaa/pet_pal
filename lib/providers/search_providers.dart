import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_pal/providers/database_providers.dart';
import 'package:pet_pal/services/search_service.dart';

final searchServiceProvider = Provider<SearchService>((ref) {
  return SearchService(ref.watch(databaseHelperProvider));
});
