import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pet_pal/models/document.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/providers/document_providers.dart';
import 'package:pet_pal/screens/add_edit_document_screen/add_edit_document_screen.dart';
import 'package:pet_pal/screens/image_preview_screen/image_preview_screen.dart';
import 'package:pet_pal/services/image_storage_service.dart';
import 'package:pet_pal/widgets/empty_state.dart';

class DocumentsScreen extends ConsumerStatefulWidget {
  final Pet pet;

  const DocumentsScreen({super.key, required this.pet});

  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  static const String _allCategoriesLabel = 'Todas';

  String _selectedCategory = _allCategoriesLabel;
  String _searchQuery = '';
  bool _isSearching = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Document> _filterDocuments(List<Document> documents) {
    return documents.where((document) {
      final matchesCategory = _selectedCategory == _allCategoriesLabel ||
          document.categoria == _selectedCategory;
      final matchesSearch = document.titulo
              .toLowerCase()
              .contains(_searchQuery.toLowerCase()) ||
          (document.notas ?? '')
              .toLowerCase()
              .contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesSearch;
    }).toList();
  }

  Future<void> _openDocument(Document document) async {
    if (!ImageStorageService.isValidLocalFile(document.filePath)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El archivo ya no está disponible.')),
      );
      return;
    }

    if (document.isImage) {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImagePreviewScreen(
            imagePath: document.filePath,
            title: document.titulo,
          ),
        ),
      );
      return;
    }

    final OpenResult result = await OpenFilex.open(document.filePath);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir el archivo: ${result.message}')),
      );
    }
  }

  Future<void> _confirmDelete(Document document) async {
    final bool? shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Documento'),
        content: Text('¿Estás seguro de que quieres eliminar "${document.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await ref.read(documentsProvider(widget.pet.id).notifier).deleteDocument(document);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Documento eliminado correctamente.')),
        );
      } catch (e) {
        debugPrint('Error al eliminar el documento: $e');
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al eliminar el documento: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> categories = [_allCategoriesLabel, ...kDocumentCategories];
    final documentsAsync = ref.watch(documentsProvider(widget.pet.id));

    return Scaffold(
      appBar: AppBar(
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Buscar documentos...',
                  border: InputBorder.none,
                  hintStyle: TextStyle(color: Colors.white70),
                ),
                style: const TextStyle(color: Colors.white),
                onChanged: (value) => setState(() => _searchQuery = value),
              )
            : Text('Documentos de ${widget.pet.name}'),
        actions: [
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                if (_isSearching) {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                } else {
                  _isSearching = true;
                }
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final String category = categories[index];
                final bool selected = category == _selectedCategory;
                return ChoiceChip(
                  label: Text(category),
                  selected: selected,
                  onSelected: (_) => setState(() => _selectedCategory = category),
                );
              },
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: documentsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(child: Text('Error: $error')),
              data: (documents) {
                final filteredDocuments = _filterDocuments(documents);

                if (filteredDocuments.isEmpty) {
                  return EmptyState(
                    icon: Icons.folder_open_outlined,
                    message: _searchQuery.isNotEmpty
                        ? 'No se encontraron resultados.'
                        : 'Aún no hay documentos registrados para ${widget.pet.name}.',
                    actionHint: _searchQuery.isNotEmpty
                        ? 'Prueba con otra palabra clave.'
                        : 'Presiona "+" para añadir uno nuevo.',
                  );
                }

                return ListView.builder(
                  itemCount: filteredDocuments.length,
                  itemBuilder: (context, index) {
                    final Document document = filteredDocuments[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: ListTile(
                        leading: Icon(
                          document.isPdf ? Icons.picture_as_pdf : Icons.image,
                          color: document.isPdf ? Colors.red : Colors.blue,
                          size: 36,
                        ),
                        title: Text(
                          document.titulo,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          '${document.categoria} · ${DateFormat('dd/MM/yyyy').format(document.fecha)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => AddEditDocumentScreen(
                                      pet: widget.pet,
                                      document: document,
                                    ),
                                  ),
                                );
                                // No hace falta refrescar acá: si se guardó
                                // algo, DocumentsNotifier.addDocument/
                                // updateDocument ya refrescó el estado
                                // internamente antes de volver; si se
                                // canceló, no hay nada que refrescar.
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => _confirmDelete(document),
                            ),
                          ],
                        ),
                        onTap: () => _openDocument(document),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddEditDocumentScreen(pet: widget.pet),
            ),
          );
          // Mismo motivo que arriba: addDocument ya refresca internamente.
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
