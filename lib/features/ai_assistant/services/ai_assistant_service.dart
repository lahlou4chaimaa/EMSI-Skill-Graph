
import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

class AiAssistantPhoto {
  final String url;
  final String caption;
  final int score;

  const AiAssistantPhoto({
    required this.url,
    required this.caption,
    required this.score,
  });

  factory AiAssistantPhoto.fromJson(Map<String, dynamic> json) {
    return AiAssistantPhoto(
      url: json['url']?.toString() ?? '',
      caption: json['caption']?.toString() ?? '',
      score: (json['score'] as num?)?.toInt() ?? 0,
    );
  }
}

class AiAssistantResponse {
  final String question;
  final String answer;
  final String? conversationId;
  final List<AiAssistantSource> sources;
  final List<AiAssistantPhoto> photos;

  const AiAssistantResponse({
    required this.question,
    required this.answer,
    required this.sources,
    required this.photos,
    this.conversationId,
  });

  factory AiAssistantResponse.fromJson(
    Map<String, dynamic> json, {
    required String baseUrl,
  }) {
    final rawSources = json['sources'] as List? ?? [];
    final rawPhotos = json['photos'] as List? ?? [];

    final photos = rawPhotos
        .whereType<Map>()
        .map((photo) {
          final parsed = AiAssistantPhoto.fromJson(
            Map<String, dynamic>.from(photo),
          );

          final absoluteUrl = Uri.parse(baseUrl)
              .resolve(parsed.url)
              .toString();

          return AiAssistantPhoto(
            url: absoluteUrl,
            caption: parsed.caption,
            score: parsed.score,
          );
        })
        .toList();

    return AiAssistantResponse(
      question: json['question']?.toString() ?? '',
      answer: json['answer']?.toString() ??
          json['visual_description']?.toString() ??
          'Aucune réponse reçue.',
      conversationId: json['conversation_id']?.toString(),
      sources: rawSources
          .whereType<Map>()
          .map(
            (source) => AiAssistantSource.fromJson(
              Map<String, dynamic>.from(source),
            ),
          )
          .toList(),
      photos: photos,
    );
  }
}

class AiAssistantService {
  // Android Emulator : 10.0.2.2 permet d'accéder au PC hôte.
  // Téléphone physique : remplacer par l'adresse IPv4 du PC.
  // Flutter Web sur le même PC : utiliser 127.0.0.1.
  static const String baseUrl = 'http://127.0.0.1:8000';

  final http.Client _client;

  String? _conversationId;

  AiAssistantService({http.Client? client})
      : _client = client ?? http.Client();

  String? get conversationId => _conversationId;

  // --------------------------------------------------
  // AUTHENTIFICATION SUPABASE
  // --------------------------------------------------

  String? _getAccessToken() {
    try {
      return Supabase.instance.client.auth.currentSession?.accessToken;
    } catch (_) {
      return null;
    }
  }

  Map<String, String> _buildHeaders({
    bool jsonContent = false,
  }) {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (jsonContent) {
      headers['Content-Type'] = 'application/json';
    }

    final token = _getAccessToken();

    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    return headers;
  }

  // --------------------------------------------------
  // NOUVELLE CONVERSATION
  // --------------------------------------------------

  void startNewConversation() {
    _conversationId = null;
  }

  // Permet de reprendre une conversation existante
  // lorsque son identifiant est connu.
  void resumeConversation(String conversationId) {
    _conversationId = conversationId;
  }

  // --------------------------------------------------
  // QUESTION TEXTUELLE
  // POST /chat/ask
  // --------------------------------------------------

  Future<AiAssistantResponse> askQuestion(
    String question, {
    String? conversationId,
  }) async {
    final uri = Uri.parse('$baseUrl/chat/ask');

    if (conversationId != null && conversationId.isNotEmpty) {
      _conversationId = conversationId;
    }

    final body = <String, dynamic>{
      'question': question.trim(),
      'match_count': 5,
    };

    if (_conversationId != null) {
      body['conversation_id'] = _conversationId;
    }

    try {
      final response = await _client
          .post(
            uri,
            headers: _buildHeaders(jsonContent: true),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 180));

      final result = _parseResponse(response);

      if (result.conversationId != null) {
        _conversationId = result.conversationId;
      }

      return result;
    } on http.ClientException {
      throw Exception(
        'Impossible de contacter le serveur. Vérifie que le backend '
        'FastAPI est démarré et que son adresse est correcte.',
      );
    } on FormatException {
      throw Exception(
        'Le serveur a renvoyé une réponse invalide.',
      );
    } on TimeoutException {
      throw Exception(
        'Le serveur met trop de temps à répondre. Réessaie.',
      );
    }
  }

  // --------------------------------------------------
  // ANALYSE D'IMAGE
  // POST /visual-search/analyze
  // multipart/form-data : file + question
  // --------------------------------------------------

  Future<AiAssistantResponse> analyzeImage({
    required XFile image,
    String question = '',
  }) async {
    final uri = Uri.parse('$baseUrl/visual-search/analyze');

    try {
      final request = http.MultipartRequest('POST', uri);

      request.headers.addAll(_buildHeaders());

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
        'Impossible d’envoyer la photo. Vérifie que le backend '
        'FastAPI est démarré et que son adresse IP est correcte.',
      );
    } on FormatException {
      throw Exception(
        'Le serveur a renvoyé une réponse invalide.',
      );
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

    return AiAssistantResponse.fromJson(
      data,
      baseUrl: baseUrl,
    );
  }

  void dispose() {
    _client.close();
  }
}
