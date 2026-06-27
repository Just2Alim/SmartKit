import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/router/app_routes.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/ai_provider.dart';
import '../../../core/services/ai_service_interface.dart';
import '../../../core/state/cart_provider.dart';
import '../../b2b/inventory/data/b2b_inventory_repository.dart';
import '../../b2b/inventory/models/b2b_inventory_model.dart';
import '../../medicine/data/medicine_repository.dart';
import '../../medicine/models/medicine_model.dart';
import '../../shop/utils/shop_product_mapper.dart';
import '../domain/ai_kit_planner.dart';
import '../models/ai_chat_result.dart';

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
  final B2BInventoryRepository _inventoryRepository = B2BInventoryRepository();

  List<MedicineModel> medicines = [];
  bool isLoadingMedicines = true;
  bool isAiTyping = false;
  AiService? _aiService;
  String? _threadId;

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
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      medicines = await _medicineRepository.getMedicinesByUser(user.id).first;
    }

    _aiService = await AiProvider.getService();

    // Инициализируем AI сервис с контекстом аптечки
    _aiService?.initWithMedicines(medicines);

    final restored = await _restoreLatestChat();
    if (!restored) {
      _addInitialMessage();
    }

    if (mounted) {
      setState(() => isLoadingMedicines = false);
    }
  }

  Future<bool> _restoreLatestChat() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return false;

    try {
      final client = Supabase.instance.client;
      final threadRows = await client
          .from('chat_threads')
          .select('id')
          .eq('user_id', user.id)
          .eq('scope', 'consumer')
          .order('last_message_at', ascending: false)
          .order('created_at', ascending: false)
          .limit(1);

      if (threadRows.isEmpty) return false;
      _threadId = threadRows.first['id']?.toString();
      if (_threadId == null || _threadId!.isEmpty) return false;

      final rows = await client
          .from('chat_messages')
          .select('role, content, metadata, created_at')
          .eq('thread_id', _threadId!)
          .order('created_at', ascending: true)
          .limit(80);

      if (rows.isEmpty) return false;
      messages.clear();
      for (final row in rows) {
        final role = row['role']?.toString() ?? 'assistant';
        final metadata = Map<String, dynamic>.from(
          (row['metadata'] as Map?) ?? const <String, dynamic>{},
        );
        final suggestions =
            (metadata['productSuggestions'] as List? ?? const [])
                .whereType<Map>()
                .map(
                  (item) => AiProductSuggestion.fromMap(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList();
        final sources =
            (metadata['sources'] as List? ?? const [])
                .whereType<Map>()
                .map(
                  (item) => AiSourceReference.fromMap(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList();
        messages.add(
          _ChatMessage(
            text: row['content']?.toString() ?? '',
            isUser: role == 'user',
            productSuggestions: suggestions,
            sources: sources,
            timestamp: DateTime.tryParse(row['created_at']?.toString() ?? ''),
          ),
        );
      }
      return messages.isNotEmpty;
    } catch (error) {
      debugPrint('SmartKit AI chat restore failed: $error');
      return false;
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
            'Привет! Я SmartKit AI 🤖 — помощник по аптечке, аптечному каталогу и безопасным справочным рекомендациям.\n\nМогу:\n• Проверить аптечку и сроки\n• Объяснить общие варианты безрецептурных средств\n• Подобрать товары из каталога и показать карточки для корзины\n• Сохранить контекст чата между входами\n\nЧем могу помочь?';
    }
    messages.add(_ChatMessage(text: text, isUser: false));
  }

  Future<void> _sendMessage([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || isAiTyping) return;
    AnalyticsService.instance.trackFeature(
      'ai_chat',
      action: 'message_sent',
      properties: {
        'mode': widget.mode ?? 'default',
        'preset': preset != null,
        'kit_intent': AiKitPlanner.hasKitIntent(text),
      },
    );

    setState(() {
      messages.add(_ChatMessage(text: text, isUser: true));
      _controller.clear();
      isAiTyping = true;
    });

    _scrollToBottom();

    String response;
    AiKitPlan? kitPlan;
    List<AiProductSuggestion> productSuggestions = const [];
    List<AiSourceReference> sources = const [];

    if (AiKitPlanner.hasKitIntent(text)) {
      final catalog = await _loadCatalogForKit();
      final preferences = AiKitPlanner.preferencesFromText(text);
      kitPlan = AiKitPlanner.buildPlan(
        preferences: preferences,
        catalog: catalog,
        homeMedicines: medicines,
      );
      response = AiKitPlanner.chatSummary(kitPlan, userText: text);
      await _persistLocalExchange(text, response);
    } else {
      final result =
          await (_aiService?.sendRichMessage(text, threadId: _threadId) ??
              Future.value(
                const AiChatResult(
                  message: 'Ошибка: AI сервис не инициализирован',
                ),
              ));
      _threadId = result.threadId ?? _threadId;
      response = result.message;
      productSuggestions = result.productSuggestions;
      sources = result.sources;
    }

    if (mounted) {
      setState(() {
        messages.add(
          _ChatMessage(
            text: response,
            isUser: false,
            kitPlan: kitPlan,
            productSuggestions: productSuggestions,
            sources: sources,
          ),
        );
        isAiTyping = false;
      });
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    }
  }

  Future<void> _persistLocalExchange(String userText, String aiText) async {
    try {
      final threadId = await _ensureThread(userText);
      if (threadId == null) return;
      final now = DateTime.now().toIso8601String();
      await Supabase.instance.client.from('chat_messages').insert([
        {
          'thread_id': threadId,
          'role': 'user',
          'content': userText,
          'metadata': {'scope': 'consumer', 'localPlanner': true},
        },
        {
          'thread_id': threadId,
          'role': 'assistant',
          'content': aiText,
          'metadata': {'scope': 'consumer', 'localPlanner': true},
        },
      ]);
      await Supabase.instance.client
          .from('chat_threads')
          .update({'last_message_at': now, 'updated_at': now})
          .eq('id', threadId);
    } catch (error) {
      debugPrint('SmartKit local AI chat persist failed: $error');
    }
  }

  Future<String?> _ensureThread(String titleSource) async {
    if (_threadId != null && _threadId!.trim().isNotEmpty) return _threadId;
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final title =
        titleSource.length > 60
            ? '${titleSource.substring(0, 60)}...'
            : titleSource;
    final row =
        await Supabase.instance.client
            .from('chat_threads')
            .insert({
              'user_id': user.id,
              'scope': 'consumer',
              'title': title,
              'last_message_at': DateTime.now().toIso8601String(),
            })
            .select('id')
            .single();
    _threadId = row['id']?.toString();
    return _threadId;
  }

  Future<List<B2BInventoryModel>> _loadCatalogForKit() async {
    try {
      return await _inventoryRepository.getPublicCatalogItems().first.timeout(
        const Duration(seconds: 8),
      );
    } catch (_) {
      return const [];
    }
  }

  int _quantityInCart(String productId) {
    return CartProvider.instance.items
        .where((item) => item['id'] == productId)
        .fold<int>(
          0,
          (sum, item) => sum + ((item['quantity'] as num?)?.toInt() ?? 1),
        );
  }

  Future<void> _confirmKitCart(AiKitPlan plan) async {
    final purchasable = plan.purchasableItems;
    if (purchasable.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Нет доступных товаров для автоматической корзины'),
        ),
      );
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Создать корзину?'),
            content: Text(
              'Добавить ${purchasable.length} позиций на сумму '
              '${ShopProductMapper.formatPrice(plan.estimatedTotal)}. '
              'Перед применением проверьте инструкцию и противопоказания.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Добавить'),
              ),
            ],
          ),
    );

    if (confirm != true || !mounted) return;

    final cartItems = <Map<String, dynamic>>[];
    for (final item in purchasable) {
      final product = item.product!;
      final inCart = _quantityInCart(product.id);
      if (inCart + item.quantity > product.stock) continue;

      final map = ShopProductMapper.toProductMap(product);
      map['quantity'] = item.quantity;
      map['source'] = 'ai_chat_kit';
      cartItems.add(map);
    }

    if (cartItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Все выбранные товары уже в корзине')),
      );
      return;
    }

    CartProvider.instance.addItems(cartItems);

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Корзина собрана')));
    Navigator.pushNamed(context, AppRoutes.cart);
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
      _threadId = null;
    });
    _aiService?.resetChat(medicines);
    _addInitialMessage();
    setState(() {});
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
          'Собери базовый набор в корзину',
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
                  isAiTyping ? 'печатает...' : 'готов • локальный режим',
                  style: TextStyle(
                    fontSize: 11,
                    color:
                        isAiTyping
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
        child:
            isLoadingMedicines
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
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width - 72,
          ),
          margin: EdgeInsets.only(
            bottom: 10,
            left: isUser ? 60 : 0,
            right: isUser ? 0 : 60,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient:
                isUser
                    ? const LinearGradient(
                      colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                    : null,
            color:
                isUser
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
                color:
                    isUser
                        ? const Color(0xFF6366F1).withValues(alpha: 0.3)
                        : Colors.black.withValues(alpha: 0.05),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.text,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  color:
                      isUser
                          ? Colors.white
                          : (isDark
                              ? const Color(0xFFE5E7EB)
                              : const Color(0xFF111827)),
                ),
              ),
              if (!isUser &&
                  message.kitPlan != null &&
                  message.kitPlan!.purchasableItems.isNotEmpty) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _confirmKitCart(message.kitPlan!),
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                    label: Text(
                      'Подтвердить корзину • ${ShopProductMapper.formatPrice(message.kitPlan!.estimatedTotal)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              if (!isUser && message.productSuggestions.isNotEmpty) ...[
                const SizedBox(height: 12),
                _buildProductSuggestions(message.productSuggestions, isDark),
              ],
              if (!isUser && message.sources.isNotEmpty) ...[
                const SizedBox(height: 10),
                _buildSourceChips(message.sources, isDark),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProductSuggestions(
    List<AiProductSuggestion> suggestions,
    bool isDark,
  ) {
    return Column(
      children:
          suggestions.map((product) {
            final color = ShopProductMapper.categoryColor(product.category);
            final inCart = _quantityInCart(product.id);
            final canAdd = product.stock > inCart;
            return Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color:
                      isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      ShopProductMapper.categoryIcon(product.category),
                      color: color,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          product.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color:
                                isDark
                                    ? const Color(0xFFF9FAFB)
                                    : const Color(0xFF111827),
                          ),
                        ),
                        if (product.subtitle.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            product.subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          '${product.price} • остаток ${product.stock}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: canAdd ? 'Добавить в корзину' : 'Недоступно',
                    style: IconButton.styleFrom(
                      backgroundColor: canAdd ? color : const Color(0xFF9CA3AF),
                      foregroundColor: Colors.white,
                      fixedSize: const Size(38, 38),
                    ),
                    onPressed:
                        canAdd ? () => _addSuggestedProduct(product) : null,
                    icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
                  ),
                ],
              ),
            );
          }).toList(),
    );
  }

  Widget _buildSourceChips(List<AiSourceReference> sources, bool isDark) {
    final visible = sources.take(3).toList();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children:
          visible.map((source) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color:
                    isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                  color:
                      isDark
                          ? const Color(0xFF374151)
                          : const Color(0xFFE5E7EB),
                ),
              ),
              child: Text(
                source.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6B7280),
                ),
              ),
            );
          }).toList(),
    );
  }

  void _addSuggestedProduct(AiProductSuggestion product) {
    final inCart = _quantityInCart(product.id);
    if (inCart >= product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Доступный остаток уже в корзине')),
      );
      return;
    }

    final map = product.toCartProduct();
    map['source'] = 'ai_chat_suggestion';
    CartProvider.instance.addItem(map);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${product.title} добавлен в корзину')),
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
              color: Colors.black.withValues(alpha: 0.05),
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
                final value = (_typingAnimController.value - delay).clamp(
                  0.0,
                  1.0,
                );
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
          children:
              _quickPrompts.map((prompt) {
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
                            color:
                                isAiTyping
                                    ? const Color(0xFFD1D5DB)
                                    : const Color(0xFFA855F7),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          color:
                              isAiTyping
                                  ? Colors.transparent
                                  : const Color(
                                    0xFFA855F7,
                                  ).withValues(alpha: 0.08),
                        ),
                        child: Text(
                          prompt,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color:
                                isAiTyping
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
            color: Colors.black.withValues(alpha: 0.06),
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
                fillColor:
                    isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
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
              gradient:
                  isAiTyping
                      ? const LinearGradient(
                        colors: [Color(0xFFD1D5DB), Color(0xFFD1D5DB)],
                      )
                      : const LinearGradient(
                        colors: [Color(0xFFA855F7), Color(0xFFEC4899)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
              borderRadius: BorderRadius.circular(16),
              boxShadow:
                  isAiTyping
                      ? []
                      : [
                        BoxShadow(
                          color: const Color(0xFFA855F7).withValues(alpha: 0.4),
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
  final AiKitPlan? kitPlan;
  final List<AiProductSuggestion> productSuggestions;
  final List<AiSourceReference> sources;
  final DateTime timestamp;

  _ChatMessage({
    required this.text,
    required this.isUser,
    this.kitPlan,
    this.productSuggestions = const [],
    this.sources = const [],
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
