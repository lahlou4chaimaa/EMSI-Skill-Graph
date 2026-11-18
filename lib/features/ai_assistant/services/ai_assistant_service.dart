
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

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
      answer: json['answer']?.toString() ??
          json['visual_description']?.toString() ??
          'Aucune réponse reçue.',
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
  // Flutter Web sur le même PC : utiliser http://127.0.0.1:8000.
  static const String baseUrl = 'http://127.0.0.1:8000';

  final http.Client _client;

  AiAssistantService({http.Client? client})
      : _client = client ?? http.Client();

  // --------------------------------------------------
  // QUESTION TEXTUELLE
  // POST /chat/ask
  // --------------------------------------------------

  Future<AiAssistantResponse> askQuestion(String question) async {
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

      return _parseResponse(response);
    } on http.ClientException {
      throw Exception(
        'Impossible de contacter le serveur. Vérifie que le backend FastAPI est démarré et que son adresse est correcte.',
      );
    } on FormatException {
      throw Exception('Le serveur a renvoyé une réponse invalide.');
    } on TimeoutException {
      throw Exception('Le serveur met trop de temps à répondre. Réessaie.');
    }
  }

  // --------------------------------------------------
  // ANALYSE D'IMAGE
  // POST /visual-search/analyze
  // multipart/form-data : file + question
  // Compatible Flutter Web et Android
  // --------------------------------------------------

  Future<AiAssistantResponse> analyzeImage({
    required XFile image,
    String question = '',
  }) async {
    final uri = Uri.parse('$baseUrl/visual-search/analyze');

    try {
      final request = http.MultipartRequest('POST', uri);

      request.headers['Accept'] = 'application/json';

      request.fields['question'] = question.trim().isEmpty
          ? 'Décris cette image et donne les informations utiles.'
          : question.trim();

      final imageBytes = await image.readAsBytes();

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: image.name,
        ),
      );

      final streamedResponse = await _client
          .send(request)
          .timeout(const Duration(seconds: 180));

      final response = await http.Response.fromStream(
        streamedResponse,
      );

      return _parseResponse(response);
    } on http.ClientException {
      throw Exception(
        'Impossible d’envoyer la photo. Vérifie que le backend FastAPI est démarré et que son adresse IP est correcte.',
      );
    } on FormatException {
      throw Exception('Le serveur a renvoyé une réponse invalide.');
    } on TimeoutException {
      throw Exception(
        'L’analyse de la photo prend trop de temps. Réessaie.',
      );
    }
  }

  // --------------------------------------------------
  // TRAITEMENT COMMUN DES REPONSES
  // --------------------------------------------------

  AiAssistantResponse _parseResponse(http.Response response) {
    Map<String, dynamic> data;

    try {
      data = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw Exception(
        'Le serveur a renvoyé une réponse JSON invalide.',
      );
    }

    if (response.statusCode != 200) {
      final detail = data['detail']?.toString() ??
          'Erreur lors du traitement de la demande.';

      throw Exception(detail);
    }

    return AiAssistantResponse.fromJson(data);
  }

  void dispose() {
    _client.close();
  }
}
