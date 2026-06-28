import 'package:flutter_test/flutter_test.dart';
import 'package:smartkit/core/services/ai_runtime_config.dart';

void main() {
  test('allocates larger generation budget for full business reports', () {
    final longReportPrompt = List.filled(60, 'данные склада').join(' ');
    final options = AiRuntimeConfig.ollamaOptions(
      userText: longReportPrompt,
      business: true,
    );

    expect(options['num_ctx'], 4096);
    expect(options['num_predict'], 1500);
  });

  test('removes hidden Qwen thinking blocks from visible answers', () {
    final cleaned = AiRuntimeConfig.sanitizeAssistantContent(
      '<think>internal chain</think>\nПроверьте аптечку и сроки годности.',
    );

    expect(cleaned, 'Проверьте аптечку и сроки годности.');
  });
}
