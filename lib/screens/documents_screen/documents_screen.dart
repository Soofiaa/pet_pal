import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pet_pal/data/database_helper.dart';
import 'package:pet_pal/models/document.dart';
import 'package:pet_pal/models/pet.dart';
import 'package:pet_pal/screens/add_edit_document_screen/add_edit_document_screen.dart';
import 'package:pet_pal/screens/image_preview_screen/image_preview_screen.dart';
import 'package:pet_pal/services/image_storage_service.dart';

class DocumentsScreen extends StatefulWidget {
  final Pet pet;

  const DocumentsScreen({super.key, required this.pet});

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> {
  static const String _allCategoriesLabel = 'Todas';

  List<Document> _documents = [];
  bool _isLoading = true;
  String _selectedCategory = _allCategoriesLabel;

  @override
  void initState() {
    super.initState();
    _loadDocuments();
  }

  Future<void> _loadDocuments() async {
    setState(() => _isLoading = true);
    final documents = await DatabaseHelper().getDocumentsForPet(widget.pet.id);
    if (!mounted) return;
    setState(() {
      _documents = documents;
      _isLoading = false;
    });
  }

  List<Document> get _filteredDocuments {
    if (_selectedCategory == _allCategoriesLabel) return _documents;
    return _documents
        .where((document) => document.categoria == _selectedCategory)
        .toList();
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
      await ImageStorageService.deleteFileIfExist(document.filePath);
      await DatabaseHelper().deleteDocument(document.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Documento eliminado correctamente.')),
      );
      _loadDocuments();
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<String> categories = [_allCategoriesLabel, ...kDocumentCategories];

    return Scaffold(
      appBar: AppBar(
        title: Text('Documentos de ${widget.pet.name}'),
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
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredDocuments.isEmpty
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: Text(
                            'No hay documentos registrados para esta categoría.',
                            style: TextStyle(fontSize: 18, fontStyle: FontStyle.italic),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filteredDocuments.length,
                        itemBuilder: (context, index) {
                          final Document document = _filteredDocuments[index];
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
                                      _loadDocuments();
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
          _loadDocuments();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
