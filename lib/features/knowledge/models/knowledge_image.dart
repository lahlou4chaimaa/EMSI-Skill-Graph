
class KnowledgeImage {
  final String id;
  final String documentId;
  final String filename;
  final int pageNumber;
  final int imageIndex;
  final int width;
  final int height;

  const KnowledgeImage({
    required this.id,
    required this.documentId,
    required this.filename,
    required this.pageNumber,
    required this.imageIndex,
    required this.width,
    required this.height,
  });

  factory KnowledgeImage.fromJson(Map<String, dynamic> json) {
    return KnowledgeImage(
      id: json['id'] as String,
      documentId: json['document_id'] as String,
      filename: json['filename'] as String,
      pageNumber: (json['page_number'] as num).toInt(),
      imageIndex: (json['image_index'] as num).toInt(),
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
    );
  }
}
