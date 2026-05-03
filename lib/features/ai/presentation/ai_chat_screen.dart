import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/services/ai_provider.dart';
import '../../../core/services/ai_service_interface.dart';
import '../../medicine/data/medicine_repository.dart';
import '../../medicine/models/medicine_model.dart';

class AiChatScreen extends StatefulWidget {
  final String? mode;

  const AiChatScreen({super.key, this.mode});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MedicineRepository _medicineRepository = MedicineRepository();

  List<MedicineModel> medicines = [];
  bool isLoadingMedicines = true;
  bool isAiTyping = false;
  AiService? _aiService;
  bool _isLocalAi = false;

  final List<_ChatMessage> messages = [];

  late AnimationController _typingAnimController;

  @override
  void initState() {
    super.initState();
    _typingAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
    _loadMedicinesAndInit();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _typingAnimController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicinesAndInit() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      medicines = await _medicineRepository.getMedicinesByUser(user.uid).first;
    }

    _isLocalAi = true;
    _aiService = await AiProvider.getService();

    // Инициализируем AI сервис с контекстом аптечки
    _aiService?.initWithMedicines(medicines);

    _addInitialMessage();

    if (mounted) {
      setState(() => isLoadingMedicines = false);
    }
  }

  void _addInitialMessage() {
    String text;
    switch (widget.mode) {
      case 'symptoms':
        text =
            'Привет! 👋 Опиши симптомы — например: "болит голова и температура 38". Я проверю твою аптечку и подскажу, что может помочь.';
        break;
      case 'inventory':
        text =
            'Привет! 📦 Хочу проверить твою аптечку. Скажи "проверь" — и я расскажу про сроки годности, остатки и что докупить.';
        break;
      default:
        text =
            'Привет! Я SmartKit AI 🤖 — твой умный помощник по домашней аптечке.\n\nМогу:\n• Подсказать что принять при симптомах\n• Проверить аптечку (сроки, остатки)\n• Составить список для покупок\n• Ответить на вопросы о лекарствах\n\nЧем могу помочь?';
    }
    messages.add(_ChatMessage(text: text, isUser: false));
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || isAiTyping) return;

    setState(() {
      messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
      isAiTyping = true;
    });

    _scrollToBottom();

    final response = await (_aiService?.sendMessage(text) ?? 
        Future.value("Ошибка: AI сервис не инициализирован"));

    if (mounted) {
      setState(() {
        messages.add(_ChatMessage(text: response, isUser: false));
        isAiTyping = false;
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 200,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  void _resetChat() {
    setState(() {
      messages.clear();
      isAiTyping = false;
    });
    _aiService?.resetChat(medicines);
    _addInitialMessage();
    setState(() {});
  }

  void _showAiSettings() {
    // We only have Ollama now, so we can just show a simple info dialog if needed,
    // or nothing at all. The user requested to remove Gemini completely.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('SmartKit AI'),
        content: const Text('Ваш помощник работает локально через Ollama для обеспечения максимальной приватности.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }


  Future<void> _updateAiService() async {
    _aiService = await AiProvider.getService();
    _aiService?.initWithMedicines(medicines);
  }

  List<String> get _quickPrompts {
    switch (widget.mode) {
      case 'symptoms':
        return [
          'Болит голова',
          'Высокая температура',
          'Кашель и горло',
          'Боль в животе',
        ];
      case 'inventory':
        return [
          'Проверь аптечку',
          'Что просрочено?',
          'Что докупить?',
          'Чего мало?',
        ];
      default:
        return [
          'Проверь аптечку',
          'Что принять от головной боли?',
          'Что докупить?',
          'Собери базовый набор',
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'SmartKit AI',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                ),
                  Text(
                    isAiTyping 
                        ? 'печатает...' 
                        : 'онлайн • Ollama (Локально)',
                    style: TextStyle(
                      fontSize: 11,
                      color: isAiTyping
                          ? const Color(0xFFA855F7)
                          : const Color(0xFF10B981),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Новый чат',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _resetChat,
          ),
        ],
      ),
      body: SafeArea(
        child: isLoadingMedicines
            ? _buildLoading()
            : Column(
                children: [
                  Expanded(child: _buildMessageList(isDark)),
                  if (isAiTyping) _buildTypingIndicator(isDark),
                  _buildQuickPrompts(isDark),
                  _buildInputBar(isDark),
                ],
              ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Color(0xFFA855F7)),
          SizedBox(height: 16),
          Text(
            'Загружаю аптечку...',
            style: TextStyle(color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList(bool isDark) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        return _buildMessageBubble(messages[index], isDark);
      },
    );
  }

  Widget _buildMessageBubble(_ChatMessage message, bool isDark) {
    final isUser = message.isUser;

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: message.text));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Сообщение скопировано'),
              duration: Duration(seconds: 1),
            ),
          );
        },
        child: Container(
          margin: EdgeInsets.only(
            bottom: 10,
            left: isUser ? 60 : 0,
            right: isUser ? 0 : 60,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: isUser
                ? const LinearGradient(
                    colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isUser
                ? null
                : (isDark ? const Color(0xFF1F2937) : Colors.white),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: Radius.circular(isUser ? 20 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 20),
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 8,
                offset: const Offset(0, 2),
                color: isUser
                    ? const Color(0xFF6366F1).withOpacity(0.3)
                    : Colors.black.withOpacity(0.05),
              ),
            ],
          ),
          child: Text(
            message.text,
            style: TextStyle(
              fontSize: 14.5,
              height: 1.45,
              color: isUser
                  ? Colors.white
                  : (isDark ? const Color(0xFFE5E7EB) : const Color(0xFF111827)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.fromLTRB(16, 0, 60, 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1F2937) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
            bottomRight: Radius.circular(20),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
              blurRadius: 8,
              offset: const Offset(0, 2),
              color: Colors.black.withOpacity(0.05),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            return AnimatedBuilder(
              animation: _typingAnimController,
              builder: (_, __) {
                final delay = i * 0.2;
                final value = (_typingAnimController.value - delay).clamp(0.0, 1.0);
                return Container(
                  width: 7,
                  height: 7,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color.lerp(
                      const Color(0xFF9CA3AF),
                      const Color(0xFFA855F7),
                      value,
                    ),
                  ),
                );
              },
            );
          }),
        ),
      ),
    );
  }

  Widget _buildQuickPrompts(bool isDark) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _quickPrompts.map((prompt) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: isAiTyping ? null : () => _sendMessage(prompt),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: isAiTyping
                            ? const Color(0xFFD1D5DB)
                            : const Color(0xFFA855F7),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      color: isAiTyping
                          ? Colors.transparent
                          : const Color(0xFFA855F7).withOpacity(0.08),
                    ),
                    child: Text(
                      prompt,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: isAiTyping
                            ? const Color(0xFF9CA3AF)
                            : const Color(0xFFA855F7),
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildInputBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : Colors.white,
        boxShadow: [
          BoxShadow(
            blurRadius: 20,
            offset: const Offset(0, -4),
            color: Colors.black.withOpacity(0.06),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !isAiTyping,
              maxLines: 3,
              minLines: 1,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText: isAiTyping ? 'AI печатает...' : 'Напиши вопрос...',
                hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark
                    ? const Color(0xFF111827)
                    : const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 10),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: isAiTyping
                  ? const LinearGradient(
                      colors: [Color(0xFFD1D5DB), Color(0xFFD1D5DB)],
                    )
                  : const LinearGradient(
                      colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isAiTyping
                  ? []
                  : [
                      BoxShadow(
                        color: const Color(0xFFA855F7).withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: isAiTyping ? null : () => _sendMessage(),
                borderRadius: BorderRadius.circular(16),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
  }) : timestamp = DateTime.now();
}
