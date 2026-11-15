
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/env.dart';
import '../models/knowledge_image.dart';

class KnowledgeImagesService {
  static String get _baseUrl {
    return Env.apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
  }

  static Future<Map<String, dynamic>> getImages({
    int limit = 20,
    int offset = 0,
    String? documentId,
  }) async {
    final queryParameters = <String, String>{
      'limit': limit.toString(),
      'offset': offset.toString(),
    };

    if (documentId != null && documentId.isNotEmpty) {
      queryParameters['document_id'] = documentId;
    }

    final uri = Uri.parse('$_baseUrl/knowledge-images/')
        .replace(queryParameters: queryParameters);

    final response = await http
        .get(uri)
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'Erreur API (${response.statusCode}): ${response.body}',
      );
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;

    final imagesJson = data['images'] as List<dynamic>;

    final images = imagesJson.map((item) {
      return KnowledgeImage.fromJson(
        item as Map<String, dynamic>,
      );
    }).toList();

    return {
      'total': (data['total'] as num).toInt(),
      'images': images,
    };
  }

  static String getImageUrl(String imageId) {
    return '$_baseUrl/knowledge-images/$imageId/file';
  }
}
