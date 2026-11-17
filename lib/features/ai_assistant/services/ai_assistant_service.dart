
import 'dart:convert';

import 'package:http/http.dart' as http;

class AiAssistantSource {
  final String documentId;
  final int pageNumber;
  final int chunkIndex;
  final double similarity;

  const AiAssistantSource({
    required this.documentId,
    required this.pageNumber,
    required this.chunkIndex,
    required this.similarity,
  });

  factory AiAssistantSource.fromJson(Map<String, dynamic> json) {
    return AiAssistantSource(
      documentId: json['document_id']?.toString() ?? '',
      pageNumber: (json['page_number'] as num?)?.toInt() ?? 0,
      chunkIndex: (json['chunk_index'] as num?)?.toInt() ?? 0,
      similarity: (json['similarity'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AiAssistantResponse {
  final String question;
  final String answer;
  final List<AiAssistantSource> sources;

  const AiAssistantResponse({
    required this.question,
    required this.answer,
    required this.sources,
  });

  factory AiAssistantResponse.fromJson(Map<String, dynamic> json) {
    final rawSources = json['sources'] as List? ?? [];

    return AiAssistantResponse(
      question: json['question']?.toString() ?? '',
      answer: json['answer']?.toString() ?? '',
      sources: rawSources
          .whereType<Map>()
          .map(
            (source) => AiAssistantSource.fromJson(
              Map<String, dynamic>.from(source),
            ),
          )
          .toList(),
    );
  }
}

class AiAssistantService {
  // Android Emulator : 10.0.2.2 permet d'accéder au PC hôte.
  // Téléphone physique : remplacer par l'adresse IPv4 du PC.
 static const String baseUrl = 'http://127.0.0.1:8000';

  final http.Client _client;

  AiAssistantService({http.Client? client})
      : _client = client ?? http.Client();

  Future<AiAssistantResponse> askQuestion(
    String question,
  ) async {
    final uri = Uri.parse('$baseUrl/chat/ask');

    try {
      final response = await _client
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode({
              'question': question.trim(),
              'match_count': 5,
            }),
          )
          .timeout(const Duration(seconds: 90));

      final Map<String, dynamic> data =
          jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode != 200) {
        final detail = data['detail']?.toString() ??
            'Erreur lors du traitement de la question.';
        throw Exception(detail);
      }

      return AiAssistantResponse.fromJson(data);
    } on http.ClientException {
      throw Exception(
        'Impossible de contacter le serveur. Vérifie que le backend FastAPI est démarré et que l’adresse IP est correcte.',
      );
    } on FormatException {
      throw Exception('Le serveur a renvoyé une réponse invalide.');
    } catch (error) {
      if (error.toString().contains('TimeoutException')) {
        throw Exception(
          'Le serveur met trop de temps à répondre. Réessaie.',
        );
      }
      rethrow;
    }
  }

  void dispose() {
    _client.close();
  }
}
