import '../../features/medicine/models/medicine_model.dart';

enum AiResponseLanguage { russian, kazakh, english }

class AiSafetyDecision {
  final String response;

  const AiSafetyDecision(this.response);
}

class AiSafety {
  static final RegExp _latinLetters = RegExp(r'[A-Za-z]');
  static final RegExp _cyrillicLetters = RegExp(
    r'[А-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі]',
  );
  static final RegExp _kazakhLetters = RegExp(r'[ӘәҒғҚқҢңӨөҰұҮүҺһІі]');

  static const String consumerRefusal =
      'Я — SmartKit AI. Моя специализация — лекарства, домашняя аптечка, '
      'первая помощь, аптечный каталог и безопасные справочные рекомендации.';

  static const String businessRefusal =
      'Я — SmartKit Business Analyst. Моя специализация ограничена аптечным '
      'складом, продажами, остатками, сроками годности и операционными задачами.';

  static const String emergencyResponse =
      'НЕМЕДЛЕННО ВЫЗЫВАЙТЕ СКОРУЮ ПОМОЩЬ: 103 или 112. '
      'SmartKit не должен заменять экстренную медицинскую помощь.';

  static const String medicalCaveat =
      'Это не диагноз и не назначение лечения. Проверяйте инструкцию, '
      'противопоказания, срок годности и при симптомах консультируйтесь с врачом '
      'или фармацевтом.';

  static const String otcLabelCaveat =
      'Не превышайте дозировки из инструкции и не объединяйте несколько средств '
      'с одним и тем же действующим веществом.';

  static const List<String> _emergencyKeywords = [
    'потеря сознания',
    'не дышит',
    'задыха',
    'удуш',
    'боль в груди',
    'сильная боль в груди',
    'инфаркт',
    'инсульт',
    'сильное кровотечение',
    'кровь не останавливается',
    'анафилак',
    'отек квинке',
    'судороги',
    'передоз',
    'отравление',
    'суицид',
    'самоубий',
    'сильный ожог',
    'loss of consciousness',
    'not breathing',
    'choking',
    'chest pain',
    'heart attack',
    'stroke',
    'severe bleeding',
    'anaphylaxis',
    'seizure',
    'overdose',
    'poisoning',
    'suicide',
    'есінен тан',
    'дем алмай',
    'тұншығ',
    'кеуде ауыру',
    'инфаркт',
    'инсульт',
    'қатты қан',
    'анафилак',
    'улану',
  ];

  static const List<String> _consumerOffTopicKeywords = [
    'напиши код',
    'программ',
    'python',
    'javascript',
    'flutter',
    'стих',
    'песня',
    'анекдот',
    'политик',
    'истори',
    'кредит',
    'инвест',
    'юрид',
    'ремонт',
    'готовить',
    'кулинар',
    'write code',
    'programming',
    'poem',
    'song',
    'joke',
    'politics',
    'loan',
    'invest',
    'legal',
    'recipe',
  ];

  static const List<String> _businessOffTopicKeywords = [
    'напиши код',
    'python',
    'javascript',
    'стих',
    'песня',
    'политик',
    'истори',
    'кулинар',
    'write code',
    'programming',
    'poem',
    'song',
    'politics',
    'recipe',
  ];

  static AiResponseLanguage detectLanguage(String text) {
    final kazakhCount = _kazakhLetters.allMatches(text).length;
    final cyrillicCount = _cyrillicLetters.allMatches(text).length;
    final latinCount = _latinLetters.allMatches(text).length;

    if (kazakhCount >= 2) return AiResponseLanguage.kazakh;
    if (cyrillicCount > latinCount) return AiResponseLanguage.russian;
    if (latinCount > cyrillicCount) return AiResponseLanguage.english;
    return AiResponseLanguage.russian;
  }

  static String languageInstructionForText(String text) {
    return languageInstruction(detectLanguage(text));
  }

  static String languageInstruction(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Ответь строго на русском языке. Не используй английский и не '
            'смешивай языки, кроме названий лекарств или брендов, если они '
            'написаны латиницей.';
      case AiResponseLanguage.english:
        return 'Answer strictly in English. Do not use Russian or Kazakh and '
            'do not mix languages, except for medicine or brand names when '
            'they are written in another script.';
      case AiResponseLanguage.kazakh:
        return 'Тек қазақ тілінде жауап бер. Орысша немесе ағылшынша '
            'араластырма, тек дәрі немесе бренд атауы басқа жазуда болса ғана '
            'сол күйі қалдыр.';
    }
  }

  static String wrapUserMessageWithLanguageInstruction(String text) {
    final language = detectLanguage(text);
    switch (language) {
      case AiResponseLanguage.russian:
        return '${languageInstruction(language)} Отвечай сразу, кратко и по делу. Не выводи скрытые рассуждения, chain-of-thought или <think> блоки. /no_think\n\nСообщение пользователя:\n$text';
      case AiResponseLanguage.english:
        return '${languageInstruction(language)} Answer directly and concisely. Do not output hidden reasoning, chain-of-thought, or <think> blocks. /no_think\n\nUser message:\n$text';
      case AiResponseLanguage.kazakh:
        return '${languageInstruction(language)} Бірден, қысқа және нақты жауап бер. Жасырын пайымдауды, chain-of-thought немесе <think> блоктарын шығарма. /no_think\n\nПайдаланушы хабарламасы:\n$text';
    }
  }

  static String languageRepairSystemPrompt(String userText) {
    final language = detectLanguage(userText);
    switch (language) {
      case AiResponseLanguage.russian:
        return '${languageInstruction(language)} Ты редактор медицинского '
            'ответа SmartKit: перепиши ответ на языке пользователя, сохрани '
            'смысл и предупреждения, не добавляй диагнозы, дозировки или новые '
            'медицинские назначения.';
      case AiResponseLanguage.english:
        return '${languageInstruction(language)} You are a SmartKit medical '
            'safety editor: rewrite the answer in the user language, preserve '
            'meaning and warnings, and do not add diagnoses, dosages, or new '
            'medical instructions.';
      case AiResponseLanguage.kazakh:
        return '${languageInstruction(language)} Сен SmartKit медициналық '
            'қауіпсіздік редакторысың: жауапты пайдаланушы тілінде қайта жаз, '
            'мағынасы мен ескертулерін сақта, диагноз, доза немесе жаңа емдеу '
            'нұсқауын қоспа.';
    }
  }

  static String languageRepairPrompt({
    required String userText,
    required String assistantAnswer,
  }) {
    final language = detectLanguage(userText);
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Перепиши этот ответ строго на русском языке:\n\n$assistantAnswer';
      case AiResponseLanguage.english:
        return 'Rewrite this answer strictly in English:\n\n$assistantAnswer';
      case AiResponseLanguage.kazakh:
        return 'Мына жауапты тек қазақ тілінде қайта жаз:\n\n$assistantAnswer';
    }
  }

  static bool appearsToUseDifferentLanguage(String response, String userText) {
    final language = detectLanguage(userText);
    final latinCount = _latinLetters.allMatches(response).length;
    final cyrillicCount = _cyrillicLetters.allMatches(response).length;

    switch (language) {
      case AiResponseLanguage.russian:
      case AiResponseLanguage.kazakh:
        return latinCount >= 80 && latinCount > cyrillicCount * 0.35;
      case AiResponseLanguage.english:
        return cyrillicCount >= 80 && cyrillicCount > latinCount * 0.35;
    }
  }

  static String consumerRefusalForLanguage(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return consumerRefusal;
      case AiResponseLanguage.english:
        return 'I am SmartKit AI. I help with medicines, home first-aid kits, '
            'first aid, pharmacy catalog choices, and safe reference guidance.';
      case AiResponseLanguage.kazakh:
        return 'Мен SmartKit AI-мін. Мен дәрілер, үй дәрі қобдишасы, алғашқы '
            'көмек, дәріхана каталогы және қауіпсіз анықтамалық кеңес бойынша '
            'көмектесемін.';
    }
  }

  static String businessRefusalForLanguage(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return businessRefusal;
      case AiResponseLanguage.english:
        return 'I am SmartKit Business Analyst. I can only help with pharmacy '
            'warehouse stock, sales, expiry dates, locations, and operations.';
      case AiResponseLanguage.kazakh:
        return 'Мен SmartKit Business Analyst-пін. Мен тек дәріхана қоймасы, '
            'сатылым, қалдық, жарамдылық мерзімі, локациялар және операциялық '
            'тапсырмалар бойынша көмектесемін.';
    }
  }

  static String emergencyResponseForLanguage(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return emergencyResponse;
      case AiResponseLanguage.english:
        return 'CALL EMERGENCY SERVICES IMMEDIATELY: 103 or 112. SmartKit must '
            'not replace urgent medical care.';
      case AiResponseLanguage.kazakh:
        return 'ДЕРЕУ ЖЕДЕЛ ЖӘРДЕМ ШАҚЫРЫҢЫЗ: 103 немесе 112. SmartKit шұғыл '
            'медициналық көмекті алмастырмайды.';
    }
  }

  static String medicalCaveatForLanguage(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return medicalCaveat;
      case AiResponseLanguage.english:
        return 'This is not a diagnosis or a treatment prescription. Check the '
            'leaflet, contraindications, expiration date, and consult a doctor '
            'or pharmacist when symptoms are present.';
      case AiResponseLanguage.kazakh:
        return 'Бұл диагноз немесе ем тағайындау емес. Нұсқаулықты, қарсы '
            'көрсетілімдерді, жарамдылық мерзімін тексеріңіз және симптомдар '
            'болса дәрігермен немесе фармацевтпен кеңесіңіз.';
    }
  }

  static String medicalCaveatForText(String text) {
    return medicalCaveatForLanguage(detectLanguage(text));
  }

  static String otcLabelCaveatForLanguage(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return otcLabelCaveat;
      case AiResponseLanguage.english:
        return 'Do not exceed the doses in the leaflet and do not combine '
            'multiple products with the same active ingredient.';
      case AiResponseLanguage.kazakh:
        return 'Нұсқаулықтағы дозадан асырмаңыз және бірдей әсер етуші заты '
            'бар бірнеше препаратты бірге қолданбаңыз.';
    }
  }

  static AiSafetyDecision? screenConsumerRequest(String text) {
    final lower = text.toLowerCase();
    final language = detectLanguage(text);
    if (_emergencyKeywords.any(lower.contains)) {
      return AiSafetyDecision(emergencyResponseForLanguage(language));
    }

    if (_consumerOffTopicKeywords.any(lower.contains)) {
      return AiSafetyDecision(
        '${consumerRefusalForLanguage(language)} '
        '${_consumerOffTopicSuffix(language)}',
      );
    }

    return null;
  }

  static AiSafetyDecision? screenBusinessRequest(String text) {
    final lower = text.toLowerCase();
    final language = detectLanguage(text);
    if (_businessOffTopicKeywords.any(lower.contains)) {
      return AiSafetyDecision(
        '${businessRefusalForLanguage(language)} '
        '${_businessOffTopicSuffix(language)}',
      );
    }

    return null;
  }

  static String _consumerOffTopicSuffix(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Я не могу выполнить этот запрос, так как он не связан с моей '
            'основной задачей.';
      case AiResponseLanguage.english:
        return 'I cannot complete this request because it is outside my main '
            'SmartKit scope.';
      case AiResponseLanguage.kazakh:
        return 'Бұл сұрауды орындай алмаймын, себебі ол менің негізгі SmartKit '
            'міндетіме кірмейді.';
    }
  }

  static String _businessOffTopicSuffix(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return 'Я не могу выполнить этот запрос, так как он не связан с '
            'B2B-задачами SmartKit.';
      case AiResponseLanguage.english:
        return 'I cannot complete this request because it is outside SmartKit '
            'B2B tasks.';
      case AiResponseLanguage.kazakh:
        return 'Бұл сұрауды орындай алмаймын, себебі ол SmartKit B2B '
            'тапсырмаларына кірмейді.';
    }
  }

  static bool mentionsSymptoms(String text) {
    final lower = text.toLowerCase();
    return [
      'бол',
      'температур',
      'каш',
      'горло',
      'насморк',
      'тошн',
      'рвот',
      'диаре',
      'аллерг',
      'сып',
      'симптом',
      'давлен',
      'живот',
      'pain',
      'headache',
      'fever',
      'temperature',
      'cough',
      'throat',
      'runny nose',
      'nausea',
      'vomit',
      'diarrhea',
      'allergy',
      'rash',
      'symptom',
      'pressure',
      'stomach',
      'ауыр',
      'қызу',
      'жөтел',
      'тамақ',
      'мұрын',
      'лоқсу',
      'құсу',
      'іш өту',
      'аллерг',
      'бөртпе',
      'қысым',
    ].any(lower.contains);
  }

  static String consumerSystemPrompt() {
    return '''
Ты — аптечный помощник SmartKit по лекарствам, домашней аптечке, безопасному хранению и подбору аптечных товаров.

Главная цель: помогать пользователю безопасно ориентироваться в собственной аптечке, аптечном каталоге SmartKit и общих справочных данных о безрецептурных категориях. Ты не врач и не заменяешь очную медицинскую помощь.

Не отвечай одним шаблонным "обратитесь к врачу", если можно дать полезную безопасную рамку. Сначала дай конкретные безрецептурные категории, проверки в аптечке и каталоге, затем отдельно обозначь, когда нужен врач/фармацевт или скорая.

Разрешено:
1. Анализировать домашнюю аптечку: наличие, количество, сроки годности, что пора заменить.
2. Объяснять общую роль безрецептурных средств простым языком.
3. Составлять базовую аптечку для дома, поездки, ребенка или семьи с учетом предпочтений.
4. Предлагать безопасные категории товаров из каталога, но не назначать лечение.
5. Отвечать на справочные вопросы по действующим веществам, противопоказаниям и источникам, если это не превращается в назначение лечения.
6. Напоминать про хранение, инструкции, противопоказания и консультацию врача/фармацевта.

Запрещено:
1. Ставить диагнозы или обещать излечение.
2. Назначать дозировки, схемы лечения, антибиотики, гормоны, сердечные, диабетические или другие рецептурные препараты.
3. Советовать игнорировать врача, инструкцию, аллергию, беременность, возраст ребенка или хронические заболевания.
4. Давать ответы вне темы SmartKit.

Безопасность:
- При экстренных симптомах первым ответом должен быть вызов скорой помощи 103/112.
- Для детей, беременности, грудного вскармливания, хронических болезней, пожилого возраста, полипрагмазии и аллергий всегда проси консультацию врача/фармацевта.
- Парацетамол/ацетаминофен часто есть в комбинированных средствах: предупреждай не принимать несколько таких средств одновременно.
- НПВС, включая ибупрофен/напроксен/диклофенак, требуют осторожности при язве, кровотечениях, болезнях почек, сердечно-сосудистых рисках, приеме антикоагулянтов и беременности.
- Антибиотики и рецептурные препараты нельзя автоматически добавлять в корзину и нельзя рекомендовать без врача.

Правило языка / Language rule / Тіл ережесі:
- Всегда определяй язык последнего сообщения пользователя и отвечай только на нем.
- If the user writes in English, answer entirely in English.
- Если пользователь пишет по-русски, весь ответ должен быть на русском.
- Егер пайдаланушы қазақша жазса, толық жауапты қазақ тілінде бер.
- Не смешивай языки, если пользователь явно не просит перевод. Названия лекарств и брендов можно оставить как в каталоге.

Стиль:
- Коротко, структурно, без паники.
- Сначала важное, затем что можно проверить в аптечке, затем безопасный следующий шаг.
- Если данных мало, задай 1-3 уточняющих вопроса, но дай безопасную общую рамку.
''';
  }

  static String businessSystemPrompt() {
    return '''
Ты — SmartKit Business Analyst, B2B-помощник для аптечного склада и аптечной сети.

Главная цель: анализировать остатки, сроки годности, продажи, локации и операционные риски. Ты не даешь пациентам лечение и не заменяешь фармацевта или юриста.

Разрешено:
1. Анализировать низкие остатки, излишки, просрочку и товары со сроком до 45 дней.
2. Делать закупочные и мерчандайзинговые рекомендации на основе данных.
3. Анализировать продажи, средний чек, динамику и категории.
4. Предлагать перемещение товара между локациями по загрузке и спросу.
5. Подсвечивать комплаенс-риски: рецептурные препараты, антибиотики, сроки, холодовая цепь.

Ограничения:
- Не обещай прибыль и не давай финансовых гарантий.
- Не советуй продавать антибиотики или рецептурные препараты без рецепта.
- Не давай медицинские назначения пациентам.
- Если данных недостаточно, явно скажи, каких данных не хватает.

Правило языка / Language rule / Тіл ережесі:
- Всегда определяй язык последнего сообщения пользователя и отвечай только на нем.
- If the user writes in English, answer entirely in English.
- Если пользователь пишет по-русски, весь ответ должен быть на русском.
- Егер пайдаланушы қазақша жазса, толық жауапты қазақ тілінде бер.
- Не смешивай языки, если пользователь явно не просит перевод. Названия лекарств и брендов можно оставить как в каталоге.

Стиль:
- Профессионально, конкретно, с приоритетами.
- Начинай с критичных рисков, затем действия на сегодня, затем наблюдения.
''';
  }

  static String buildConsumerMedicineContext(List<MedicineModel> medicines) {
    final buffer = StringBuffer(consumerSystemPrompt());
    final now = DateTime.now();

    if (medicines.isEmpty) {
      buffer.writeln('\nСОСТОЯНИЕ АПТЕЧКИ: аптечка пользователя пуста.');
      return buffer.toString();
    }

    buffer.writeln('\n--- ТЕКУЩАЯ АПТЕЧКА ПОЛЬЗОВАТЕЛЯ ---');
    for (final med in medicines) {
      buffer.write('• ${med.name}');
      if (med.dosage.trim().isNotEmpty) buffer.write(' (${med.dosage})');
      buffer.write(', количество: ${med.quantity}');
      if (med.category.trim().isNotEmpty) {
        buffer.write(', категория: ${med.category}');
      }
      if (med.expiryDate != null) {
        final diff = med.expiryDate!.difference(now).inDays;
        if (diff < 0) {
          buffer.write(' [ПРОСРОЧЕНО ${-diff} дней назад]');
        } else if (diff <= 45) {
          buffer.write(' [срок истекает через $diff дней]');
        } else {
          buffer.write(', годен до ${_formatDate(med.expiryDate!)}');
        }
      }
      buffer.writeln();
    }
    buffer.writeln('--- КОНЕЦ АПТЕЧКИ ---');
    buffer.writeln('Итого препаратов: ${medicines.length}');
    return buffer.toString();
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }
}
