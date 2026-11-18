
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../services/ai_assistant_service.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<AiAssistantSource> sources;
  final bool isError;
  final Uint8List? imageBytes;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const [],
    this.isError = false,
    this.imageBytes,
  });
}

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final AiAssistantService _assistantService = AiAssistantService();
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      text:
          'Bonjour ! Je suis EMSI Assistant. Pose-moi tes questions sur les formations, les études, les campus et la vie à EMSI. Tu peux également m’envoyer une photo pour obtenir des informations à son sujet.',
      isUser: false,
    ),
  ];

  XFile? _selectedImage;
  Uint8List? _selectedImageBytes;

  bool _isLoading = false;

  static const Color primaryBlue = Color(0xFF356AE6);
  static const Color darkBlue = Color(0xFF172B4D);
  static const Color backgroundColor = Color(0xFFF5F7FC);

  // --------------------------------------------------
  // SELECTION D'IMAGE
  // --------------------------------------------------

  Future<void> _showImageSourcePicker() async {
    if (_isLoading) return;

    FocusScope.of(context).unfocus();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(22),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Ajouter une photo',
                  style: TextStyle(
                    color: darkBlue,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 18),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                    color: primaryBlue,
                  ),
                  title: const Text('Choisir depuis la galerie'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                    color: primaryBlue,
                  ),
                  title: const Text('Prendre une photo'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1800,
        maxHeight: 1800,
      );

      if (pickedFile == null || !mounted) return;

      final Uint8List imageBytes = await pickedFile.readAsBytes();

      if (!mounted) return;

      setState(() {
        _selectedImage = pickedFile;
        _selectedImageBytes = imageBytes;
      });

      _scrollToBottom();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Impossible de sélectionner cette photo : $error',
          ),
        ),
      );
    }
  }

  void _removeSelectedImage() {
    setState(() {
      _selectedImage = null;
      _selectedImageBytes = null;
    });
  }

  // --------------------------------------------------
  // ENVOI D'UN MESSAGE TEXTE OU D'UNE IMAGE
  // --------------------------------------------------

  Future<void> _sendMessage() async {
    final question = _messageController.text.trim();
    final XFile? image = _selectedImage;
    final Uint8List? imageBytes = _selectedImageBytes;

    if (_isLoading) return;

    if (question.isEmpty && image == null) return;

    _messageController.clear();

    setState(() {
      _messages.add(
        _ChatMessage(
          text: question.isEmpty ? 'Analyse cette photo.' : question,
          isUser: true,
          imageBytes: imageBytes,
        ),
      );

      _selectedImage = null;
      _selectedImageBytes = null;
      _isLoading = true;
    });

    _scrollToBottom();

    try {
      final AiAssistantResponse response;

      if (image != null) {
        response = await _assistantService.analyzeImage(
          image: image,
          question: question,
        );
      } else {
        response = await _assistantService.askQuestion(question);
      }

      if (!mounted) return;

      setState(() {
        _messages.add(
          _ChatMessage(
            text: response.answer,
            isUser: false,
            sources: response.sources,
          ),
        );

        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _messages.add(
          _ChatMessage(
            text: error.toString().replaceFirst('Exception: ', ''),
            isUser: false,
            isError: true,
          ),
        );

        _isLoading = false;
      });
    }

    _scrollToBottom();
  }

  // --------------------------------------------------
  // CONVERSATION
  // --------------------------------------------------

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  void _clearConversation() {
    if (_isLoading) return;

    setState(() {
      _messages.clear();

      _selectedImage = null;
      _selectedImageBytes = null;
      _messageController.clear();

      _messages.add(
        const _ChatMessage(
          text:
              'Nouvelle conversation. Quelle est ta question sur EMSI ? Tu peux aussi m’envoyer une photo.',
          isUser: false,
        ),
      );
    });

    _scrollToBottom();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _assistantService.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // INTERFACE PRINCIPALE
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.white,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: darkBlue,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: primaryBlue,
                size: 25,
              ),
            ),
            const SizedBox(width: 11),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'EMSI Assistant',
                  style: TextStyle(
                    color: darkBlue,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      Icons.circle,
                      color: Colors.green,
                      size: 7,
                    ),
                    SizedBox(width: 5),
                    Text(
                      'En ligne • Assistant intelligent',
                      style: TextStyle(
                        color: Colors.green,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle conversation',
            onPressed: _clearConversation,
            icon: const Icon(
              Icons.add_comment_outlined,
              color: darkBlue,
            ),
          ),
          const SizedBox(width: 5),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const _TypingIndicator();
                }

                return _MessageBubble(
                  message: _messages[index],
                );
              },
            ),
          ),
          _buildInputArea(),
        ],
      ),
    );
  }

  // --------------------------------------------------
  // ZONE DE SAISIE
  // --------------------------------------------------

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: Color(0xFFE8ECF3),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_selectedImageBytes != null) ...[
              _buildSelectedImagePreview(),
              const SizedBox(height: 10),
            ],
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                IconButton(
                  tooltip: 'Joindre une photo',
                  onPressed: _isLoading ? null : _showImageSourcePicker,
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    color: primaryBlue,
                    size: 25,
                  ),
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: backgroundColor,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: const Color(0xFFE3E8F0),
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: !_isLoading,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: const InputDecoration(
                        hintText: 'Pose ta question...',
                        hintStyle: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 13,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                SizedBox(
                  width: 48,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendMessage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryBlue,
                      disabledBackgroundColor:
                          primaryBlue.withValues(alpha: 0.45),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: const Icon(
                      Icons.send_rounded,
                      size: 21,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedImagePreview() {
    if (_selectedImageBytes == null) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(
              _selectedImageBytes!,
              width: 65,
              height: 65,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Image sélectionnée',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: darkBlue,
              ),
            ),
          ),
          IconButton(
            onPressed: _removeSelectedImage,
            icon: const Icon(
              Icons.close,
              color: Colors.red,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================================================
// BULLE DE MESSAGE
// ==================================================

class _MessageBubble extends StatelessWidget {
  final _ChatMessage message;

  const _MessageBubble({
    required this.message,
  });

  static const Color primaryBlue = Color(0xFF356AE6);
  static const Color darkBlue = Color(0xFF172B4D);

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: primaryBlue,
                size: 19,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isUser
                    ? const Color(0xFF172B4D)
                    : message.isError
                        ? const Color(0xFFFFF0F0)
                        : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(17),
                  topRight: const Radius.circular(17),
                  bottomLeft: Radius.circular(isUser ? 17 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 17),
                ),
                border: isUser
                    ? null
                    : Border.all(
                        color: message.isError
                            ? const Color(0xFFFFD5D5)
                            : const Color(0xFFE8ECF3),
                      ),
                boxShadow: [
                  if (!isUser)
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.025),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (message.imageBytes != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.memory(
                        message.imageBytes!,
                        width: 230,
                        height: 190,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Text(
                    message.text,
                    style: TextStyle(
                      color: isUser
                          ? Colors.white
                          : message.isError
                              ? Colors.red.shade800
                              : darkBlue,
                      fontSize: 14,
                      height: 1.55,
                    ),
                  ),
                  if (message.sources.isNotEmpty) ...[
                    const SizedBox(height: 13),
                    Divider(
                      height: 1,
                      color: isUser
                          ? Colors.white24
                          : const Color(0xFFE8ECF3),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      'Sources utilisées',
                      style: TextStyle(
                        color: isUser ? Colors.white : darkBlue,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 7),
                    ...message.sources.map(
                      (source) => Padding(
                        padding: const EdgeInsets.only(bottom: 5),
                        child: Row(
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 14,
                              color: isUser ? Colors.white70 : primaryBlue,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Document ${source.documentId} • Page ${source.pageNumber}',
                                style: TextStyle(
                                  color: isUser
                                      ? Colors.white70
                                      : Colors.black54,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.person_rounded,
                color: primaryBlue,
                size: 19,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ==================================================
// INDICATEUR DE CHARGEMENT
// ==================================================

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(left: 42, bottom: 14),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Row(
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                strokeWidth: 2,
              ),
            ),
            SizedBox(width: 10),
            Text(
              'EMSI Assistant analyse ta demande...',
              style: TextStyle(
                color: Colors.black54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
