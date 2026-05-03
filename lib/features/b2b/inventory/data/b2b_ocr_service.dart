import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/b2b_ocr_result.dart';

class B2BOcrService {
  Future<B2BOcrResult> scanPackageImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await recognizer.processImage(inputImage);
      return parsePackageText(recognizedText.text);
    } finally {
      await recognizer.close();
    }
  }

  B2BOcrResult parsePackageText(String rawText) {
    final normalizedText = rawText.replaceAll('\r', '\n');
    final lines =
        normalizedText
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.length >= 2)
            .toList();

    final joined = lines.join(' ');
    final dosage = _extractDosage(joined);
    final packageSize = _extractPackageSize(joined);

    return B2BOcrResult(
      rawText: normalizedText.trim(),
      name: _extractName(lines),
      category: _extractCategory(joined),
      manufacturer: _extractManufacturer(lines, joined),
      dosage: dosage,
      packageSize: packageSize,
      barcode: _firstMatch(joined, RegExp(r'\b\d{8,14}\b')),
      batchNumber: _extractBatch(joined),
      expiryDate: _extractExpiryDate(joined),
    );
  }

  String? _extractName(List<String> lines) {
    final rejected = RegExp(
      r'(exp|expiry|годен|срок|lot|batch|серия|партия|barcode|штрих|состав|хранить|примен|табл|капс|mg|мг|\d{2}[./-]\d{2})',
      caseSensitive: false,
    );

    final candidates =
        lines
            .where((line) => !rejected.hasMatch(line))
            .where((line) => RegExp(r'[A-Za-zА-Яа-я]').hasMatch(line))
            .where(
              (line) =>
                  line
                      .replaceAll(
                        RegExp(r'[^A-Za-zА-Яа-яЁёӘәҒғҚқҢңӨөҰұҮүҺһІі]'),
                        '',
                      )
                      .length >=
                  4,
            )
            .toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final lengthCompare = b.length.compareTo(a.length);
      if (lengthCompare != 0) return lengthCompare;
      return lines.indexOf(a).compareTo(lines.indexOf(b));
    });

    return _cleanValue(candidates.first);
  }

  String? _extractCategory(String text) {
    final lower = text.toLowerCase();
    final rules = <String, List<String>>{
      'Обезболивающее': [
        'ibuprofen',
        'ибупрофен',
        'paracetamol',
        'парацетамол',
        'аспирин',
        'ketorol',
        'кеторол',
        'nurofen',
        'нурофен',
        'analgin',
        'анальгин',
        'aspirin',
        'аспирин',
      ],
      'Антибиотик': [
        'amoxicillin',
        'амоксициллин',
        'azithromycin',
        'азитромицин',
        'антибиотик',
      ],
      'Витамины': ['vitamin', 'витамин', 'аскорбин'],
      'Противовоспалительное': ['diclofenac', 'диклофенак', 'nsaid', 'нпвс'],
      'Антисептик': [
        'chlorhexidine',
        'хлоргексидин',
        'мирамистин',
        'antiseptic',
      ],
      'От аллергии': [
        'allergy',
        'аллерг',
        'suprastin',
        'супрастин',
        'loratadine',
        'лоратадин',
        'cetirizine',
        'цетиризин',
      ],
      'ЖКТ': [
        'smecta',
        'смекта',
        'mezim',
        'мезим',
        'линекс',
        'loperamide',
        'регидрон',
        'панкреатин',
      ],
      'От простуды': [
        'cold',
        'flu',
        'cough',
        'простуд',
        'грипп',
        'кашель',
        'theraflu',
        'терафлю',
      ],
      'Противовирусное': [
        'antiviral',
        'арбидол',
        'кагоцел',
        'ingavirin',
        'ингавирин',
      ],
    };

    for (final entry in rules.entries) {
      if (entry.value.any(lower.contains)) return entry.key;
    }
    return null;
  }

  String? _extractDosage(String text) {
    final strengthPatterns = [
      RegExp(
        r'\b\d+(?:[,.]\d+)?\s*(?:mg|мг|g|г|mcg|мкг|µg|ml|мл|iu|ме|ед\.?|%)\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\b\d+(?:[,.]\d+)?\s*(?:mg|мг)\s*/\s*\d+(?:[,.]\d+)?\s*(?:ml|мл)\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\b\d+(?:[,.]\d+)?\s*(?:мг|mg)\s*\+\s*\d+(?:[,.]\d+)?\s*(?:мг|mg)\b',
        caseSensitive: false,
      ),
    ];

    for (final pattern in strengthPatterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      return _cleanValue(match.group(0) ?? '').replaceAll(',', '.');
    }

    return null;
  }

  String? _extractPackageSize(String text) {
    final patterns = [
      RegExp(
        r'\b(?:№|n|no\.?|x)?\s?\d{1,4}\s*(?:табл\.?|таблет(?:ок|ки)?|капс\.?|капсул(?:а|ы)?|caps?|tablets?|амп\.?|ампул(?:а|ы)?|флак\.?|саше|пакет(?:ик)?|шт\.?|pcs?)\b',
        caseSensitive: false,
      ),
      RegExp(
        r'\b\d{1,4}\s*(?:x|х)\s*\d+(?:[,.]\d+)?\s*(?:mg|мг|ml|мл|g|г)\b',
        caseSensitive: false,
      ),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      return _cleanValue(match.group(0) ?? '').replaceAll(',', '.');
    }

    return null;
  }

  String? _extractManufacturer(List<String> lines, String joined) {
    final explicit = _firstGroup(
      joined,
      RegExp(
        r'(?:manufacturer|made by|производитель|изготовитель)[:\s]+([A-Za-zА-Яа-я0-9 .,"«»\-]{3,40})',
        caseSensitive: false,
      ),
    );
    if (explicit != null) return _cleanValue(explicit);

    final companyLine = lines.cast<String?>().firstWhere(
      (line) =>
          line != null &&
          RegExp(
            r'(pharma|фарм|labs?|laborator|gmbh|inc\.?|llc|тоо|ооо)',
            caseSensitive: false,
          ).hasMatch(line),
      orElse: () => null,
    );
    return companyLine == null ? null : _cleanValue(companyLine);
  }

  String? _extractBatch(String text) {
    final patterns = [
      RegExp(
        r'(?:lot|batch|серия|партия|сер\.?|серия №|партия №)[:\s#№]*([A-ZА-Я0-9\-]{3,24})',
        caseSensitive: false,
      ),
      RegExp(r'\b[A-ZА-Я]{1,4}\d{3,12}[A-ZА-Я0-9\-]*\b'),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      return _cleanValue(match.group(match.groupCount >= 1 ? 1 : 0) ?? '');
    }
    return null;
  }

  DateTime? _extractExpiryDate(String text) {
    final datePattern = RegExp(
      r'(?:exp\.?|expiry|expires|годен до|срок годности|срок до|исп\.? до|до)?\s*(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})',
      caseSensitive: false,
    );

    for (final match in datePattern.allMatches(text)) {
      final date = _buildDate(
        day: int.tryParse(match.group(1) ?? ''),
        month: int.tryParse(match.group(2) ?? ''),
        year: int.tryParse(match.group(3) ?? ''),
      );
      if (_isReasonableExpiry(date)) return date;
    }

    final monthPattern = RegExp(
      r'(?:exp\.?|expiry|expires|годен до|срок годности|срок до|исп\.? до|до)\s*(\d{1,2})[./-](\d{2,4})',
      caseSensitive: false,
    );

    for (final match in monthPattern.allMatches(text)) {
      final month = int.tryParse(match.group(1) ?? '');
      final year = int.tryParse(match.group(2) ?? '');
      final normalizedYear = _normalizeYear(year);
      if (month == null || normalizedYear == null || month < 1 || month > 12) {
        continue;
      }
      final date = DateTime(
        normalizedYear,
        month,
        _lastDayOfMonth(normalizedYear, month),
      );
      if (_isReasonableExpiry(date)) return date;
    }

    final yearFirstPattern = RegExp(
      r'(?:exp\.?|expiry|expires|годен до|срок годности|срок до|до)?\s*(20\d{2})[./-](\d{1,2})(?:[./-](\d{1,2}))?',
      caseSensitive: false,
    );

    for (final match in yearFirstPattern.allMatches(text)) {
      final year = int.tryParse(match.group(1) ?? '');
      final month = int.tryParse(match.group(2) ?? '');
      final day = int.tryParse(match.group(3) ?? '');
      if (year == null || month == null || month < 1 || month > 12) continue;
      final date = DateTime(year, month, day ?? _lastDayOfMonth(year, month));
      if (_isReasonableExpiry(date)) return date;
    }

    return null;
  }

  DateTime? _buildDate({int? day, int? month, int? year}) {
    final normalizedYear = _normalizeYear(year);
    if (day == null ||
        month == null ||
        normalizedYear == null ||
        day < 1 ||
        day > 31 ||
        month < 1 ||
        month > 12) {
      return null;
    }

    final lastDay = _lastDayOfMonth(normalizedYear, month);
    return DateTime(normalizedYear, month, day.clamp(1, lastDay));
  }

  int? _normalizeYear(int? year) {
    if (year == null) return null;
    if (year < 100) return 2000 + year;
    return year;
  }

  int _lastDayOfMonth(int year, int month) {
    return DateTime(year, month + 1, 0).day;
  }

  bool _isReasonableExpiry(DateTime? date) {
    if (date == null) return false;
    final now = DateTime.now();
    return date.isAfter(now.subtract(const Duration(days: 365))) &&
        date.isBefore(now.add(const Duration(days: 3650)));
  }

  String? _firstMatch(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    if (match == null) return null;
    return _cleanValue(match.group(0) ?? '');
  }

  String? _firstGroup(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    if (match == null || match.groupCount < 1) return null;
    return _cleanValue(match.group(1) ?? '');
  }

  String _cleanValue(String value) {
    return value
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'^[\s:;,.#№-]+|[\s:;,.#№-]+$'), '')
        .trim();
  }
}
