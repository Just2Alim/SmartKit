import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../medicine/data/medicine_repository.dart';
import '../../medicine/models/medicine_model.dart';

class AiChatScreen extends StatefulWidget {
  final String? mode;

  const AiChatScreen({super.key, this.mode});

  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final MedicineRepository _medicineRepository = MedicineRepository();

  List<MedicineModel> medicines = [];
  bool isLoadingMedicines = true;

  final List<_ChatMessage> messages = [];

  @override
  void initState() {
    super.initState();
    _loadMedicines();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMedicines() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      medicines = await _medicineRepository.getMedicinesByUser(user.uid).first;
    }

    _addInitialMessage();

    if (mounted) {
      setState(() {
        isLoadingMedicines = false;
      });
    }
  }

  void _addInitialMessage() {
    String text =
        'Привет! Я AI-помощник SmartKit. Могу помочь с симптомами, проверить аптечку и подсказать, чего не хватает.';

    if (widget.mode == 'symptoms') {
      text =
          'Опиши симптомы, например: "болит голова", "температура", "кашель". Я попробую подсказать, что есть в аптечке.';
    } else if (widget.mode == 'inventory') {
      text =
          'Я могу проверить твою аптечку: что скоро истекает, чего мало и что стоит докупить.';
    }

    messages.add(_ChatMessage(text: text, isUser: false));
  }

  void _sendMessage([String? preset]) {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty) return;

    setState(() {
      messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
    });

    final response = _generateResponse(text);

    setState(() {
      messages.add(_ChatMessage(text: response, isUser: false));
    });

    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  void _scrollToBottom() {
    if (!_scrollController.hasClients) return;
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent + 120,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  String _generateResponse(String input) {
    final text = input.toLowerCase();

    if (widget.mode == 'inventory' ||
        text.contains('аптечк') ||
        text.contains('что есть') ||
        text.contains('проверь')) {
      return _inventorySummary();
    }

    if (text.contains('голова')) {
      return _symptomResponse(
        symptom: 'головная боль',
        keywords: ['парацетамол', 'цитрамон', 'ибупрофен'],
      );
    }

    if (text.contains('температур')) {
      return _symptomResponse(
        symptom: 'температура',
        keywords: ['парацетамол', 'ибупрофен'],
      );
    }

    if (text.contains('каш') || text.contains('горло')) {
      return 'Я пока не вижу специальных лекарств от кашля или горла по названиям в аптечке. Лучше проверь наличие сиропов, спреев или пастилок и, если симптомы сильные, обратись к врачу.';
    }

    if (text.contains('не хватает') || text.contains('докупить')) {
      return _shoppingAdvice();
    }

    return 'Я могу помочь так: проверить аптечку, подсказать по симптомам, предложить, что докупить, и собрать базовый набор лекарств.';
  }

  String _inventorySummary() {
    if (medicines.isEmpty) {
      return 'У тебя пока нет лекарств в аптечке. Сначала добавь хотя бы несколько препаратов, и я смогу дать рекомендации.';
    }

    final now = DateTime.now();

    final expiring =
        medicines.where((m) {
          if (m.expiryDate == null) return false;
          final diff = m.expiryDate!.difference(now).inDays;
          return diff >= 0 && diff <= 30;
        }).toList();

    final lowStock = medicines.where((m) => m.quantity <= 5).toList();

    final total = medicines.length;
    final expiringPart =
        expiring.isEmpty
            ? 'Нет лекарств с близким сроком.'
            : 'Скоро истекают: ${expiring.map((e) => e.name).take(3).join(', ')}.';
    final lowStockPart =
        lowStock.isEmpty
            ? 'Все остатки в норме.'
            : 'Мало осталось: ${lowStock.map((e) => e.name).take(3).join(', ')}.';

    return 'Сейчас в аптечке $total лекарств. $expiringPart $lowStockPart';
  }

  String _symptomResponse({
    required String symptom,
    required List<String> keywords,
  }) {
    final matched =
        medicines.where((m) {
          final name = m.name.toLowerCase();
          return keywords.any((k) => name.contains(k));
        }).toList();

    if (matched.isEmpty) {
      return 'По запросу "$symptom" я не нашёл очевидно подходящих лекарств в твоей аптечке. Возможно, стоит проверить наличие обезболивающих или жаропонижающих и при необходимости обратиться к врачу.';
    }

    return 'По запросу "$symptom" у тебя в аптечке есть: ${matched.map((e) => e.name).join(', ')}. Перед приёмом проверь дозировку и инструкцию.';
  }

  String _shoppingAdvice() {
    final lowStock = medicines.where((m) => m.quantity <= 5).toList();

    if (medicines.isEmpty) {
      return 'Сначала добавь лекарства в аптечку, тогда я смогу точнее подсказать, что докупить.';
    }

    if (lowStock.isEmpty) {
      return 'По текущим остаткам срочно докупать ничего не нужно. Но можно проверить базовый набор: обезболивающее, жаропонижающее, антисептик и перевязочные материалы.';
    }

    return 'Я бы рекомендовал докупить в первую очередь: ${lowStock.map((e) => e.name).join(', ')}.';
  }

  @override
  Widget build(BuildContext context) {
    final quickPrompts = [
      'Проверь мою аптечку',
      'Что принять от головной боли?',
      'Что докупить?',
      'Что есть от температуры?',
    ];

    return Scaffold(

      appBar: AppBar(title: const Text('AI чат')),
      body: SafeArea(
        child:
            isLoadingMedicines
                ? const Center(child: CircularProgressIndicator())
                : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isUser = message.isUser;

                          return Align(
                            alignment:
                                isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              constraints: const BoxConstraints(maxWidth: 300),
                              decoration: BoxDecoration(
                                color:
                                    isUser
                                        ? const Color(0xFF2563EB)
                                        : Colors.white,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  if (!isUser)
                                    BoxShadow(
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                      color: Colors.black.withOpacity(0.04),
                                    ),
                                ],
                              ),
                              child: Text(
                                message.text,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.35,
                                  color:
                                      isUser
                                          ? Colors.white
                                          : const Color(0xFF111827),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children:
                              quickPrompts.map((prompt) {
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ActionChip(
                                    label: Text(prompt),
                                    onPressed: () => _sendMessage(prompt),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              decoration: const InputDecoration(
                                hintText: 'Напиши вопрос...',
                              ),
                              onSubmitted: (_) => _sendMessage(),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 52,
                            width: 52,
                            child: ElevatedButton(
                              onPressed: _sendMessage,
                              style: ElevatedButton.styleFrom(
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Icon(Icons.send_rounded),
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
}

class _ChatMessage {
  final String text;
  final bool isUser;

  _ChatMessage({required this.text, required this.isUser});
}
