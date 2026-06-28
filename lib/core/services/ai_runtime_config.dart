class AiRuntimeConfig {
  static const Duration backendTimeout = Duration(seconds: 7);
  static const Duration localTimeout = Duration(seconds: 12);
  static const Duration repairTimeout = Duration(seconds: 5);

  static Map<String, dynamic> ollamaOptions({
    required String userText,
    double temperature = 0.25,
    bool repair = false,
    bool business = false,
  }) {
    return {
      'temperature': repair ? 0.1 : temperature,
      'top_p': repair ? 0.75 : 0.82,
      'num_ctx': business ? 4096 : 3584,
      'num_predict': _predictionBudget(
        userText,
        repair: repair,
        business: business,
      ),
      'repeat_penalty': 1.08,
    };
  }

  static List<Map<String, String>> compactMessages(
    List<Map<String, String>> history, {
    int recentMessages = 6,
    int systemLimit = 1800,
    int messageLimit = 620,
  }) {
    if (history.isEmpty) return const [];

    final system = history.firstWhere(
      (message) => message['role'] == 'system',
      orElse: () => history.first,
    );
    final recent =
        history
            .where((message) => message['role'] != 'system')
            .toList()
            .reversed
            .take(recentMessages)
            .toList()
            .reversed;

    return [
      {
        'role': system['role'] ?? 'system',
        'content': _trim(system['content'] ?? '', systemLimit),
      },
      ...recent.map(
        (message) => {
          'role': message['role'] ?? 'user',
          'content': _trim(message['content'] ?? '', messageLimit),
        },
      ),
    ];
  }

  static void remember(
    List<Map<String, String>> history,
    String role,
    String content, {
    int maxMessages = 11,
  }) {
    history.add({'role': role, 'content': content});
    if (history.length <= maxMessages) return;

    final system =
        history.isNotEmpty && history.first['role'] == 'system'
            ? history.first
            : null;
    final recent =
        history
            .where((message) => message['role'] != 'system')
            .toList()
            .reversed
            .take(maxMessages - (system == null ? 0 : 1))
            .toList()
            .reversed
            .toList();

    history
      ..clear()
      ..addAll([if (system != null) system, ...recent]);
  }

  static String sanitizeAssistantContent(String value) {
    return value
        .replaceAll(
          RegExp(r'<think>[\s\S]*?</think>', caseSensitive: false),
          '',
        )
        .trim();
  }

  static int _predictionBudget(
    String userText, {
    required bool repair,
    required bool business,
  }) {
    if (repair) return 360;
    final length = userText.trim().length;
    if (length <= 80) return business ? 260 : 320;
    if (length <= 220) return business ? 420 : 560;
    return business ? 720 : 900;
  }

  static String _trim(String value, int limit) {
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.length <= limit) return normalized;
    return '${normalized.substring(0, limit)}...';
  }
}
