import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class BarcodeService {
  static const String _openFoodFactsApiUrl =
      'https://world.openfoodfacts.org/api/v2/product/';
  static const String _openProductsFactsApiUrl =
      'https://world.openproductsfacts.org/api/v2/product/';
  static const String _openFdaApiUrl = 'https://api.fda.gov/drug/label.json';

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Возвращает черновик лекарства всегда, даже если внешний справочник ничего
  /// не знает о коде. Так UI не упирается в ошибку "не найдено".
  static Future<Map<String, dynamic>?> lookupBarcode(String barcode) async {
    final normalizedBarcode = _normalizeBarcode(barcode);
    if (!_looksLikeBarcode(normalizedBarcode)) return null;

    try {
      debugPrint('Looking up barcode: $normalizedBarcode');

      final sources = <Future<Map<String, dynamic>?> Function()>[
        () => _lookupLearnedBarcode(normalizedBarcode),
        () => _lookupB2BInventory(normalizedBarcode),
        () => _lookupOpenProductsFacts(normalizedBarcode),
        () => _lookupOpenFoodFacts(normalizedBarcode),
        () => _lookupOpenFDA(normalizedBarcode),
      ];

      for (final source in sources) {
        final result = await source();
        if (result == null) continue;
        return _withDefaults(
          normalizedBarcode,
          result,
          needsPackageScan: _needsPackageScan(result),
        );
      }

      final localResult = _lookupLocalDatabase(normalizedBarcode);
      if (localResult != null) {
        return _withDefaults(
          normalizedBarcode,
          localResult,
          needsPackageScan: _needsPackageScan(localResult),
        );
      }
    } catch (e) {
      debugPrint('Barcode lookup error: $e');
    }

    return _unknownDraft(normalizedBarcode);
  }

  static Future<void> rememberBarcode({
    required String barcode,
    required Map<String, dynamic> medicineData,
  }) async {
    final normalizedBarcode = _normalizeBarcode(barcode);
    if (!_looksLikeBarcode(normalizedBarcode)) return;

    final cleaned = <String, dynamic>{
      'barcode': normalizedBarcode,
      'name': _nonEmpty(medicineData['name']),
      'category': _nonEmpty(medicineData['category']) ?? 'Другое',
      'manufacturer':
          _nonEmpty(medicineData['manufacturer']) ??
          _nonEmpty(medicineData['brand']),
      'brand':
          _nonEmpty(medicineData['brand']) ??
          _nonEmpty(medicineData['manufacturer']),
      'dosage': _nonEmpty(medicineData['dosage']),
      'packageSize': _nonEmpty(medicineData['packageSize']),
      'batchNumber': _nonEmpty(medicineData['batchNumber']),
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'SmartKit user scan',
    }..removeWhere((_, value) => value == null);

    if ((cleaned['name'] as String?)?.isEmpty ?? true) return;

    try {
      await _firestore
          .collection('barcode_products')
          .doc(normalizedBarcode)
          .set(cleaned, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Barcode remember error: $e');
    }
  }

  static Future<Map<String, dynamic>?> _lookupLearnedBarcode(
    String barcode,
  ) async {
    try {
      final doc = await _firestore
          .collection('barcode_products')
          .doc(barcode)
          .get()
          .timeout(const Duration(seconds: 4));
      final data = doc.data();
      if (data == null) return null;
      return {
        ...data,
        'source': data['source'] ?? 'SmartKit learned barcode',
        'confidence': data['confidence'] ?? 0.95,
      };
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _lookupB2BInventory(
    String barcode,
  ) async {
    try {
      final snapshot = await _firestore
          .collection('b2b_inventory')
          .where('barcode', isEqualTo: barcode)
          .limit(1)
          .get()
          .timeout(const Duration(seconds: 4));
      if (snapshot.docs.isEmpty) return null;

      final data = snapshot.docs.first.data();
      return {
        'name': _nonEmpty(data['name']),
        'category': _nonEmpty(data['category']),
        'manufacturer': _nonEmpty(data['manufacturer']),
        'brand': _nonEmpty(data['manufacturer']),
        'dosage': _nonEmpty(data['dosage']),
        'packageSize': _nonEmpty(data['packageSize']),
        'batchNumber': _nonEmpty(data['batchNumber']),
        'expiryDate':
            (data['expiryDate'] as Timestamp?)?.toDate().toIso8601String(),
        'source': 'B2B inventory',
        'confidence': 0.92,
      };
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _lookupOpenProductsFacts(
    String barcode,
  ) async {
    return _lookupOpenFacts(
      barcode: barcode,
      endpoint: _openProductsFactsApiUrl,
      source: 'Open Products Facts',
    );
  }

  static Future<Map<String, dynamic>?> _lookupOpenFoodFacts(String barcode) {
    return _lookupOpenFacts(
      barcode: barcode,
      endpoint: _openFoodFactsApiUrl,
      source: 'Open Food Facts',
    );
  }

  static Future<Map<String, dynamic>?> _lookupOpenFacts({
    required String barcode,
    required String endpoint,
    required String source,
  }) async {
    try {
      final uri = Uri.parse('$endpoint$barcode.json');
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      if (data['status'] != 1 || data['product'] == null) return null;

      final product = data['product'] as Map<String, dynamic>;
      final name = _firstNonEmpty([
        product['product_name_ru'],
        product['product_name'],
        product['generic_name_ru'],
        product['generic_name'],
        product['abbreviated_product_name'],
      ]);

      if (name == null) return null;

      final quantity = _firstNonEmpty([
        product['quantity'],
        product['packaging'],
      ]);
      final textForCategory = [
        product['categories'],
        product['categories_tags'],
        product['generic_name'],
        product['product_name'],
      ].join(' ');

      return {
        'name': name,
        'category': _mapCategory(textForCategory),
        'manufacturer': _firstNonEmpty([
          product['brands'],
          product['manufacturing_places'],
          product['producer'],
        ]),
        'brand': _firstNonEmpty([product['brands']]),
        'packageSize': _extractPackageSize(quantity ?? name),
        'dosage': _extractDosage('$name ${product['generic_name'] ?? ''}'),
        'source': source,
        'confidence': source == 'Open Products Facts' ? 0.78 : 0.62,
      };
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _lookupOpenFDA(String barcode) async {
    for (final ndc in _candidateNdcCodes(barcode)) {
      try {
        final query = Uri.encodeQueryComponent(
          'openfda.package_ndc:"$ndc" OR openfda.product_ndc:"$ndc"',
        );
        final uri = Uri.parse('$_openFdaApiUrl?search=$query&limit=1');
        final response = await http
            .get(uri)
            .timeout(const Duration(seconds: 8));
        if (response.statusCode != 200) continue;

        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final results = data['results'];
        if (results is! List || results.isEmpty) continue;

        final result = results.first as Map<String, dynamic>;
        final openfda =
            (result['openfda'] as Map?)?.cast<String, dynamic>() ?? {};
        final name = _firstNonEmpty([
          _firstFromList(openfda['brand_name']),
          _firstFromList(openfda['generic_name']),
        ]);
        if (name == null) continue;

        final labelText = [
          _firstFromList(result['description']),
          _firstFromList(result['dosage_and_administration']),
          _firstFromList(openfda['substance_name']),
          _firstFromList(openfda['pharm_class_epc']),
        ].join(' ');

        return {
          'name': name,
          'category': _mapCategory(labelText),
          'manufacturer': _firstFromList(openfda['manufacturer_name']),
          'brand': _firstFromList(openfda['manufacturer_name']),
          'dosage': _extractDosage(labelText),
          'source': 'OpenFDA',
          'confidence': 0.76,
        };
      } catch (_) {
        continue;
      }
    }

    return null;
  }

  static Map<String, dynamic>? _lookupLocalDatabase(String barcode) {
    final localDb = <String, Map<String, dynamic>>{
      '4601669003515': {
        'name': 'Арбидол',
        'category': 'Противовирусное',
        'brand': 'Отисифарм',
      },
      '4601423000019': {
        'name': 'Анальгин',
        'category': 'Обезболивающее',
        'brand': 'Фармстандарт',
      },
      '300056434407': {
        'name': 'Advil (Ibuprofen)',
        'category': 'Обезболивающее',
        'brand': 'Pfizer',
        'dosage': '200 mg',
      },
      '4607027766524': {
        'name': 'Парацетамол',
        'category': 'Обезболивающее',
        'brand': 'Озон',
        'dosage': '500 мг',
      },
      '4607027766347': {
        'name': 'Нурофен Форте',
        'category': 'Обезболивающее',
        'brand': 'Reckitt Benckiser',
        'dosage': '400 мг',
      },
      '4013054001555': {
        'name': 'Мезим Форте',
        'category': 'ЖКТ',
        'brand': 'Berlin-Chemie',
      },
      '3574661413464': {
        'name': 'Терафлю',
        'category': 'От простуды',
        'brand': 'GSK',
      },
      '7611628100104': {
        'name': 'Вольтарен Эмульгель',
        'category': 'Противовоспалительное',
        'brand': 'Novartis',
      },
      '4600613000018': {
        'name': 'Аспирин',
        'category': 'Обезболивающее',
        'brand': 'Bayer',
      },
      '4607027765104': {
        'name': 'Цитрамон П',
        'category': 'Обезболивающее',
        'brand': 'Обновление',
      },
      '4602509001353': {'name': 'Но-шпа', 'category': 'ЖКТ', 'brand': 'Sanofi'},
      '4607027767429': {
        'name': 'Кеторол',
        'category': 'Обезболивающее',
        'brand': 'Dr. Reddy\'s',
      },
      '5995327165844': {
        'name': 'Супрастин',
        'category': 'От аллергии',
        'brand': 'Egis',
      },
      '3838957017721': {'name': 'Линекс', 'category': 'ЖКТ', 'brand': 'Sandoz'},
      '3582182030006': {'name': 'Смекта', 'category': 'ЖКТ', 'brand': 'Ipsen'},
      '4601669002570': {
        'name': 'Пенталгин',
        'category': 'Обезболивающее',
        'brand': 'Отисифарм',
      },
      '4607024100106': {
        'name': 'Кагоцел',
        'category': 'Противовирусное',
        'brand': 'Ниармедик',
      },
      '4602193001859': {
        'name': 'Ингавирин',
        'category': 'Противовирусное',
        'brand': 'Валента Фарм',
      },
      '4605423000010': {
        'name': 'Мирамистин',
        'category': 'Антисептик',
        'brand': 'Инфамед',
      },
      '4607027766026': {
        'name': 'Хлоргексидин',
        'category': 'Антисептик',
        'brand': 'Озон',
      },
      '4601423000323': {
        'name': 'Левомеколь',
        'category': 'Противовоспалительное',
        'brand': 'Нижфарм',
      },
      '4601423000088': {
        'name': 'Корвалол',
        'category': 'Другое',
        'brand': 'Фармстандарт',
      },
      '4008491113019': {
        'name': 'Глицин',
        'category': 'Другое',
        'brand': 'Биотики',
      },
      '4607027766623': {
        'name': 'Ибупрофен',
        'category': 'Обезболивающее',
        'brand': 'Озон',
      },
      '4601423000217': {
        'name': 'Уголь активированный',
        'category': 'ЖКТ',
        'brand': 'Фармстандарт',
      },
    };

    final item = localDb[barcode];
    if (item == null) return null;
    return {...item, 'source': 'Local fallback', 'confidence': 0.7};
  }

  static Map<String, dynamic> _withDefaults(
    String barcode,
    Map<String, dynamic> data, {
    required bool needsPackageScan,
  }) {
    final name = _nonEmpty(data['name']);
    final category = _nonEmpty(data['category']) ?? 'Другое';

    return {
      ...data,
      'barcode': barcode,
      'name': name,
      'category': category,
      'manufacturer':
          _nonEmpty(data['manufacturer']) ?? _nonEmpty(data['brand']),
      'brand': _nonEmpty(data['brand']) ?? _nonEmpty(data['manufacturer']),
      'needsPackageScan': needsPackageScan,
      'isUnknown': name == null,
      'lookupMessage':
          needsPackageScan
              ? 'Сканируйте упаковку, чтобы уточнить дозировку, срок годности и серию.'
              : 'Данные найдены по штрих-коду.',
    };
  }

  static Map<String, dynamic> _unknownDraft(String barcode) {
    return {
      'barcode': barcode,
      'name': null,
      'category': 'Другое',
      'source': 'Barcode only',
      'confidence': 0.2,
      'needsPackageScan': true,
      'isUnknown': true,
      'lookupMessage':
          'Штрих-код считан, но в справочниках нет карточки. Сканируйте упаковку, чтобы SmartKit распознал поля по тексту.',
    };
  }

  static bool _needsPackageScan(Map<String, dynamic> data) {
    return _nonEmpty(data['dosage']) == null ||
        _nonEmpty(data['packageSize']) == null ||
        data['expiryDate'] == null;
  }

  static String _normalizeBarcode(String barcode) {
    return barcode.trim().replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
  }

  static bool _looksLikeBarcode(String barcode) {
    return RegExp(r'^[0-9A-Za-z]{6,32}$').hasMatch(barcode);
  }

  static String? _nonEmpty(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String? _firstNonEmpty(List<dynamic> values) {
    for (final value in values) {
      final text = _nonEmpty(value);
      if (text != null) return text;
    }
    return null;
  }

  static String? _firstFromList(dynamic value) {
    if (value is List && value.isNotEmpty) return _nonEmpty(value.first);
    return _nonEmpty(value);
  }

  static Set<String> _candidateNdcCodes(String barcode) {
    final digits = barcode.replaceAll(RegExp(r'\D'), '');
    final candidates = <String>{
      digits,
      digits.replaceFirst(RegExp(r'^0+'), ''),
    };

    for (final length in [11, 10]) {
      if (digits.length >= length) {
        final tail = digits.substring(digits.length - length);
        candidates.add(tail);
        if (tail.length == 11) {
          candidates.add(
            '${tail.substring(0, 5)}-${tail.substring(5, 9)}-${tail.substring(9)}',
          );
        }
        if (tail.length == 10) {
          candidates.add(
            '${tail.substring(0, 4)}-${tail.substring(4, 8)}-${tail.substring(8)}',
          );
          candidates.add(
            '${tail.substring(0, 5)}-${tail.substring(5, 8)}-${tail.substring(8)}',
          );
          candidates.add(
            '${tail.substring(0, 5)}-${tail.substring(5, 9)}-${tail.substring(9)}',
          );
        }
      }
    }

    return candidates.where((value) => value.length >= 8).toSet();
  }

  static String? _extractDosage(String? text) {
    if (text == null) return null;
    final match = RegExp(
      r'\b\d+(?:[,.]\d+)?\s*(?:mg|мг|g|г|mcg|мкг|ml|мл|iu|ме|%)\b',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(0)?.replaceAll(',', '.').trim();
  }

  static String? _extractPackageSize(String? text) {
    if (text == null) return null;
    final match = RegExp(
      r'\b(?:№|n|no\.?|x)?\s?\d{1,4}\s*(?:табл\.?|капс\.?|caps?|tablets?|амп\.?|флак\.?|саше|шт\.?|pcs?)\b',
      caseSensitive: false,
    ).firstMatch(text);
    return match?.group(0)?.trim();
  }

  static String _mapCategory(dynamic tagsOrText) {
    final tagString =
        tagsOrText is List
            ? tagsOrText.join(' ').toLowerCase()
            : tagsOrText.toString().toLowerCase();

    if (tagString.contains('ibuprofen') ||
        tagString.contains('ибупрофен') ||
        tagString.contains('paracetamol') ||
        tagString.contains('парацетамол') ||
        tagString.contains('pain') ||
        tagString.contains('analgesic') ||
        tagString.contains('antipyretic') ||
        tagString.contains('обезбол')) {
      return 'Обезболивающее';
    }
    if (tagString.contains('vitamin') ||
        tagString.contains('supplement') ||
        tagString.contains('витамин')) {
      return 'Витамины';
    }
    if (tagString.contains('antibiotic') ||
        tagString.contains('anti-infective') ||
        tagString.contains('антибиот')) {
      return 'Антибиотик';
    }
    if (tagString.contains('diclofenac') ||
        tagString.contains('диклофенак') ||
        tagString.contains('inflammatory') ||
        tagString.contains('nsaid') ||
        tagString.contains('нпвс')) {
      return 'Противовоспалительное';
    }
    if (tagString.contains('cold') ||
        tagString.contains('flu') ||
        tagString.contains('cough') ||
        tagString.contains('простуд') ||
        tagString.contains('грипп') ||
        tagString.contains('кашель')) {
      return 'От простуды';
    }
    if (tagString.contains('allergy') ||
        tagString.contains('antihistamine') ||
        tagString.contains('аллерг') ||
        tagString.contains('loratadine')) {
      return 'От аллергии';
    }
    if (tagString.contains('antiseptic') ||
        tagString.contains('chlorhexidine') ||
        tagString.contains('хлоргексидин') ||
        tagString.contains('мирамистин')) {
      return 'Антисептик';
    }
    if (tagString.contains('smecta') ||
        tagString.contains('смекта') ||
        tagString.contains('mezim') ||
        tagString.contains('мезим') ||
        tagString.contains('digest') ||
        tagString.contains('stomach') ||
        tagString.contains('жкт')) {
      return 'ЖКТ';
    }
    if (tagString.contains('antiviral') ||
        tagString.contains('арбидол') ||
        tagString.contains('кагоцел') ||
        tagString.contains('ингавирин')) {
      return 'Противовирусное';
    }

    return 'Другое';
  }
}
