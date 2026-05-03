import '../../../core/services/ai_safety.dart';
import '../../b2b/inventory/models/b2b_inventory_model.dart';
import '../../medicine/models/medicine_model.dart';

class AiKitPreferences {
  final String scenario;
  final bool forChild;
  final bool forTravel;
  final bool includeAllergy;
  final bool includeDigestive;
  final bool includeColdCare;
  final bool includeWoundCare;
  final bool hasChronicConditions;
  final bool pregnantOrBreastfeeding;

  const AiKitPreferences({
    required this.scenario,
    this.forChild = false,
    this.forTravel = false,
    this.includeAllergy = true,
    this.includeDigestive = true,
    this.includeColdCare = true,
    this.includeWoundCare = true,
    this.hasChronicConditions = false,
    this.pregnantOrBreastfeeding = false,
  });

  AiKitPreferences copyWith({
    String? scenario,
    bool? forChild,
    bool? forTravel,
    bool? includeAllergy,
    bool? includeDigestive,
    bool? includeColdCare,
    bool? includeWoundCare,
    bool? hasChronicConditions,
    bool? pregnantOrBreastfeeding,
  }) {
    return AiKitPreferences(
      scenario: scenario ?? this.scenario,
      forChild: forChild ?? this.forChild,
      forTravel: forTravel ?? this.forTravel,
      includeAllergy: includeAllergy ?? this.includeAllergy,
      includeDigestive: includeDigestive ?? this.includeDigestive,
      includeColdCare: includeColdCare ?? this.includeColdCare,
      includeWoundCare: includeWoundCare ?? this.includeWoundCare,
      hasChronicConditions: hasChronicConditions ?? this.hasChronicConditions,
      pregnantOrBreastfeeding:
          pregnantOrBreastfeeding ?? this.pregnantOrBreastfeeding,
    );
  }
}

class AiKitPlanItem {
  final String title;
  final String purpose;
  final String safetyNote;
  final int quantity;
  final B2BInventoryModel? product;
  final bool alreadyCovered;
  final bool requiresProfessionalAdvice;

  const AiKitPlanItem({
    required this.title,
    required this.purpose,
    required this.safetyNote,
    required this.quantity,
    this.product,
    this.alreadyCovered = false,
    this.requiresProfessionalAdvice = false,
  });

  bool get canPurchase {
    return product != null &&
        !alreadyCovered &&
        !requiresProfessionalAdvice &&
        product!.stock > 0;
  }

  String get displayName => product?.name ?? title;
}

class AiKitPlan {
  final String title;
  final String summary;
  final AiKitPreferences preferences;
  final List<AiKitPlanItem> items;
  final List<String> safetyNotes;

  const AiKitPlan({
    required this.title,
    required this.summary,
    required this.preferences,
    required this.items,
    required this.safetyNotes,
  });

  List<AiKitPlanItem> get purchasableItems {
    return items.where((item) => item.canPurchase).toList();
  }

  List<AiKitPlanItem> get missingItems {
    return items
        .where((item) => item.product == null && !item.alreadyCovered)
        .toList();
  }

  List<AiKitPlanItem> get coveredItems {
    return items.where((item) => item.alreadyCovered).toList();
  }

  int get estimatedTotal {
    return purchasableItems.fold(
      0,
      (sum, item) => sum + (item.product?.price ?? 0) * item.quantity,
    );
  }
}

class _KitNeed {
  final String title;
  final String purpose;
  final String safetyNote;
  final List<String> productKeywords;
  final List<String> homeKeywords;
  final List<String> categoryKeywords;
  final bool requiredAgeSpecificForm;
  final bool requiresProfessionalAdvice;

  const _KitNeed({
    required this.title,
    required this.purpose,
    required this.safetyNote,
    required this.productKeywords,
    required this.homeKeywords,
    this.categoryKeywords = const [],
    this.requiredAgeSpecificForm = false,
    this.requiresProfessionalAdvice = false,
  });
}

class AiKitPlanner {
  static bool hasKitIntent(String text) {
    final lower = text.toLowerCase();
    final hasKitWord = [
      'аптечк',
      'набор',
      'комплект',
      'корзин',
      'добавь',
      'собери',
      'first aid kit',
      'medicine kit',
      'basic kit',
      'cart',
      'basket',
      'kit',
      'дәрі қобдиша',
      'себет',
      'жинақ',
    ].any(lower.contains);
    final hasAction = [
      'собер',
      'созда',
      'подбер',
      'добав',
      'купи',
      'закаж',
      'базов',
      'build',
      'assemble',
      'create',
      'add',
      'buy',
      'order',
      'basic',
      'жина',
      'құр',
      'қос',
      'сатып',
      'негізгі',
    ].any(lower.contains);
    return hasKitWord && hasAction;
  }

  static AiKitPreferences preferencesFromText(String text) {
    final lower = text.toLowerCase();
    final forChild = [
      'ребен',
      'ребён',
      'детск',
      'малыш',
      'детей',
      'child',
      'kid',
      'baby',
      'children',
      'бала',
      'нәресте',
    ].any(lower.contains);
    final forTravel = [
      'поезд',
      'путеше',
      'дорог',
      'отпуск',
      'самолет',
      'самолёт',
      'travel',
      'trip',
      'vacation',
      'flight',
      'plane',
      'сапар',
      'жол',
      'ұшақ',
      'демалыс',
    ].any(lower.contains);
    final chronic = [
      'хронич',
      'давлен',
      'диабет',
      'серд',
      'почки',
      'язв',
      'chronic',
      'pressure',
      'diabetes',
      'heart',
      'kidney',
      'ulcer',
      'созылмалы',
      'қысым',
      'диабет',
      'жүрек',
      'бүйрек',
      'ойық жара',
    ].any(lower.contains);
    final pregnancy = [
      'беремен',
      'груд',
      'лактац',
      'корм',
      'pregnan',
      'breastfeed',
      'lactation',
      'жүкт',
      'еміз',
    ].any(lower.contains);
    final minimal = [
      'миним',
      'minimum',
      'minimal',
      'basic only',
      'ең аз',
      'минималды',
    ].any(lower.contains);

    return AiKitPreferences(
      scenario:
          forChild
              ? 'Для ребенка'
              : forTravel
              ? 'Аптечка в поездку'
              : 'Домашняя аптечка',
      forChild: forChild,
      forTravel: forTravel,
      includeAllergy:
          lower.contains('аллер') || lower.contains('allerg') || !minimal,
      includeDigestive:
          lower.contains('живот') ||
          lower.contains('жкт') ||
          lower.contains('отрав') ||
          lower.contains('диаре') ||
          lower.contains('stomach') ||
          lower.contains('digest') ||
          lower.contains('poison') ||
          lower.contains('diarrhea') ||
          lower.contains('іш') ||
          forTravel ||
          !minimal,
      includeColdCare:
          lower.contains('простуд') ||
          lower.contains('грип') ||
          lower.contains('нос') ||
          lower.contains('горло') ||
          lower.contains('cold') ||
          lower.contains('flu') ||
          lower.contains('nose') ||
          lower.contains('throat') ||
          lower.contains('суық') ||
          lower.contains('тұмау') ||
          lower.contains('тамақ') ||
          !minimal,
      includeWoundCare: true,
      hasChronicConditions: chronic,
      pregnantOrBreastfeeding: pregnancy,
    );
  }

  static AiKitPlan buildPlan({
    required AiKitPreferences preferences,
    required List<B2BInventoryModel> catalog,
    required List<MedicineModel> homeMedicines,
  }) {
    final needs = _buildNeeds(preferences);
    final items = <AiKitPlanItem>[];

    for (final need in needs) {
      final alreadyCovered = _isCoveredByHome(need, homeMedicines);
      final product =
          alreadyCovered || need.requiresProfessionalAdvice
              ? null
              : _findProduct(need, catalog);

      items.add(
        AiKitPlanItem(
          title: need.title,
          purpose: need.purpose,
          safetyNote: need.safetyNote,
          quantity: 1,
          product: product,
          alreadyCovered: alreadyCovered,
          requiresProfessionalAdvice: need.requiresProfessionalAdvice,
        ),
      );
    }

    final safetyNotes = <String>[
      'Корзина собирается только из базовых безрецептурных категорий и доступных складских товаров.',
      'Антибиотики, сердечные, диабетические, гормональные и другие рецептурные препараты не добавляются автоматически.',
      'Перед применением проверяйте инструкцию, противопоказания, возрастные ограничения и срок годности.',
      if (preferences.forChild)
        'Для ребенка нужны возрастные формы и дозировки. Взрослые таблетки не заменяют детские препараты.',
      if (preferences.hasChronicConditions)
        'При хронических заболеваниях базовый набор лучше сверить с врачом или фармацевтом.',
      if (preferences.pregnantOrBreastfeeding)
        'При беременности или грудном вскармливании не начинайте препараты без консультации врача.',
    ];

    return AiKitPlan(
      title: preferences.scenario,
      summary: _summaryFor(preferences),
      preferences: preferences,
      items: items,
      safetyNotes: safetyNotes,
    );
  }

  static String chatSummary(AiKitPlan plan, {String? userText}) {
    final language =
        userText == null
            ? AiResponseLanguage.russian
            : AiSafety.detectLanguage(userText);
    if (language != AiResponseLanguage.russian) {
      return _localizedChatSummary(plan, language);
    }

    final buffer = StringBuffer();
    buffer.writeln('Собрал безопасный план: ${plan.title}.');

    final purchasable = plan.purchasableItems;
    if (purchasable.isNotEmpty) {
      buffer.writeln('\nМожно добавить в корзину:');
      for (final item in purchasable.take(8)) {
        buffer.writeln('• ${item.product!.name} — ${item.purpose}');
      }
    } else {
      buffer.writeln(
        '\nВ каталоге нет безопасных позиций, которые можно добавить автоматически.',
      );
    }

    if (plan.coveredItems.isNotEmpty) {
      buffer.writeln('\nУже есть в вашей аптечке:');
      for (final item in plan.coveredItems.take(4)) {
        buffer.writeln('• ${item.title}');
      }
    }

    if (plan.missingItems.isNotEmpty) {
      buffer.writeln('\nНужно докупить отдельно или уточнить у фармацевта:');
      for (final item in plan.missingItems.take(5)) {
        buffer.writeln('• ${item.title}');
      }
    }

    buffer.writeln(
      '\nНажмите кнопку подтверждения, и я добавлю доступные позиции в корзину.',
    );
    buffer.writeln('\nВажно: ${plan.safetyNotes.first}');
    return buffer.toString();
  }

  static String _localizedChatSummary(
    AiKitPlan plan,
    AiResponseLanguage language,
  ) {
    final buffer = StringBuffer();

    switch (language) {
      case AiResponseLanguage.english:
        buffer.writeln(
          'I built a safe plan: ${_localizedPlanTitle(plan, language)}.',
        );
        break;
      case AiResponseLanguage.kazakh:
        buffer.writeln(
          'Қауіпсіз жоспар құрдым: ${_localizedPlanTitle(plan, language)}.',
        );
        break;
      case AiResponseLanguage.russian:
        buffer.writeln('Собрал безопасный план: ${plan.title}.');
        break;
    }

    final purchasable = plan.purchasableItems;
    if (purchasable.isNotEmpty) {
      buffer.writeln(_cartSectionTitle(language));
      for (final item in purchasable.take(8)) {
        buffer.writeln(
          '• ${item.product!.name} — ${_localizedNeedTitle(item.title, language)}',
        );
      }
    } else {
      buffer.writeln(_noPurchasableLine(language));
    }

    if (plan.coveredItems.isNotEmpty) {
      buffer.writeln(_coveredSectionTitle(language));
      for (final item in plan.coveredItems.take(4)) {
        buffer.writeln('• ${_localizedNeedTitle(item.title, language)}');
      }
    }

    if (plan.missingItems.isNotEmpty) {
      buffer.writeln(_missingSectionTitle(language));
      for (final item in plan.missingItems.take(5)) {
        buffer.writeln('• ${_localizedNeedTitle(item.title, language)}');
      }
    }

    buffer.writeln(_confirmCartLine(language));
    buffer.writeln(_firstSafetyNote(language));
    return buffer.toString();
  }

  static String _localizedPlanTitle(
    AiKitPlan plan,
    AiResponseLanguage language,
  ) {
    if (plan.preferences.forChild) {
      switch (language) {
        case AiResponseLanguage.russian:
          return 'Для ребенка';
        case AiResponseLanguage.english:
          return 'Child first-aid kit';
        case AiResponseLanguage.kazakh:
          return 'Балаға арналған дәрі қобдишасы';
      }
    }
    if (plan.preferences.forTravel) {
      switch (language) {
        case AiResponseLanguage.russian:
          return 'Аптечка в поездку';
        case AiResponseLanguage.english:
          return 'Travel first-aid kit';
        case AiResponseLanguage.kazakh:
          return 'Сапарға арналған дәрі қобдишасы';
      }
    }
    switch (language) {
      case AiResponseLanguage.russian:
        return plan.title;
      case AiResponseLanguage.english:
        return 'Home first-aid kit';
      case AiResponseLanguage.kazakh:
        return 'Үй дәрі қобдишасы';
    }
  }

  static String _cartSectionTitle(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '\nМожно добавить в корзину:';
      case AiResponseLanguage.english:
        return '\nCan be added to the cart:';
      case AiResponseLanguage.kazakh:
        return '\nСебетке қосуға болады:';
    }
  }

  static String _coveredSectionTitle(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '\nУже есть в вашей аптечке:';
      case AiResponseLanguage.english:
        return '\nAlready covered in your first-aid kit:';
      case AiResponseLanguage.kazakh:
        return '\nДәрі қобдишаңызда бар:';
    }
  }

  static String _missingSectionTitle(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '\nНужно докупить отдельно или уточнить у фармацевта:';
      case AiResponseLanguage.english:
        return '\nBuy separately or confirm with a pharmacist:';
      case AiResponseLanguage.kazakh:
        return '\nБөлек алу немесе фармацевтпен нақтылау керек:';
    }
  }

  static String _noPurchasableLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '\nВ каталоге нет безопасных позиций, которые можно добавить автоматически.';
      case AiResponseLanguage.english:
        return '\nThe catalog has no safe items that can be added automatically.';
      case AiResponseLanguage.kazakh:
        return '\nКаталогта автоматты түрде қосуға болатын қауіпсіз позициялар жоқ.';
    }
  }

  static String _confirmCartLine(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '\nНажмите кнопку подтверждения, и я добавлю доступные позиции в корзину.';
      case AiResponseLanguage.english:
        return '\nPress the confirmation button, and I will add available items to the cart.';
      case AiResponseLanguage.kazakh:
        return '\nРастау батырмасын басыңыз, мен қолжетімді позицияларды себетке қосамын.';
    }
  }

  static String _firstSafetyNote(AiResponseLanguage language) {
    switch (language) {
      case AiResponseLanguage.russian:
        return '\nВажно: Корзина собирается только из базовых безрецептурных категорий и доступных складских товаров.';
      case AiResponseLanguage.english:
        return '\nImportant: the cart is built only from basic over-the-counter categories and available stock items.';
      case AiResponseLanguage.kazakh:
        return '\nМаңызды: себет тек негізгі рецептсіз санаттардан және қолжетімді қойма тауарларынан құралады.';
    }
  }

  static String _localizedNeedTitle(String title, AiResponseLanguage language) {
    if (language == AiResponseLanguage.russian) return title;

    final english = <String, String>{
      'Детское жаропонижающее по возрасту':
          'Age-appropriate fever reducer for children',
      'Солевой спрей для носа': 'Saline nasal spray',
      'Антисептик для мелких ран': 'Antiseptic for minor wounds',
      'Средство для ожогов и раздражения кожи':
          'Care product for minor burns and skin irritation',
      'Пластыри и стерильные салфетки': 'Plasters and sterile wipes',
      'Термометр': 'Thermometer',
      'Обезболивающее и жаропонижающее': 'Pain and fever relief',
      'Антисептик': 'Antiseptic',
      'Пластыри, бинт и стерильные салфетки':
          'Plasters, bandage, and sterile wipes',
      'Средство для небольших ожогов': 'Care product for minor burns',
      'Средство от аллергии': 'Allergy medicine',
      'Средство для регидратации': 'Rehydration product',
      'Сорбент': 'Sorbent',
      'Средство для горла': 'Throat care product',
      'Средство от укачивания': 'Motion sickness product',
      'Индивидуальные препараты по назначению врача':
          'Doctor-prescribed personal medicines',
    };

    final kazakh = <String, String>{
      'Детское жаропонижающее по возрасту':
          'Баланың жасына сай қызу түсіретін құрал',
      'Солевой спрей для носа': 'Мұрынға арналған тұзды спрей',
      'Антисептик для мелких ран': 'Ұсақ жараларға арналған антисептик',
      'Средство для ожогов и раздражения кожи':
          'Ұсақ күйік пен тері тітіркенуіне арналған күтім құралы',
      'Пластыри и стерильные салфетки': 'Пластырь және стерильді сулықтар',
      'Термометр': 'Термометр',
      'Обезболивающее и жаропонижающее': 'Ауырсыну мен қызуға арналған құрал',
      'Антисептик': 'Антисептик',
      'Пластыри, бинт и стерильные салфетки':
          'Пластырь, бинт және стерильді сулықтар',
      'Средство для небольших ожогов': 'Ұсақ күйікке арналған күтім құралы',
      'Средство от аллергии': 'Аллергияға арналған құрал',
      'Средство для регидратации': 'Регидратацияға арналған құрал',
      'Сорбент': 'Сорбент',
      'Средство для горла': 'Тамаққа арналған күтім құралы',
      'Средство от укачивания': 'Жолда жүрек айнуына арналған құрал',
      'Индивидуальные препараты по назначению врача':
          'Дәрігер тағайындаған жеке препараттар',
    };

    switch (language) {
      case AiResponseLanguage.russian:
        return title;
      case AiResponseLanguage.english:
        return english[title] ?? title;
      case AiResponseLanguage.kazakh:
        return kazakh[title] ?? title;
    }
  }

  static List<_KitNeed> _buildNeeds(AiKitPreferences preferences) {
    if (preferences.forChild) {
      return [
        const _KitNeed(
          title: 'Детское жаропонижающее по возрасту',
          purpose: 'Для температуры и боли у ребенка',
          safetyNote:
              'Нужна детская форма и дозировка по возрасту/весу; взрослые формы не подходят.',
          productKeywords: ['детск', 'сироп', 'суспенз'],
          homeKeywords: ['детск', 'парацетамол', 'ибупрофен'],
          categoryKeywords: ['обезбол', 'жаропониж'],
          requiredAgeSpecificForm: true,
          requiresProfessionalAdvice: true,
        ),
        const _KitNeed(
          title: 'Солевой спрей для носа',
          purpose: 'Для промывания носа и ухода при насморке',
          safetyNote: 'Использовать по инструкции и возрастной маркировке.',
          productKeywords: ['аква марис', 'аквалор'],
          homeKeywords: ['аква марис', 'аквалор', 'солев'],
          categoryKeywords: ['насморк'],
        ),
        const _KitNeed(
          title: 'Антисептик для мелких ран',
          purpose: 'Для первичной обработки небольших ссадин',
          safetyNote: 'Не наносить в глубокие раны без медицинской помощи.',
          productKeywords: ['мирамистин', 'хлоргексидин'],
          homeKeywords: ['мирамистин', 'хлоргексидин', 'антисеп'],
          categoryKeywords: ['антисеп'],
        ),
        const _KitNeed(
          title: 'Средство для ожогов и раздражения кожи',
          purpose: 'Для ухода за небольшими бытовыми ожогами',
          safetyNote: 'При сильном ожоге нужна срочная медицинская помощь.',
          productKeywords: ['пантенол', 'бепантен', 'декспантенол'],
          homeKeywords: ['пантенол', 'бепантен', 'декспантенол'],
          categoryKeywords: ['дермат'],
        ),
        const _KitNeed(
          title: 'Пластыри и стерильные салфетки',
          purpose: 'Для закрытия мелких порезов и ссадин',
          safetyNote: 'Не заменяет обработку глубоких ран.',
          productKeywords: ['пластыр', 'салфет'],
          homeKeywords: ['пластыр', 'салфет', 'бинт'],
        ),
        const _KitNeed(
          title: 'Термометр',
          purpose: 'Для контроля температуры',
          safetyNote: 'Измерение температуры не заменяет оценку врача.',
          productKeywords: ['термометр'],
          homeKeywords: ['термометр'],
        ),
      ];
    }

    final needs = <_KitNeed>[
      const _KitNeed(
        title: 'Обезболивающее и жаропонижающее',
        purpose: 'Для боли или температуры у взрослых',
        safetyNote:
            'Не сочетайте несколько средств с парацетамолом; НПВС требуют осторожности при язве, почках, сердце и беременности.',
        productKeywords: ['парацетамол', 'ибупрофен', 'нурофен'],
        homeKeywords: ['парацетамол', 'ибупрофен', 'нурофен', 'цитрамон'],
        categoryKeywords: ['обезбол'],
      ),
      if (preferences.includeWoundCare) ...[
        const _KitNeed(
          title: 'Антисептик',
          purpose: 'Для обработки мелких ран и ссадин',
          safetyNote:
              'Глубокие, укушенные или сильно загрязненные раны должен оценить врач.',
          productKeywords: ['хлоргексидин', 'мирамистин', 'перекись'],
          homeKeywords: ['хлоргексидин', 'мирамистин', 'перекись', 'антисеп'],
          categoryKeywords: ['антисеп'],
        ),
        const _KitNeed(
          title: 'Пластыри, бинт и стерильные салфетки',
          purpose: 'Для закрытия мелких повреждений кожи',
          safetyNote: 'При сильном кровотечении вызывайте скорую помощь.',
          productKeywords: ['пластыр', 'бинт', 'салфет'],
          homeKeywords: ['пластыр', 'бинт', 'салфет'],
        ),
        const _KitNeed(
          title: 'Средство для небольших ожогов',
          purpose: 'Для ухода за кожей после бытовых ожогов',
          safetyNote:
              'Сильные ожоги, ожоги лица или большой площади требуют врача.',
          productKeywords: ['пантенол', 'бепантен', 'декспантенол'],
          homeKeywords: ['пантенол', 'бепантен', 'декспантенол'],
          categoryKeywords: ['дермат'],
        ),
      ],
      const _KitNeed(
        title: 'Термометр',
        purpose: 'Для контроля температуры',
        safetyNote:
            'Температура с тяжелым состоянием требует медицинской оценки.',
        productKeywords: ['термометр'],
        homeKeywords: ['термометр'],
      ),
      if (preferences.includeAllergy)
        const _KitNeed(
          title: 'Средство от аллергии',
          purpose: 'Для легких аллергических проявлений',
          safetyNote:
              'При отеке лица, губ, языка, одышке или резкой слабости вызывайте 103/112.',
          productKeywords: ['лоратадин', 'цетрин', 'зодак', 'зиртек'],
          homeKeywords: ['лоратадин', 'цетрин', 'зодак', 'зиртек', 'супрастин'],
          categoryKeywords: ['аллер'],
        ),
      if (preferences.includeDigestive) ...[
        const _KitNeed(
          title: 'Средство для регидратации',
          purpose: 'Для восполнения жидкости при диарее или рвоте',
          safetyNote:
              'При крови, высокой температуре или обезвоживании нужен врач.',
          productKeywords: ['регидрон'],
          homeKeywords: ['регидрон', 'оральн', 'регидратац'],
          categoryKeywords: ['жкт'],
        ),
        const _KitNeed(
          title: 'Сорбент',
          purpose: 'Для кратковременной помощи при пищевом дискомфорте',
          safetyNote: 'Сорбенты могут мешать всасыванию других лекарств.',
          productKeywords: [
            'смекта',
            'полисорб',
            'энтеросгель',
            'активированный уголь',
          ],
          homeKeywords: ['смекта', 'полисорб', 'энтеросгель', 'уголь'],
          categoryKeywords: ['жкт', 'сорб'],
        ),
      ],
      if (preferences.includeColdCare) ...[
        const _KitNeed(
          title: 'Солевой спрей для носа',
          purpose: 'Для ухода при насморке и сухости носа',
          safetyNote:
              'Сосудосуживающие спреи нельзя использовать дольше инструкции.',
          productKeywords: ['аква марис', 'аквалор'],
          homeKeywords: ['аква марис', 'аквалор', 'солев'],
          categoryKeywords: ['насморк'],
        ),
        const _KitNeed(
          title: 'Средство для горла',
          purpose: 'Для симптоматического ухода при боли в горле',
          safetyNote:
              'При высокой температуре, гное или затрудненном дыхании нужен врач.',
          productKeywords: [
            'лизобакт',
            'фарингосепт',
            'тантум верде',
            'стрепсилс',
          ],
          homeKeywords: ['лизобакт', 'фарингосепт', 'тантум', 'стрепсилс'],
          categoryKeywords: ['горло', 'каш'],
        ),
      ],
      if (preferences.forTravel)
        const _KitNeed(
          title: 'Средство от укачивания',
          purpose: 'Для поездок и перелетов',
          safetyNote:
              'Может вызывать сонливость и иметь возрастные ограничения.',
          productKeywords: ['укач', 'драмина'],
          homeKeywords: ['укач', 'драмина'],
        ),
    ];

    if (preferences.hasChronicConditions ||
        preferences.pregnantOrBreastfeeding) {
      needs.add(
        const _KitNeed(
          title: 'Индивидуальные препараты по назначению врача',
          purpose: 'Для хронических состояний или особых периодов',
          safetyNote: 'Такие препараты нельзя подбирать автоматически.',
          productKeywords: [],
          homeKeywords: [],
          requiresProfessionalAdvice: true,
        ),
      );
    }

    return needs;
  }

  static bool _isCoveredByHome(_KitNeed need, List<MedicineModel> medicines) {
    final now = DateTime.now();
    for (final medicine in medicines) {
      if (medicine.quantity <= 0) continue;
      if (medicine.expiryDate != null && medicine.expiryDate!.isBefore(now)) {
        continue;
      }
      final searchable =
          '${medicine.name} ${medicine.category} ${medicine.dosage}'
              .toLowerCase();
      if (need.homeKeywords.any(searchable.contains)) {
        return true;
      }
    }
    return false;
  }

  static B2BInventoryModel? _findProduct(
    _KitNeed need,
    List<B2BInventoryModel> catalog,
  ) {
    final validProducts =
        catalog.where((product) {
          if (product.stock <= 0) return false;
          if (_isRestrictedProduct(product)) return false;
          if (product.expiryDate != null &&
              product.expiryDate!.isBefore(DateTime.now())) {
            return false;
          }
          if (need.requiredAgeSpecificForm) {
            final text = _productText(product);
            return ['дет', 'сироп', 'суспенз', 'капли'].any(text.contains);
          }
          return true;
        }).toList();

    for (final keyword in need.productKeywords) {
      final matches =
          validProducts
              .where((product) => _productText(product).contains(keyword))
              .toList()
            ..sort((a, b) => b.stock.compareTo(a.stock));
      if (matches.isNotEmpty) return matches.first;
    }

    for (final keyword in need.categoryKeywords) {
      final matches =
          validProducts
              .where(
                (product) => product.category.toLowerCase().contains(keyword),
              )
              .toList()
            ..sort((a, b) => b.stock.compareTo(a.stock));
      if (matches.isNotEmpty) return matches.first;
    }

    return null;
  }

  static bool _isRestrictedProduct(B2BInventoryModel product) {
    final text = _productText(product);
    return [
      'антибиот',
      'сердце',
      'давление',
      'эндокрин',
      'диабет',
      'гормон',
    ].any(text.contains);
  }

  static String _productText(B2BInventoryModel product) {
    return [
      product.name,
      product.category,
      product.description ?? '',
      product.manufacturer ?? '',
      product.dosage ?? '',
      product.packageSize ?? '',
    ].join(' ').toLowerCase();
  }

  static String _summaryFor(AiKitPreferences preferences) {
    if (preferences.forChild) {
      return 'Базовый набор для ребенка с осторожным автоподбором: без взрослых таблеток и без рецептурных препаратов.';
    }
    if (preferences.forTravel) {
      return 'Набор для поездки: боль/температура, аллергия, ЖКТ, насморк и мелкие травмы.';
    }
    return 'Базовый домашний набор для частых бытовых ситуаций: температура, мелкие травмы, аллергия, ЖКТ и простуда.';
  }
}
