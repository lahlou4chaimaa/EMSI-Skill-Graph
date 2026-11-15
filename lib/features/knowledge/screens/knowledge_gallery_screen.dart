
import 'package:flutter/material.dart';

import '../models/knowledge_image.dart';
import '../services/knowledge_images_service.dart';

class KnowledgeGalleryScreen extends StatefulWidget {
  const KnowledgeGalleryScreen({super.key});

  @override
  State<KnowledgeGalleryScreen> createState() =>
      _KnowledgeGalleryScreenState();
}

class _KnowledgeGalleryScreenState
    extends State<KnowledgeGalleryScreen> {
  static const int _pageSize = 20;

  static const String _brochure1 =
      'da4ee140-7849-459d-9434-323880f0ea48';

  static const String _brochure2 =
      'b20df1a7-dfdd-4726-a09b-b3996e4f631b';

  final List<KnowledgeImage> _images = [];

  String _selectedDocument = 'all';

  int _total = 0;
  int _requestId = 0;

  bool _isLoading = false;
  bool _hasError = false;

  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadImages(reset: true);
  }

  Future<void> _loadImages({bool reset = false}) async {
    if (!reset && _isLoading) return;

    // Chaque nouvelle requête invalide la précédente.
    final currentRequestId = ++_requestId;

    if (reset) {
      setState(() {
        _images.clear();
        _total = 0;
        _hasError = false;
        _errorMessage = null;
      });
    }

    final requestedDocument = _selectedDocument;
    final requestedOffset = reset ? 0 : _images.length;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _errorMessage = null;
    });

    try {
      final result = await KnowledgeImagesService.getImages(
        limit: _pageSize,
        offset: requestedOffset,
        documentId: requestedDocument == 'all'
            ? null
            : requestedDocument,
      );

      if (!mounted || currentRequestId != _requestId) return;

      final newImages = result['images'] as List<KnowledgeImage>;
      final total = result['total'] as int;

      setState(() {
        _images.addAll(newImages);
        _total = total;
        _hasError = false;
      });
    } catch (error) {
      if (!mounted || currentRequestId != _requestId) return;

      setState(() {
        _hasError = true;
        _errorMessage = error.toString();
      });
    } finally {
      if (mounted && currentRequestId == _requestId) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onDocumentChanged(String? value) {
    if (value == null || value == _selectedDocument) return;

    setState(() {
      _selectedDocument = value;
    });

    _loadImages(reset: true);
  }

  void _showImageDetails(KnowledgeImage image) {
    final imageUrl =
        KnowledgeImagesService.getImageUrl(image.id);

    showDialog(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Détails de l’image',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight:
                        MediaQuery.of(context).size.height * 0.55,
                  ),
                  child: Image.network(
                    imageUrl,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;

                      return const Center(
                        child: CircularProgressIndicator(),
                      );
                    },
                    errorBuilder: (context, error, stackTrace) {
                      return const Text(
                        'Impossible de charger cette image.',
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  image.filename,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text('Page ${image.pageNumber}'),
                Text('${image.width} × ${image.height} pixels'),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildImageCard(KnowledgeImage image) {
    final imageUrl =
        KnowledgeImagesService.getImageUrl(image.id);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      color: Colors.white,
      child: InkWell(
        onTap: () => _showImageDetails(image),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: SizedBox(
                width: double.infinity,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;

                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Icon(
                        Icons.broken_image_outlined,
                        size: 35,
                        color: Colors.grey,
                      ),
                    );
                  },
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Page ${image.pageNumber}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    image.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Column(
      children: [
        const Icon(
          Icons.cloud_off_outlined,
          size: 45,
          color: Colors.redAccent,
        ),
        const SizedBox(height: 8),
        Text(
          _errorMessage ?? 'Erreur de connexion.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        ElevatedButton(
          onPressed: () {
            _loadImages(reset: _images.isEmpty);
          },
          child: const Text('Réessayer'),
        ),
      ],
    );
  }

  Widget _buildGalleryGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900
            ? 4
            : constraints.maxWidth > 600
                ? 3
                : 2;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _images.length,
          gridDelegate:
              SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.82,
          ),
          itemBuilder: (context, index) {
            return _buildImageCard(_images[index]);
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Knowledge Gallery',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadImages(reset: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Images des brochures EMSI',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Consulte les images extraites des documents.',
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),

            DropdownButtonFormField<String>(
              initialValue: _selectedDocument,
              decoration: const InputDecoration(
                labelText: 'Filtrer par brochure',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('Toutes les brochures'),
                ),
                DropdownMenuItem(
                  value: _brochure1,
                  child: Text('Brochure_EMSI.pdf'),
                ),
                DropdownMenuItem(
                  value: _brochure2,
                  child: Text('Brochure-EMSI.pdf'),
                ),
              ],
              onChanged: _onDocumentChanged,
            ),

            const SizedBox(height: 16),

            Text(
              '${_images.length} / $_total images',
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 12),

            if (_hasError && _images.isEmpty)
              _buildErrorView()
            else if (_images.isEmpty && _isLoading)
              const Padding(
                padding: EdgeInsets.all(40),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_images.isEmpty)
              const Padding(
                padding: EdgeInsets.all(30),
                child: Center(
                  child: Text('Aucune image disponible.'),
                ),
              )
            else
              _buildGalleryGrid(),

            if (_hasError && _images.isNotEmpty)
              _buildErrorView(),

            if (_isLoading && _images.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Center(
                  child: CircularProgressIndicator(),
                ),
              ),

            if (!_isLoading && _images.length < _total)
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: OutlinedButton.icon(
                  onPressed: () => _loadImages(),
                  icon: const Icon(Icons.add),
                  label: const Text('Charger plus d’images'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
