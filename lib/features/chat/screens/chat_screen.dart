import 'package:flutter/material.dart';

import '../services/chat_service.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ChatService _chatService = ChatService();
  final List<Map<String, dynamic>> _messages = [];

  bool _isLoading = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();

    if (message.isEmpty || _isLoading) return;

    setState(() {
      _messages.add({'content': message, 'isUser': true});

      _messageController.clear();
      _isLoading = true;
    });

    try {
      final response = await _chatService.askQuestion(message);

      if (!mounted) return;

      setState(() {
        _messages.add({
          'content': response.answer,
          'isUser': false,
          'sources': response.sources,
        });

        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _messages.add({
          'content': 'Erreur : ${e.toString().replaceFirst('Exception: ', '')}',
          'isUser': false,
          'sources': <ChatSource>[],
        });

        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    const primaryBlue = Color(0xFF356AE6);
    const darkBlue = Color(0xFF172B4D);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F9FC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: darkBlue),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'EMSI Assistant',
              style: TextStyle(
                color: darkBlue,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              'Assistant intelligent EMSI',
              style: TextStyle(color: Colors.grey, fontSize: 11),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle conversation',
            icon: const Icon(Icons.add, color: darkBlue),
            onPressed: () {
              setState(() {
                _messages.clear();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? _buildWelcome(primaryBlue, darkBlue)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _messages.length,
                    itemBuilder: (context, index) {
                      final message = _messages[index];

                      return _buildMessage(
                        message['content'] as String,
                        message['isUser'] as bool,
                        primaryBlue,
                      );
                    },
                  ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(left: 20, bottom: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'EMSI Assistant réfléchit...',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ),
            ),
          _buildInput(primaryBlue),
        ],
      ),
    );
  }

  Widget _buildWelcome(Color primaryBlue, Color darkBlue) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: primaryBlue.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Icon(Icons.school_outlined, color: primaryBlue, size: 38),
            ),
            const SizedBox(height: 20),
            Text(
              'Bonjour !',
              style: TextStyle(
                color: darkBlue,
                fontSize: 25,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Je suis votre assistant EMSI. '
              'Posez vos questions sur les formations, '
              'les filières, les programmes et la vie étudiante.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black54,
                fontSize: 14,
                height: 1.6,
              ),
            ),
            const SizedBox(height: 24),
            _suggestion('Quelles sont les filières proposées à EMSI ?'),
            _suggestion('Quels sont les débouchés après le diplôme ?'),
            _suggestion('Comment fonctionne le système des stages ?'),
          ],
        ),
      ),
    );
  }

  Widget _suggestion(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          _messageController.text = text;
          _sendMessage();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Text(text, style: const TextStyle(fontSize: 12)),
        ),
      ),
    );
  }

  Widget _buildMessage(
    String content,
    bool isUser,
    Color primaryBlue, {
    List<ChatSource>? sources,
  }) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isUser ? primaryBlue : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              content,
              style: TextStyle(
                color: isUser ? Colors.white : const Color(0xFF172B4D),
                fontSize: 14,
                height: 1.5,
              ),
            ),
            if (!isUser && sources != null && sources.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              const Text(
                'Sources documentaires',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                  color: Color(0xFF356AE6),
                ),
              ),
              const SizedBox(height: 5),
              ...sources.map(
                (source) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(
                    'Page ${source.pageNumber}',
                    style: const TextStyle(fontSize: 11, color: Colors.black54),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInput(Color primaryBlue) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEEEE))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendMessage(),
              decoration: InputDecoration(
                hintText: 'Posez votre question...',
                filled: true,
                fillColor: const Color(0xFFF3F5F9),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _sendMessage,
            style: IconButton.styleFrom(
              backgroundColor: primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(13),
            ),
            icon: const Icon(Icons.send, size: 19),
          ),
        ],
      ),
    );
  }
}
