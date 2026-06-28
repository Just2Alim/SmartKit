import 'dart:async';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/api/smartkit_api_client.dart';
import '../../../../core/services/barcode_service.dart';
import '../models/b2b_ocr_result.dart';

class B2BOcrService {
  static const Duration _lookupTimeout = Duration(milliseconds: 1400);
  static const Duration _serverParserTimeout = Duration(milliseconds: 3600);

  Future<B2BOcrResult> scanPackageImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);

    try {
      final recognizedText = await recognizer.processImage(inputImage);
      final parsed = parsePackageText(recognizedText.text);
      final enriched = await enrichWithBarcodeLookup(parsed);
      return _enrichWithServerParser(recognizedText.text, enriched);
    } finally {
      await recognizer.close();
    }
  }

  Future<B2BOcrResult> _enrichWithServerParser(
    String rawText,
    B2BOcrResult localResult,
  ) async {
    final accessToken =
        Supabase.instance.client.auth.currentSession?.accessToken;
    if (accessToken == null || rawText.trim().length < 3) return localResult;

    try {
      final response = await SmartKitApiClient().postJson(
        'medicine-ocr',
        accessToken: accessToken,
        body: {
          'rawText': rawText,
          'barcode': localResult.barcode,
          'localDraft': localResult.toMap(),
        },
      ).timeout(_serverParserTimeout);

      final rawResult = response['result'];
      if (rawResult is! Map) return localResult;
      final serverResult = B2BOcrResult.fromMap(
        Map<String, dynamic>.from(rawResult),
      );
      return _mergeServerResult(localResult, serverResult);
    } catch (_) {
      return localResult;
    }
  }

  B2BOcrResult _mergeServerResult(
    B2BOcrResult local,
    B2BOcrResult server,
  ) {
    final confidence =
        server.confidence > local.confidence
            ? server.confidence
            : local.confidence;
    return local.copyWith(
      rawText: _firstNonEmpty([local.rawText, server.rawText]) ?? local.rawText,
      name: _firstNonEmpty([server.name, local.name]),
      category: _firstNonEmpty([server.category, local.category]),
      manufacturer: _firstNonEmpty([server.manufacturer, local.manufacturer]),
      description: _firstNonEmpty([server.description, local.description]),
      dosage: _firstNonEmpty([server.dosage, local.dosage]),
      packageSize: _firstNonEmpty([server.packageSize, local.packageSize]),
      barcode: _firstNonEmpty([server.barcode, local.barcode]),
      batchNumber: _firstNonEmpty([server.batchNumber, local.batchNumber]),
      form: _firstNonEmpty([server.form, local.form]),
      unitLabel: _firstNonEmpty([server.unitLabel, local.unitLabel]),
      storagePlace: _firstNonEmpty([server.storagePlace, local.storagePlace]),
      expiryDate: server.expiryDate ?? local.expiryDate,
      source: _combineSources(local.source, server.source),
      lookupMessage:
          _firstNonEmpty([server.lookupMessage, local.lookupMessage]) ??
          _lookupMessage(confidence),
      confidence: confidence,
      needsReview: confidence < 0.78 || (server.name ?? local.name) == null,
      suggestedStock: server.suggestedStock ?? local.suggestedStock ?? 1,
      suggestedMinStock:
          server.suggestedMinStock ?? local.suggestedMinStock,
      suggestedPrice: server.suggestedPrice ?? local.suggestedPrice,
    );
  }

  Future<B2BOcrResult> enrichWithBarcodeLookup(B2BOcrResult result) async {
    final barcode = result.barcode?.trim();
    if (barcode == null || barcode.isEmpty) return result;

    try {
      final lookup = await BarcodeService.lookupBarcode(
        barcode,
        allowSlowNetwork: false,
      ).timeout(_lookupTimeout);
      if (lookup == null) return result;
      return _mergeLookup(result, lookup);
    } on TimeoutException {
      return result.copyWith(
        lookupMessage:
            'Упаковка распознана. Справочник не успел ответить, но поля уже можно проверить и сохранить.',
      );
    } catch (_) {
      return result;
    }
  }

  B2BOcrResult parsePackageText(String rawText) {
    final normalizedText = _normalizeRawText(rawText);
    final repairedText = _repairCommonOcrText(normalizedText);
    final parsingText =
        repairedText == normalizedText
            ? normalizedText
            : '$normalizedText\n$repairedText';
    final lines =
        parsingText
            .split('\n')
            .map((line) => line.trim())
            .where((line) => line.length >= 2)
            .toSet()
            .toList();

    final joined = lines.join(' ');
    final hint = _findMedicineHint(joined);
    final name = _extractName(lines, joined, hint);
    final category = _extractCategory(joined) ?? hint?.category;
    final manufacturer =
        _extractManufacturer(lines, joined) ?? hint?.manufacturer;
    final dosage = _extractDosage(joined) ?? hint?.dosage;
    final packageSize = _extractPackageSize(joined);
    final form = _extractForm(joined, packageSize);
    final unitLabel = _suggestUnitLabel(form, packageSize);
    final storagePlace = _suggestStoragePlace(joined);
    final barcode = _extractBarcode(joined);
    final batchNumber = _extractBatch(joined);
    final expiryDate = _extractExpiryDate(joined);
    final suggestedPrice = _extractPrice(joined);
    final description = _buildDescription(
      name: name,
      category: category,
      dosage: dosage,
      packageSize: packageSize,
      manufacturer: manufacturer,
      form: form,
    );
    final confidence = _calculateConfidence(
      hasKnownHint: hint != null,
      name: name,
      category: category,
      manufacturer: manufacturer,
      dosage: dosage,
      packageSize: packageSize,
      barcode: barcode,
      batchNumber: batchNumber,
      expiryDate: expiryDate,
    );

    return B2BOcrResult(
      rawText: normalizedText.trim(),
      name: name,
      category: category,
      manufacturer: manufacturer,
      description: description,
      dosage: dosage,
      packageSize: packageSize,
      barcode: barcode,
      batchNumber: batchNumber,
      form: form,
      unitLabel: unitLabel,
      storagePlace: storagePlace,
      expiryDate: expiryDate,
      source:
          hint == null
              ? 'OCR упаковки + RU/KZ/EN parser'
              : 'OCR упаковки + RU/KZ/EN parser + локальные подсказки',
      lookupMessage: _lookupMessage(confidence),
      confidence: confidence,
      needsReview: confidence < 0.75 || name == null,
      suggestedStock: name == null ? null : 1,
      suggestedMinStock: _suggestMinStock(category),
      suggestedPrice: suggestedPrice,
    );
  }

  B2BOcrResult _mergeLookup(B2BOcrResult ocr, Map<String, dynamic> lookup) {
    final mergedName = _firstNonEmpty([ocr.name, lookup['name']]);
    final mergedCategory = _firstNonEmpty([ocr.category, lookup['category']]);
    final mergedManufacturer = _firstNonEmpty([
      ocr.manufacturer,
      lookup['manufacturer'],
      lookup['brand'],
    ]);
    final mergedDosage = _firstNonEmpty([ocr.dosage, lookup['dosage']]);
    final mergedPackageSize = _firstNonEmpty([
      ocr.packageSize,
      lookup['packageSize'],
      lookup['package_size'],
    ]);
    final mergedForm = _firstNonEmpty([ocr.form, lookup['form']]);
    final mergedUnitLabel = _firstNonEmpty([
      ocr.unitLabel,
      lookup['unitLabel'],
    ]);
    final mergedStoragePlace = _firstNonEmpty([
      ocr.storagePlace,
      lookup['storagePlace'],
    ]);
    final mergedDescription = _firstNonEmpty([
      ocr.description,
      lookup['description'],
      _buildDescription(
        name: mergedName,
        category: mergedCategory,
        dosage: mergedDosage,
        packageSize: mergedPackageSize,
        manufacturer: mergedManufacturer,
        form: mergedForm,
      ),
    ]);
    final mergedBatch = _firstNonEmpty([
      ocr.batchNumber,
      lookup['batchNumber'],
      lookup['batch_number'],
    ]);
    final mergedExpiry = ocr.expiryDate ?? _parseDate(lookup['expiryDate']);
    final lookupConfidence = (lookup['confidence'] as num?)?.toDouble() ?? 0.0;
    final confidence = _calculateConfidence(
      hasKnownHint: lookupConfidence >= 0.65,
      name: mergedName,
      category: mergedCategory,
      manufacturer: mergedManufacturer,
      dosage: mergedDosage,
      packageSize: mergedPackageSize,
      barcode: ocr.barcode ?? lookup['barcode']?.toString(),
      batchNumber: mergedBatch,
      expiryDate: mergedExpiry,
    );
    final bestConfidence =
        confidence > lookupConfidence ? confidence : lookupConfidence;

    return ocr.copyWith(
      name: mergedName,
      category: mergedCategory,
      manufacturer: mergedManufacturer,
      description: mergedDescription,
      dosage: mergedDosage,
      packageSize: mergedPackageSize,
      barcode: _firstNonEmpty([ocr.barcode, lookup['barcode']]),
      batchNumber: mergedBatch,
      form: mergedForm,
      unitLabel: mergedUnitLabel,
      storagePlace: mergedStoragePlace,
      expiryDate: mergedExpiry,
      source: _combineSources(ocr.source, lookup['source']),
      lookupMessage:
          _firstNonEmpty([lookup['lookupMessage'], ocr.lookupMessage]) ??
          _lookupMessage(bestConfidence),
      confidence: bestConfidence.clamp(0.0, 0.98),
      needsReview: bestConfidence < 0.75 || mergedName == null,
      suggestedStock: ocr.suggestedStock ?? 1,
      suggestedMinStock:
          ocr.suggestedMinStock ?? _suggestMinStock(mergedCategory),
      suggestedPrice:
          ocr.suggestedPrice ??
          _intFrom(lookup['suggestedPrice']) ??
          _intFrom(lookup['price']),
    );
  }

  String _normalizeRawText(String rawText) {
    return rawText
        .replaceAll('\r', '\n')
        .replaceAll(RegExp(r'[|]'), 'I')
        .replaceAll(RegExp(r'\bEXPIRY\b', caseSensitive: false), 'EXP')
        .replaceAll(RegExp(r'\bСЕР[,.]?\b', caseSensitive: false), 'Серия')
        .replaceAll(RegExp(r'\bLOT[,.]?\b', caseSensitive: false), 'LOT')
        .replaceAll(RegExp(r'[ \t]+'), ' ')
        .trim();
  }

  String _repairCommonOcrText(String rawText) {
    final repairedLines = rawText.split('\n').map((line) {
      var value = line;
      final replacements = <RegExp, String>{
        RegExp(r'\bHYPOFEH\b', caseSensitive: false): 'НУРОФЕН',
        RegExp(r'\bHYPOФEH\b', caseSensitive: false): 'НУРОФЕН',
        RegExp(r'\bФOPTE\b', caseSensitive: false): 'ФОРТЕ',
        RegExp(r'\bIBYПPOFEH\b', caseSensitive: false): 'ИБУПРОФЕН',
        RegExp(r'\bIБУПРОФЕН\b', caseSensitive: false): 'ИБУПРОФЕН',
        RegExp(r'\bTAБЛETKИ\b', caseSensitive: false): 'ТАБЛЕТКИ',
        RegExp(r'\bTAБЛЕТКИ\b', caseSensitive: false): 'ТАБЛЕТКИ',
        RegExp(r'\bЦETPИH\b', caseSensitive: false): 'ЦЕТРИН',
        RegExp(r'\bЦETИPИЗИH\b', caseSensitive: false): 'ЦЕТИРИЗИН',
        RegExp(r'\bГOДEH\b', caseSensitive: false): 'ГОДЕН',
        RegExp(r'\bДO\b', caseSensitive: false): 'ДО',
        RegExp(r'\bCEPИЯ\b', caseSensitive: false): 'СЕРИЯ',
        RegExp(r'\bCEР[,.]?\b', caseSensitive: false): 'СЕРИЯ',
        RegExp(r'\bPECKITT\b', caseSensitive: false): 'RECKITT',
      };

      for (final entry in replacements.entries) {
        value = value.replaceAll(entry.key, entry.value);
      }
      value = value.replaceAllMapped(
        RegExp(r'\b(?:N|No|NO)\s?(\d{1,4})\b', caseSensitive: false),
        (match) => '№${match.group(1)}',
      );
      value = value.replaceAllMapped(
        RegExp(r'(\d)\s*(?:mr|mг|мr|мт|mt)\b', caseSensitive: false),
        (match) => '${match.group(1)} мг',
      );
      return value;
    });

    return repairedLines.join('\n');
  }

  String? _extractForm(String text, String? packageSize) {
    final lower = '$text ${packageSize ?? ''}'.toLowerCase();
    final searchable = '$lower ${_cyrillicizeLookalikes(lower).toLowerCase()}';
    final rules = <String, List<String>>{
      'Таблетки': ['таблет', 'табл', 'tablets', 'tablet'],
      'Капсулы': ['капсул', 'capsule', 'caps'],
      'Сироп': ['сироп', 'syrup'],
      'Капли': ['капли', 'drops'],
      'Спрей': ['спрей', 'spray'],
      'Раствор': ['раствор', 'solution'],
      'Суспензия': ['суспенз', 'suspension'],
      'Мазь': ['мазь', 'ointment'],
      'Крем': ['крем', 'cream'],
      'Гель': ['гель', 'gel'],
      'Ампулы': ['ампул', 'ampoule', 'ampule'],
      'Порошок': ['порош', 'powder', 'саше', 'sachet'],
    };

    for (final entry in rules.entries) {
      if (entry.value.any(searchable.contains)) return entry.key;
    }
    return null;
  }

  String _suggestUnitLabel(String? form, String? packageSize) {
    final lower = '${form ?? ''} ${packageSize ?? ''}'.toLowerCase();
    if (lower.contains('сироп') ||
        lower.contains('раствор') ||
        lower.contains('суспенз') ||
        lower.contains('капли') ||
        lower.contains('спрей')) {
      return 'фл';
    }
    if (lower.contains('ампул')) return 'амп';
    if (lower.contains('саше') || lower.contains('порош')) return 'саше';
    return 'шт';
  }

  String _suggestStoragePlace(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('2-8') ||
        lower.contains('2 °c') ||
        lower.contains('2°c') ||
        lower.contains('холодиль') ||
        lower.contains('refriger')) {
      return 'Холодильник';
    }
    if (lower.contains('сух') || lower.contains('dry')) {
      return 'Сухое место';
    }
    if (lower.contains('темн') ||
        lower.contains('свет') ||
        lower.contains('light')) {
      return 'Защищенное от света место';
    }
    return 'Домашняя аптечка';
  }

  String? _buildDescription({
    required String? name,
    required String? category,
    required String? dosage,
    required String? packageSize,
    required String? manufacturer,
    required String? form,
  }) {
    if (name == null) return null;
    final details = [
      if (form != null) form.toLowerCase(),
      if (dosage != null) dosage,
      if (packageSize != null) packageSize,
      if (manufacturer != null) manufacturer,
    ].join(' • ');
    final suffix = details.isEmpty ? '' : ': $details';
    return '$name${category == null ? '' : ' ($category)'}$suffix.';
  }

  String? _extractName(List<String> lines, String joined, _MedicineHint? hint) {
    if (hint != null) {
      final hasCyrillic = RegExp(r'[А-Яа-яЁё]').hasMatch(joined);
      return hasCyrillic ? hint.name : hint.latinName ?? hint.name;
    }

    final rejected = RegExp(
      r'(exp|expiry|годен|срок|lot|batch|серия|партия|barcode|штрих|состав|хранить|примен|табл|таблет|капс|капсул|mg|мг|ml|мл|№|n\s?\d|\d{2}[./-]\d{2})',
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
            .where((line) => !_looksLikeCompany(line))
            .toList();

    if (candidates.isEmpty) return null;

    candidates.sort((a, b) {
      final aScore = _nameScore(a);
      final bScore = _nameScore(b);
      final scoreCompare = bScore.compareTo(aScore);
      if (scoreCompare != 0) return scoreCompare;
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
        'citramon',
        'цитрамон',
        'pentalgin',
        'пенталгин',
      ],
      'Антибиотик': [
        'amoxicillin',
        'амоксициллин',
        'azithromycin',
        'азитромицин',
        'антибиотик',
      ],
      'Витамины': ['vitamin', 'витамин', 'аскорбин'],
      'Противовоспалительное': [
        'diclofenac',
        'диклофенак',
        'voltaren',
        'вольтарен',
        'nsaid',
        'нпвс',
        'levomekol',
        'левомеколь',
      ],
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
        'cetrin',
        'цетрин',
        'zodak',
        'зодак',
        'zirtec',
        'zyrtec',
        'зиртек',
      ],
      'ЖКТ': [
        'smecta',
        'смекта',
        'mezim',
        'мезим',
        'линекс',
        'linex',
        'loperamide',
        'регидрон',
        'rehydron',
        'omeprazole',
        'омепразол',
        'панкреатин',
        'но-шпа',
        'nospanum',
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
        'ambrobene',
        'амбробене',
        'ambroxol',
        'амброксол',
        'lazolvan',
        'лазолван',
        'aquamaris',
        'аквамарис',
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
      return _formatDosage(_cleanValue(match.group(0) ?? ''));
    }

    return null;
  }

  String? _extractPackageSize(String text) {
    final patterns = [
      RegExp(
        r'(?:таблет(?:ки|ок)?|капсул(?:ы|а)?|caps?|tablets?).{0,32}(?:№|n)\s?\d{1,4}',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:№\s?\d{1,4}|\b(?:n|no\.?|x)?\s?\d{1,4}\s*(?:табл\.?|таблет(?:ок|ки)?|капс\.?|капсул(?:а|ы)?|caps?|tablets?|амп\.?|ампул(?:а|ы)?|флак\.?|саше|пакет(?:ик)?|шт\.?|pcs?)\b)',
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
        r'(?:manufacturer|made by|производитель|изготовитель)[:\s]+([A-Za-zА-Яа-я0-9 .,"«»\-]{3,48})',
        caseSensitive: false,
      ),
    );
    if (explicit != null) return _cleanValue(explicit);

    final companyLine = lines.cast<String?>().firstWhere(
      (line) => line != null && _looksLikeCompany(line),
      orElse: () => null,
    );
    return companyLine == null ? null : _cleanValue(companyLine);
  }

  String? _extractBarcode(String text) {
    final matches = RegExp(r'\b\d{8,14}\b').allMatches(text);
    for (final match in matches) {
      final value = match.group(0) ?? '';
      if (!_looksLikeDateOrLot(value)) return _cleanValue(value);
    }
    return null;
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

  int? _extractPrice(String text) {
    final patterns = [
      RegExp(
        r'(?:цена|price|бағасы)\s*[:\-]?\s*(\d{2,7})\s*(?:₸|тг|тенге|kzt)?',
        caseSensitive: false,
      ),
      RegExp(r'\b(\d{2,7})\s*(?:₸|тг|тенге|kzt)\b', caseSensitive: false),
    ];

    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match == null) continue;
      final value = int.tryParse(match.group(1) ?? '');
      if (value != null && value >= 10) return value;
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

    final bareMonthYearPattern = RegExp(r'\b(0?[1-9]|1[0-2])[./-](\d{2,4})\b');
    for (final match in bareMonthYearPattern.allMatches(text)) {
      final month = int.tryParse(match.group(1) ?? '');
      final year = _normalizeYear(int.tryParse(match.group(2) ?? ''));
      if (month == null || year == null || month < 1 || month > 12) continue;
      final date = DateTime(year, month, _lastDayOfMonth(year, month));
      if (_isReasonableExpiry(date)) return date;
    }

    return null;
  }

  _MedicineHint? _findMedicineHint(String text) {
    final variants = {
      _normalizeForSearch(text),
      _normalizeForSearch(_repairCommonOcrText(text)),
      _normalizeForSearch(_cyrillicizeLookalikes(text)),
      _normalizeForSearch(_cyrillicizeLookalikes(_repairCommonOcrText(text))),
    };
    for (final hint in _medicineHints) {
      final normalizedAliases = hint.aliases.map(_normalizeForSearch);
      if (normalizedAliases.any((alias) {
        return variants.any((variant) => variant.contains(alias));
      })) {
        return hint;
      }
    }
    return null;
  }

  double _calculateConfidence({
    required bool hasKnownHint,
    required String? name,
    required String? category,
    required String? manufacturer,
    required String? dosage,
    required String? packageSize,
    required String? barcode,
    required String? batchNumber,
    required DateTime? expiryDate,
  }) {
    var score = hasKnownHint ? 0.42 : 0.18;
    if (name != null) score += 0.16;
    if (category != null) score += 0.08;
    if (manufacturer != null) score += 0.08;
    if (dosage != null) score += 0.12;
    if (packageSize != null) score += 0.08;
    if (barcode != null) score += 0.12;
    if (batchNumber != null) score += 0.06;
    if (expiryDate != null) score += 0.08;
    return score.clamp(0.0, 0.98);
  }

  int? _suggestMinStock(String? category) {
    switch (category) {
      case 'Обезболивающее':
      case 'Жаропонижающее':
      case 'От простуды':
        return 8;
      case 'Антибиотик':
      case 'Сердце':
        return 3;
      case 'Антисептик':
      case 'ЖКТ':
      case 'От аллергии':
      case 'Аллергия':
        return 5;
      case 'Витамины':
        return 6;
      default:
        return category == null ? null : 4;
    }
  }

  String _lookupMessage(double confidence) {
    if (confidence >= 0.85) {
      return 'Поля заполнены автоматически. Проверьте цену и фактический остаток перед сохранением.';
    }
    if (confidence >= 0.65) {
      return 'SmartKit распознал основные поля. Проверьте название, срок и партию.';
    }
    return 'Текст распознан частично. Лучше сделать фото ближе или заполнить недостающие поля вручную.';
  }

  int _nameScore(String value) {
    final lower = value.toLowerCase();
    var score = value.length;
    if (RegExp(r'\d').hasMatch(value)) score -= 8;
    if (lower.contains('таб') || lower.contains('капс')) score -= 8;
    if (lower.contains('forte') || lower.contains('форте')) score += 8;
    if (_looksLikeCompany(value)) score -= 18;
    return score;
  }

  bool _looksLikeCompany(String value) {
    return RegExp(
      r'(pharma|фарм|labs?|laborator|gmbh|inc\.?|llc|тоо|ооо|bayer|reckitt|benckiser|sanofi|sandoz|novartis|ipsen|egis|ozon|озон|нижфарм|валента|фармстандарт|berlin-chemie|dr\.?\s*reddy)',
      caseSensitive: false,
    ).hasMatch(value);
  }

  bool _looksLikeDateOrLot(String value) {
    if (value.length >= 8) return false;
    final number = int.tryParse(value);
    if (number == null) return false;
    return number >= 10100 && number <= 311299;
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

  String _formatDosage(String value) {
    return _cleanValue(value)
        .replaceAll(',', '.')
        .replaceAllMapped(
          RegExp(
            r'(\d)(mg|мг|g|г|mcg|мкг|µg|ml|мл|iu|ме|ед|%)\b',
            caseSensitive: false,
          ),
          (match) => '${match.group(1)} ${match.group(2)}',
        );
  }

  String _normalizeForSearch(String value) {
    return value
        .toLowerCase()
        .replaceAll('ё', 'е')
        .replaceAll(RegExp(r'[^a-zа-яәғқңөұүһі0-9]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _cyrillicizeLookalikes(String value) {
    const replacements = {
      'A': 'А',
      'a': 'а',
      'B': 'В',
      'C': 'С',
      'c': 'с',
      'E': 'Е',
      'e': 'е',
      'F': 'Ф',
      'f': 'ф',
      'H': 'Н',
      'h': 'н',
      'K': 'К',
      'k': 'к',
      'M': 'М',
      'm': 'м',
      'N': 'Н',
      'n': 'н',
      'O': 'О',
      'o': 'о',
      'P': 'Р',
      'p': 'р',
      'T': 'Т',
      't': 'т',
      'X': 'Х',
      'x': 'х',
      'Y': 'У',
      'y': 'у',
      'I': 'И',
      'i': 'и',
    };
    final buffer = StringBuffer();
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      buffer.write(replacements[char] ?? char);
    }
    return buffer.toString();
  }

  String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = value?.toString().trim();
      if (text != null && text.isNotEmpty) return text;
    }
    return null;
  }

  int? _intFrom(dynamic value) {
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString().replaceAll(RegExp(r'[^\d]'), ''));
  }

  String _combineSources(dynamic first, dynamic second) {
    final values =
        [first, second]
            .map((value) => value?.toString().trim())
            .whereType<String>()
            .where((value) => value.isNotEmpty)
            .expand((value) => value.split('+'))
            .map((value) => value.trim())
            .where((value) => value.isNotEmpty)
            .toSet();
    return values.join(' + ');
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  static const List<_MedicineHint> _medicineHints = [
    _MedicineHint(
      aliases: ['нурофен', 'nurofen', 'ибупрофен', 'ibuprofen'],
      name: 'Нурофен Форте',
      latinName: 'Nurofen Forte',
      category: 'Обезболивающее',
      manufacturer: 'Reckitt Benckiser',
      dosage: '400 мг',
      minStock: 8,
    ),
    _MedicineHint(
      aliases: ['парацетамол', 'paracetamol', 'acetaminophen'],
      name: 'Парацетамол',
      latinName: 'Paracetamol',
      category: 'Обезболивающее',
      dosage: '500 мг',
      minStock: 8,
    ),
    _MedicineHint(
      aliases: ['аспирин', 'aspirin', 'ацетилсалицил'],
      name: 'Аспирин',
      latinName: 'Aspirin',
      category: 'Обезболивающее',
      manufacturer: 'Bayer',
      minStock: 6,
    ),
    _MedicineHint(
      aliases: ['супрастин', 'suprastin', 'хлоропирамин'],
      name: 'Супрастин',
      latinName: 'Suprastin',
      category: 'От аллергии',
      manufacturer: 'Egis',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['цетрин', 'cetrin', 'цетиризин', 'cetirizine'],
      name: 'Цетрин',
      latinName: 'Cetrin',
      category: 'От аллергии',
      manufacturer: 'Dr. Reddy\'s',
      dosage: '10 мг',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['лоратадин', 'loratadine'],
      name: 'Лоратадин',
      latinName: 'Loratadine',
      category: 'От аллергии',
      dosage: '10 мг',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['смекта', 'smecta', 'diosmectite', 'диосмектит'],
      name: 'Смекта',
      latinName: 'Smecta',
      category: 'ЖКТ',
      manufacturer: 'Ipsen',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['мезим', 'mezim', 'pancreatin', 'панкреатин'],
      name: 'Мезим Форте',
      latinName: 'Mezim Forte',
      category: 'ЖКТ',
      manufacturer: 'Berlin-Chemie',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['линекс', 'linex'],
      name: 'Линекс',
      latinName: 'Linex',
      category: 'ЖКТ',
      manufacturer: 'Sandoz',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['регидрон', 'rehydron', 'oral rehydration'],
      name: 'Регидрон',
      latinName: 'Rehydron',
      category: 'ЖКТ',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['омепразол', 'omeprazole'],
      name: 'Омепразол',
      latinName: 'Omeprazole',
      category: 'ЖКТ',
      dosage: '20 мг',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['терафлю', 'theraflu'],
      name: 'Терафлю',
      latinName: 'Theraflu',
      category: 'От простуды',
      minStock: 8,
    ),
    _MedicineHint(
      aliases: ['амбробене', 'ambrobene', 'амброксол', 'ambroxol'],
      name: 'Амбробене',
      latinName: 'Ambrobene',
      category: 'От простуды',
      dosage: '30 мг',
      minStock: 6,
    ),
    _MedicineHint(
      aliases: ['аквамарис', 'aqua maris', 'aquamaris'],
      name: 'Аква Марис',
      latinName: 'Aqua Maris',
      category: 'От простуды',
      minStock: 6,
    ),
    _MedicineHint(
      aliases: ['мирамистин', 'miramistin'],
      name: 'Мирамистин',
      latinName: 'Miramistin',
      category: 'Антисептик',
      manufacturer: 'Инфамед',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['хлоргексидин', 'chlorhexidine'],
      name: 'Хлоргексидин',
      latinName: 'Chlorhexidine',
      category: 'Антисептик',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['ингавирин', 'ingavirin'],
      name: 'Ингавирин',
      latinName: 'Ingavirin',
      category: 'Противовирусное',
      manufacturer: 'Валента Фарм',
      minStock: 4,
    ),
    _MedicineHint(
      aliases: ['кагоцел', 'kagocel'],
      name: 'Кагоцел',
      latinName: 'Kagocel',
      category: 'Противовирусное',
      minStock: 4,
    ),
    _MedicineHint(
      aliases: ['но шпа', 'но-шпа', 'nospanum', 'drotaverine', 'дротаверин'],
      name: 'Но-шпа',
      latinName: 'No-Spa',
      category: 'ЖКТ',
      manufacturer: 'Sanofi',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['кеторол', 'ketorol', 'ketorolac', 'кеторолак'],
      name: 'Кеторол',
      latinName: 'Ketorol',
      category: 'Обезболивающее',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['диклофенак', 'diclofenac', 'вольтарен', 'voltaren'],
      name: 'Диклофенак',
      latinName: 'Diclofenac',
      category: 'Противовоспалительное',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['энтеросгель', 'enterosgel'],
      name: 'Энтеросгель',
      latinName: 'Enterosgel',
      category: 'ЖКТ',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['лоперамид', 'loperamide', 'имодиум', 'imodium'],
      name: 'Лоперамид',
      latinName: 'Loperamide',
      category: 'ЖКТ',
      minStock: 4,
    ),
    _MedicineHint(
      aliases: ['активированный уголь', 'уголь активированный', 'activated charcoal'],
      name: 'Активированный уголь',
      latinName: 'Activated charcoal',
      category: 'Сорбенты',
      minStock: 5,
    ),
    _MedicineHint(
      aliases: ['фервекс', 'fervex'],
      name: 'Фервекс',
      latinName: 'Fervex',
      category: 'От простуды',
      minStock: 8,
    ),
    _MedicineHint(
      aliases: ['називин', 'nasivin', 'оксиметазолин', 'oxymetazoline'],
      name: 'Називин',
      latinName: 'Nasivin',
      category: 'От простуды',
      minStock: 6,
    ),
    _MedicineHint(
      aliases: ['анаферон', 'anaferon'],
      name: 'Анаферон',
      latinName: 'Anaferon',
      category: 'Противовирусное',
      minStock: 4,
    ),
  ];
}

class _MedicineHint {
  final List<String> aliases;
  final String name;
  final String? latinName;
  final String category;
  final String? manufacturer;
  final String? dosage;
  final int minStock;

  const _MedicineHint({
    required this.aliases,
    required this.name,
    this.latinName,
    required this.category,
    this.manufacturer,
    this.dosage,
    required this.minStock,
  });
}
