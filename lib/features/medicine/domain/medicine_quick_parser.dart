class MedicineQuickParser {
  static List<Map<String, dynamic>> parseBulk(String text) {
    return text
        .split(RegExp(r'\r?\n'))
        .map(parseLine)
        .where(
          (draft) => (draft['name']?.toString().trim().isNotEmpty ?? false),
        )
        .toList();
  }

  static Map<String, dynamic> parseLine(String input) {
    final original = _repairCommonOcrText(input.trim());
    if (original.isEmpty) return {};

    final hint = _findHint(original);
    final expiryDate = _extractExpiryDate(original);
    final dosage = _extractDosage(original) ?? hint?.dosage;
    final packageSize = _extractPackageSize(original);
    final quantity = _extractQuantity(original, packageSize);
    final form = _extractForm(original) ?? _extractForm(packageSize ?? '');
    final category = hint?.category ?? _mapCategory(original);
    final storagePlace = _extractStoragePlace(original);
    final manufacturer = _extractManufacturer(original) ?? hint?.manufacturer;
    final barcode = _extractBarcode(original);
    final batchNumber = _extractBatch(original);

    var name = original;
    for (final pattern in [
      RegExp(
        r'(?:годен\s+до|срок\s+до|до|exp(?:iry)?\.?)\s*[:\-]?\s*\d{1,2}[./-]\d{1,2}[./-]\d{2,4}',
        caseSensitive: false,
        unicode: true,
      ),
      RegExp(
        r'(?:годен\s+до|срок\s+до|до|exp(?:iry)?\.?)\s*[:\-]?\s*\d{1,2}[./-]\d{2,4}',
        caseSensitive: false,
        unicode: true,
      ),
      RegExp(
        r'\b\d+(?:[,.]\d+)?\s*(?:mg|мг|g|г|mcg|мкг|ml|мл|iu|ме|%)\b',
        caseSensitive: false,
        unicode: true,
      ),
      RegExp(
        r'(?:№\s?\d{1,4}|\b(?:n|no\.?|x)?\s?\d{1,4}\s*(?:табл?\.?|таблет(?:ок|ки|ка)?|капс?\.?|капсул(?:а|ы)?|caps?|tablets?|амп\.?|ампул(?:а|ы)?|флак\.?|саше|пакет(?:ик|а|ов)?|шт\.?|pcs?)\b)',
        caseSensitive: false,
        unicode: true,
      ),
      RegExp(
        r'(?:полка|ящик|шкаф|аптечка|холодильник|место)\s*[:\-]?\s*[\p{L}\d\s№#-]+$',
        caseSensitive: false,
        unicode: true,
      ),
      RegExp(
        r'(?:производитель|изготовитель|manufacturer|made by)\s*[:\-]?\s*[\p{L}\d\s.,«»"-]+',
        caseSensitive: false,
        unicode: true,
      ),
      RegExp(
        r'(?:серия|партия|lot|batch)\s*[:#№-]?\s*[A-ZА-Я0-9-]{3,24}',
        caseSensitive: false,
        unicode: true,
      ),
      RegExp(r'\b\d{8,14}\b', unicode: true),
    ]) {
      name = name.replaceAll(pattern, ' ');
    }

    name =
        name
            .replaceAll(RegExp(r'\s+'), ' ')
            .replaceAll(RegExp(r'^[,.;:\-\s]+|[,.;:\-\s]+$'), '')
            .trim();

    if (name.isEmpty) {
      name = original.split(RegExp(r'\s+')).take(3).join(' ');
    }
    if (hint != null && _looksTooGenericName(name)) {
      name = hint.name;
    }

    return {
      'name': name,
      'dosage': dosage,
      'quantity': quantity,
      'category': category,
      'expiryDate': expiryDate?.toIso8601String(),
      'packageSize': packageSize,
      'manufacturer': manufacturer,
      'barcode': barcode,
      'batchNumber': batchNumber,
      'form': form,
      'storagePlace': storagePlace,
      'unitLabel': _unitForForm(form),
      'source': 'Быстрый ввод SmartKit',
    }..removeWhere((_, value) => value == null || value == '');
  }

  static DateTime? _extractExpiryDate(String text) {
    final fullDate = RegExp(
      r'(?:годен\s+до|срок\s+до|до|exp(?:iry)?\.?)?\s*[:\-]?\s*(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    if (fullDate != null) {
      final day = int.tryParse(fullDate.group(1)!);
      final month = int.tryParse(fullDate.group(2)!);
      final year = _normalizeYear(fullDate.group(3)!);
      if (_validDateParts(year, month, day)) {
        return DateTime(year!, month!, day!);
      }
    }

    final monthYear = RegExp(
      r'(?:годен\s+до|срок\s+до|до|exp(?:iry)?\.?)\s*[:\-]?\s*(\d{1,2})[./-](\d{2,4})',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    if (monthYear != null) {
      final month = int.tryParse(monthYear.group(1)!);
      final year = _normalizeYear(monthYear.group(2)!);
      if (_validMonth(year, month)) {
        return DateTime(year!, month! + 1, 0);
      }
    }

    return null;
  }

  static String? _extractDosage(String text) {
    final match = RegExp(
      r'\b\d+(?:[,.]\d+)?\s*(?:mg|мг|g|г|mcg|мкг|ml|мл|iu|ме|%)\b',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    return match?.group(0)?.replaceAll(',', '.').trim();
  }

  static String? _extractPackageSize(String text) {
    final match = RegExp(
      r'(?:№\s?\d{1,4}|\b(?:n|no\.?|x)?\s?\d{1,4}\s*(?:табл?\.?|таблет(?:ок|ки|ка)?|капс?\.?|капсул(?:а|ы)?|caps?|tablets?|амп\.?|ампул(?:а|ы)?|флак\.?|саше|пакет(?:ик|а|ов)?|шт\.?|pcs?)\b)',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    return match?.group(0)?.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static int? _extractQuantity(String text, String? packageSize) {
    if (packageSize == null) return null;
    final match = RegExp(r'\d{1,4}').firstMatch(packageSize);
    return int.tryParse(match?.group(0) ?? '');
  }

  static String? _extractForm(String text) {
    final lower = text.toLowerCase();
    if (RegExp(r'табл|таблет').hasMatch(lower)) return 'Таблетки';
    if (RegExp(r'капс|caps').hasMatch(lower)) return 'Капсулы';
    if (RegExp(r'сироп|суспенз').hasMatch(lower)) return 'Сироп';
    if (RegExp(r'капли|drops').hasMatch(lower)) return 'Капли';
    if (RegExp(r'мазь|крем|гель').hasMatch(lower)) return 'Наружное средство';
    if (RegExp(r'ампул|инъекц|раствор').hasMatch(lower)) return 'Раствор';
    if (RegExp(r'спрей').hasMatch(lower)) return 'Спрей';
    if (RegExp(r'саше|пакет').hasMatch(lower)) return 'Саше';
    return null;
  }

  static String? _extractStoragePlace(String text) {
    final match = RegExp(
      r'(?:полка|ящик|шкаф|аптечка|холодильник|место)\s*[:\-]?\s*([\p{L}\d\s№#-]+)$',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    return match?.group(1)?.trim();
  }

  static String? _extractManufacturer(String text) {
    final match = RegExp(
      r'(?:производитель|изготовитель|manufacturer|made by)\s*[:\-]?\s*([\p{L}\d\s.,«»"-]{3,48})',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    return match?.group(1)?.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static String? _extractBarcode(String text) {
    final matches = RegExp(r'\b\d{8,14}\b').allMatches(text);
    for (final match in matches) {
      final value = match.group(0) ?? '';
      if (!_looksLikeDateDigits(value)) return value;
    }
    return null;
  }

  static String? _extractBatch(String text) {
    final explicit = RegExp(
      r'(?:серия|партия|lot|batch)\s*[:#№-]?\s*([A-ZА-Я0-9-]{3,24})',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    if (explicit != null) return explicit.group(1)?.trim();

    final compact = RegExp(
      r'\b[A-ZА-Я]{1,4}\d{3,12}[A-ZА-Я0-9-]*\b',
      caseSensitive: false,
      unicode: true,
    ).firstMatch(text);
    return compact?.group(0)?.trim();
  }

  static String? _unitForForm(String? form) {
    switch (form) {
      case 'Таблетки':
        return 'таб';
      case 'Капсулы':
        return 'капс';
      case 'Сироп':
      case 'Капли':
      case 'Раствор':
        return 'мл';
      case 'Саше':
        return 'саше';
      default:
        return null;
    }
  }

  static String _mapCategory(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('ибупрофен') ||
        lower.contains('парацетамол') ||
        lower.contains('анальгин') ||
        lower.contains('аспирин') ||
        lower.contains('нурофен') ||
        lower.contains('кеторол') ||
        lower.contains('цитрамон') ||
        lower.contains('боль')) {
      return 'Обезболивающее';
    }
    if (lower.contains('температур') || lower.contains('жар')) {
      return 'Жаропонижающее';
    }
    if (lower.contains('антибиот') || lower.contains('амокси')) {
      return 'Антибиотик';
    }
    if (lower.contains('витамин') ||
        lower.contains('d3') ||
        lower.contains('омега')) {
      return 'Витамины';
    }
    if (lower.contains('аллерг') ||
        lower.contains('лоратадин') ||
        lower.contains('цетиризин') ||
        lower.contains('цетрин') ||
        lower.contains('зодак') ||
        lower.contains('супрастин')) {
      return 'От аллергии';
    }
    if (lower.contains('смекта') ||
        lower.contains('мезим') ||
        lower.contains('регидрон') ||
        lower.contains('омепразол') ||
        lower.contains('лоперамид') ||
        lower.contains('энтеросгель') ||
        lower.contains('желуд') ||
        lower.contains('кишеч') ||
        lower.contains('уголь')) {
      return 'ЖКТ';
    }
    if (lower.contains('сорбент')) return 'Сорбенты';
    if (lower.contains('мирамистин') || lower.contains('хлоргексидин')) {
      return 'Антисептик';
    }
    if (lower.contains('грипп') ||
        lower.contains('простуд') ||
        lower.contains('кашель') ||
        lower.contains('терафлю')) {
      return 'От простуды';
    }
    if (lower.contains('арбидол') ||
        lower.contains('кагоцел') ||
        lower.contains('ингавирин')) {
      return 'Противовирусное';
    }
    return 'Другое';
  }

  static int? _normalizeYear(String yearText) {
    final raw = int.tryParse(yearText);
    if (raw == null) return null;
    return raw < 100 ? 2000 + raw : raw;
  }

  static bool _validDateParts(int? year, int? month, int? day) {
    if (!_validMonth(year, month) || day == null || day < 1 || day > 31) {
      return false;
    }
    final date = DateTime(year!, month!, day);
    return date.year == year && date.month == month && date.day == day;
  }

  static bool _validMonth(int? year, int? month) {
    return year != null &&
        year >= 2020 &&
        year <= 2100 &&
        month != null &&
        month >= 1 &&
        month <= 12;
  }

  static String _repairCommonOcrText(String text) {
    return text
        .replaceAll('|', 'I')
        .replaceAll(RegExp(r'\bEXPIRY\b', caseSensitive: false), 'EXP')
        .replaceAll(RegExp(r'\bHYPOFEH\b', caseSensitive: false), 'НУРОФЕН')
        .replaceAll(RegExp(r'\bIBYПPOFEH\b', caseSensitive: false), 'ИБУПРОФЕН')
        .replaceAll(RegExp(r'\bTAБЛETKИ\b', caseSensitive: false), 'ТАБЛЕТКИ')
        .replaceAll(RegExp(r'\bЦETPИH\b', caseSensitive: false), 'ЦЕТРИН')
        .replaceAllMapped(
          RegExp(r'(\d)\s*(?:mr|mг|мr|mt)\b', caseSensitive: false),
          (match) => '${match.group(1)} мг',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static bool _looksLikeDateDigits(String value) {
    if (value.length >= 8) return false;
    final number = int.tryParse(value);
    return number != null && number >= 10100 && number <= 311299;
  }

  static bool _looksTooGenericName(String value) {
    final lower = value.toLowerCase();
    return value.length < 4 ||
        lower.contains('таблет') ||
        lower.contains('капсул') ||
        lower.contains('срок') ||
        lower.contains('годен') ||
        RegExp(r'^\d').hasMatch(value);
  }

  static _QuickMedicineHint? _findHint(String text) {
    final normalized = text.toLowerCase().replaceAll('ё', 'е');
    for (final hint in _hints) {
      if (hint.aliases.any((alias) => normalized.contains(alias))) {
        return hint;
      }
    }
    return null;
  }

  static const List<_QuickMedicineHint> _hints = [
    _QuickMedicineHint(
      ['нурофен', 'ибупрофен', 'nurofen', 'ibuprofen'],
      'Нурофен',
      'Обезболивающее',
      dosage: '400 мг',
      manufacturer: 'Reckitt Benckiser',
    ),
    _QuickMedicineHint(
      ['парацетамол', 'paracetamol', 'acetaminophen'],
      'Парацетамол',
      'Обезболивающее',
      dosage: '500 мг',
    ),
    _QuickMedicineHint(
      ['цетрин', 'цетиризин', 'cetrin', 'cetirizine'],
      'Цетрин',
      'От аллергии',
      dosage: '10 мг',
      manufacturer: 'Dr. Reddy\'s',
    ),
    _QuickMedicineHint(
      ['лоратадин', 'loratadine'],
      'Лоратадин',
      'От аллергии',
      dosage: '10 мг',
    ),
    _QuickMedicineHint(
      ['супрастин', 'suprastin'],
      'Супрастин',
      'От аллергии',
      manufacturer: 'Egis',
    ),
    _QuickMedicineHint(
      ['смекта', 'диосмектит', 'smecta', 'diosmectite'],
      'Смекта',
      'ЖКТ',
      manufacturer: 'Ipsen',
    ),
    _QuickMedicineHint(
      ['регидрон', 'rehydron'],
      'Регидрон',
      'ЖКТ',
    ),
    _QuickMedicineHint(
      ['омепразол', 'omeprazole'],
      'Омепразол',
      'ЖКТ',
      dosage: '20 мг',
    ),
    _QuickMedicineHint(
      ['мирамистин', 'miramistin'],
      'Мирамистин',
      'Антисептик',
      manufacturer: 'Инфамед',
    ),
    _QuickMedicineHint(
      ['хлоргексидин', 'chlorhexidine'],
      'Хлоргексидин',
      'Антисептик',
    ),
    _QuickMedicineHint(
      ['амброксол', 'амбробене', 'ambroxol', 'ambrobene'],
      'Амброксол',
      'От простуды',
      dosage: '30 мг',
    ),
    _QuickMedicineHint(
      ['аквамарис', 'aqua maris', 'aquamaris'],
      'Аква Марис',
      'От простуды',
    ),
  ];
}

class _QuickMedicineHint {
  final List<String> aliases;
  final String name;
  final String category;
  final String? dosage;
  final String? manufacturer;

  const _QuickMedicineHint(
    this.aliases,
    this.name,
    this.category, {
    this.dosage,
    this.manufacturer,
  });
}
