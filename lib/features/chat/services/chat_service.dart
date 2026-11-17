
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/env.dart';

class ChatSource {
  final String documentId;
  final int pageNumber;
  final int chunkIndex;
  final double similarity;

  const ChatSource({
    required this.documentId,
    required this.pageNumber,
    required this.chunkIndex,
    required this.similarity,
  });

  factory ChatSource.fromJson(Map<String, dynamic> json) {
    return ChatSource(
      documentId: json['document_id']?.toString() ?? '',
      pageNumber: (json['page_number'] as num?)?.toInt() ?? 0,
      chunkIndex: (json['chunk_index'] as num?)?.toInt() ?? 0,
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0,
    );
  }
}

class ChatResponse {
  final String question;
  final String answer;
  final List<ChatSource> sources;

  const ChatResponse({
    required this.question,
    required this.answer,
    required this.sources,
  });

  factory ChatResponse.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'] as List? ?? [];

    return ChatResponse(
      question: json['question']?.toString() ?? '',
      answer: json['answer']?.toString() ?? '',
      sources: rawSources
          .whereType<Map<String, dynamic>>()
          .map(ChatSource.fromJson)
          .toList(),
    );
  }
}

class ChatService {
  Future<ChatResponse> askQuestion(String question) async {
    final baseUrl = Env.apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.parse('$baseUrl/chat/ask');

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'question': question,
              'match_count': 5,
            }),
          )
          .timeout(const Duration(seconds: 180));

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {
        return ChatResponse.fromJson(data);
      }

      final detail = data['detail']?.toString() ??
          'Erreur HTTP ${response.statusCode}';

      throw Exception(detail);
    } catch (e) {
      if (e is http.ClientException) {
        throw Exception(
          'Impossible de contacter le serveur. Vérifie que FastAPI est démarré et que API_BASE_URL est correct.',
        );
      }

      if (e is FormatException) {
        throw Exception('Le serveur a retourné une réponse invalide.');
      }

      rethrow;
    }
  }
}
