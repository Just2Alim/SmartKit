import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/medicine/domain/gs1_barcode_parser.dart';

class BarcodeService {
  static final Map<String, Map<String, dynamic>> _lookupCache = {};
  static const Duration _privateLookupTimeout = Duration(milliseconds: 900);
  static const Duration _publicLookupTimeout = Duration(milliseconds: 1800);
  static const Duration _referenceEnrichmentTimeout = Duration(
    milliseconds: 1200,
  );
  static const Duration _externalHttpTimeout = Duration(seconds: 3);

  static const String _openFoodFactsApiUrl =
      'https://world.openfoodfacts.org/api/v2/product/';
  static const String _openProductsFactsApiUrl =
      'https://world.openproductsfacts.org/api/v2/product/';
  static const String _openFdaApiUrl = 'https://api.fda.gov/drug/label.json';
  static const String _dailyMedSplsApiUrl =
      'https://dailymed.nlm.nih.gov/dailymed/services/v2/spls.json';
  static const String _rxNormDrugsApiUrl =
      'https://rxnav.nlm.nih.gov/REST/drugs.json';

  static SupabaseClient get _client => Supabase.instance.client;

  /// Возвращает черновик лекарства всегда, даже если внешний справочник ничего
  /// не знает о коде. Так UI не упирается в ошибку "не найдено".
  static Future<Map<String, dynamic>?> lookupBarcode(
    String barcode, {
    bool allowSlowNetwork = true,
  }) async {
    final gs1Data = Gs1BarcodeParser.parse(barcode);
    final lookupValue =
        gs1Data?['gtin']?.toString() ??
        gs1Data?['barcode']?.toString() ??
        barcode;
    final normalizedBarcode = _normalizeBarcode(lookupValue);
    if (!_looksLikeBarcode(normalizedBarcode)) return null;

    final cached = _lookupCache[normalizedBarcode];
    if (cached != null) return Map<String, dynamic>.from(cached);

    try {
      debugPrint('Looking up barcode: $normalizedBarcode');

      final localResult = _lookupLocalDatabase(normalizedBarcode);
      if (localResult != null) {
        final merged = _mergeScanData(localResult, gs1Data);
        return _rememberLookup(
          normalizedBarcode,
          _withDefaults(
            normalizedBarcode,
            merged,
            needsPackageScan: _needsPackageScan(merged),
          ),
        );
      }

      final privateResult = await _bestLookup([
        _lookupLearnedBarcode(normalizedBarcode),
        _lookupB2BInventory(normalizedBarcode),
      ], timeout: _privateLookupTimeout);

      if (privateResult != null) {
        final enriched =
            allowSlowNetwork
                ? await _enrichDrugReference(privateResult).timeout(
                  _referenceEnrichmentTimeout,
                  onTimeout: () => privateResult,
                )
                : privateResult;
        final merged = _mergeScanData(enriched, gs1Data);
        return _rememberLookup(
          normalizedBarcode,
          _withDefaults(
            normalizedBarcode,
            merged,
            needsPackageScan: _needsPackageScan(merged),
          ),
        );
      }

      if (!allowSlowNetwork) {
        if (gs1Data != null) {
          return _rememberLookup(
            normalizedBarcode,
            _withDefaults(
              normalizedBarcode,
              gs1Data,
              needsPackageScan: _needsPackageScan(gs1Data),
            ),
          );
        }
        return _rememberLookup(
          normalizedBarcode,
          _unknownDraft(normalizedBarcode),
        );
      }

      final publicResult = await _bestLookup([
        _lookupOpenProductsFacts(normalizedBarcode),
        _lookupOpenFoodFacts(normalizedBarcode),
        _lookupOpenFDA(normalizedBarcode),
      ], timeout: _publicLookupTimeout);

      if (publicResult != null) {
        final enriched = await _enrichDrugReference(
          publicResult,
        ).timeout(_referenceEnrichmentTimeout, onTimeout: () => publicResult);
        final merged = _mergeScanData(enriched, gs1Data);
        return _rememberLookup(
          normalizedBarcode,
          _withDefaults(
            normalizedBarcode,
            merged,
            needsPackageScan: _needsPackageScan(merged),
          ),
        );
      }
    } catch (e) {
      debugPrint('Barcode lookup error: $e');
    }

    if (gs1Data != null) {
      return _rememberLookup(
        normalizedBarcode,
        _withDefaults(
          normalizedBarcode,
          gs1Data,
          needsPackageScan: _needsPackageScan(gs1Data),
        ),
      );
    }

    return _rememberLookup(normalizedBarcode, _unknownDraft(normalizedBarcode));
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
      'package_size': _nonEmpty(medicineData['packageSize']),
      'batch_number': _nonEmpty(medicineData['batchNumber']),
      'updated_at': DateTime.now().toIso8601String(),
      'source': 'SmartKit user scan',
    }..removeWhere((_, value) => value == null);

    if ((cleaned['name'] as String?)?.isEmpty ?? true) return;

    try {
      await _client
          .from('barcode_products')
          .upsert(cleaned, onConflict: 'barcode');
    } catch (e) {
      debugPrint('Barcode remember error: $e');
    }
  }

  static Future<Map<String, dynamic>?> _lookupLearnedBarcode(
    String barcode,
  ) async {
    try {
      final data = await _client
          .from('barcode_products')
          .select()
          .eq('barcode', barcode)
          .maybeSingle()
          .timeout(const Duration(seconds: 2));
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
      final data = await _client
          .from('b2b_inventory')
          .select()
          .eq('barcode', barcode)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 2));
      if (data == null) return null;

      return {
        'name': _nonEmpty(data['name']),
        'category': _nonEmpty(data['category']),
        'manufacturer': _nonEmpty(data['manufacturer']),
        'brand': _nonEmpty(data['manufacturer']),
        'dosage': _nonEmpty(data['dosage']),
        'packageSize': _nonEmpty(data['package_size'] ?? data['packageSize']),
        'batchNumber': _nonEmpty(data['batch_number'] ?? data['batchNumber']),
        'expiryDate': data['expiry_date']?.toString(),
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
      final response = await http.get(uri).timeout(_externalHttpTimeout);
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
        final response = await http.get(uri).timeout(_externalHttpTimeout);
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

  static Future<Map<String, dynamic>> _enrichDrugReference(
    Map<String, dynamic> base,
  ) async {
    final name = _nonEmpty(base['name']);
    if (name == null) return base;
    if (_nonEmpty(base['category']) != null &&
        _nonEmpty(base['dosage']) != null) {
      return base;
    }

    try {
      final references = await Future.wait([
        _lookupDailyMedByName(name),
        _lookupRxNormByName(name),
      ]);

      var merged = Map<String, dynamic>.from(base);
      for (final reference in references) {
        if (reference == null) continue;
        merged = _mergeReferenceData(merged, reference);
      }
      return merged;
    } catch (_) {
      return base;
    }
  }

  static Future<Map<String, dynamic>?> _bestLookup(
    List<Future<Map<String, dynamic>?>> lookups, {
    required Duration timeout,
  }) async {
    try {
      final results = await Future.wait(
        lookups.map((lookup) => lookup.timeout(timeout, onTimeout: () => null)),
      ).timeout(timeout + const Duration(milliseconds: 250));

      final candidates = results.whereType<Map<String, dynamic>>().toList();
      if (candidates.isEmpty) return null;
      candidates.sort((a, b) {
        final aConfidence = (a['confidence'] as num?)?.toDouble() ?? 0.0;
        final bConfidence = (b['confidence'] as num?)?.toDouble() ?? 0.0;
        return bConfidence.compareTo(aConfidence);
      });
      return candidates.first;
    } catch (_) {
      return null;
    }
  }

  static Map<String, dynamic> _rememberLookup(
    String barcode,
    Map<String, dynamic> result,
  ) {
    _lookupCache[barcode] = Map<String, dynamic>.from(result);
    return result;
  }

  static Future<Map<String, dynamic>?> _lookupDailyMedByName(
    String name,
  ) async {
    try {
      final uri = Uri.parse(
        _dailyMedSplsApiUrl,
      ).replace(queryParameters: {'drug_name': name, 'pagesize': '1'});
      final response = await http.get(uri).timeout(_externalHttpTimeout);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final rows = data['data'];
      if (rows is! List || rows.isEmpty || rows.first is! Map) return null;

      final item = (rows.first as Map).cast<String, dynamic>();
      final title = _firstNonEmpty([
        item['title'],
        item['spl_product_data_elements'],
        item['published_date'],
      ]);
      final text = [
        title,
        item['dosage_form'],
        item['marketing_category'],
      ].whereType<Object>().join(' ');

      return {
        'name': _extractReadableName(title) ?? name,
        'category': _mapCategory(text),
        'dosage': _extractDosage(text),
        'form': _firstNonEmpty([item['dosage_form']]),
        'source': 'DailyMed',
        'confidence': 0.7,
      }..removeWhere((_, value) => value == null || value == '');
    } catch (_) {
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _lookupRxNormByName(String name) async {
    try {
      final uri = Uri.parse(
        _rxNormDrugsApiUrl,
      ).replace(queryParameters: {'name': name});
      final response = await http.get(uri).timeout(_externalHttpTimeout);
      if (response.statusCode != 200) return null;

      final data = jsonDecode(utf8.decode(response.bodyBytes));
      final drugGroup = data['drugGroup'];
      if (drugGroup is! Map) return null;

      final conceptGroups = drugGroup['conceptGroup'];
      if (conceptGroups is! List) return null;

      Map<String, dynamic>? concept;
      for (final group in conceptGroups) {
        if (group is! Map) continue;
        final properties = group['conceptProperties'];
        if (properties is List && properties.isNotEmpty) {
          concept = (properties.first as Map).cast<String, dynamic>();
          break;
        }
      }

      if (concept == null) return null;

      final conceptName = _firstNonEmpty([concept['synonym'], concept['name']]);
      final text = [conceptName, concept['tty']].whereType<Object>().join(' ');

      return {
        'name': conceptName ?? name,
        'dosage': _extractDosage(text),
        'category': _mapCategory(text),
        'rxCui': _nonEmpty(concept['rxcui']),
        'source': 'RxNorm',
        'confidence': 0.72,
      }..removeWhere((_, value) => value == null || value == '');
    } catch (_) {
      return null;
    }
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
      '4607001771561': {
        'name': 'Цетрин',
        'category': 'От аллергии',
        'brand': 'Dr. Reddy\'s',
        'dosage': '10 мг',
      },
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

  static Map<String, dynamic> _mergeScanData(
    Map<String, dynamic> base,
    Map<String, dynamic>? scanData,
  ) {
    if (scanData == null) return base;

    final merged = Map<String, dynamic>.from(base);
    for (final entry in scanData.entries) {
      final value = entry.value;
      if (value == null || value.toString().trim().isEmpty) continue;

      if (entry.key == 'source') {
        merged['source'] = _combineSources(merged['source'], value);
        continue;
      }

      final current = merged[entry.key];
      if (current == null || current.toString().trim().isEmpty) {
        merged[entry.key] = value;
      } else if (entry.key == 'expiryDate' || entry.key == 'batchNumber') {
        merged[entry.key] = value;
      }
    }

    final scanMessage = _nonEmpty(scanData['lookupMessage']);
    if (scanMessage != null) merged['lookupMessage'] = scanMessage;
    return merged;
  }

  static Map<String, dynamic> _mergeReferenceData(
    Map<String, dynamic> base,
    Map<String, dynamic> reference,
  ) {
    final merged = Map<String, dynamic>.from(base);

    for (final key in [
      'category',
      'dosage',
      'form',
      'rxCui',
      'manufacturer',
      'packageSize',
    ]) {
      final value = _nonEmpty(reference[key]);
      final current = _nonEmpty(merged[key]);
      if (value != null && current == null) merged[key] = value;
    }

    merged['source'] = _combineSources(merged['source'], reference['source']);
    final confidence = reference['confidence'];
    if (confidence is num) {
      final current = merged['confidence'];
      final currentNum = current is num ? current : 0;
      merged['confidence'] = currentNum > confidence ? currentNum : confidence;
    }

    return merged;
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
          _nonEmpty(data['lookupMessage']) ??
          (needsPackageScan
              ? 'Сканируйте упаковку, чтобы уточнить дозировку, срок годности и серию.'
              : 'Данные найдены по штрих-коду.'),
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

  static String _combineSources(dynamic current, dynamic next) {
    final values =
        [_nonEmpty(current), _nonEmpty(next)]
            .whereType<String>()
            .expand((value) => value.split('+'))
            .map((value) {
              return value.trim();
            })
            .where((value) => value.isNotEmpty)
            .toSet();

    return values.join(' + ');
  }

  static String? _extractReadableName(String? title) {
    final text = _nonEmpty(title);
    if (text == null) return null;

    final cleaned =
        text
            .replaceAll(
              RegExp(
                r'\b(?:tablet|capsule|solution|syrup|cream|gel|spray)s?\b',
                caseSensitive: false,
              ),
              ' ',
            )
            .replaceAll(
              RegExp(
                r'\b\d+(?:[,.]\d+)?\s*(?:mg|mcg|g|ml|%)\b',
                caseSensitive: false,
              ),
              ' ',
            )
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

    return cleaned.isEmpty ? text : cleaned;
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
      r'(?:№\s?\d{1,4}|\b(?:n|no\.?|x)?\s?\d{1,4}\s*(?:табл\.?|капс\.?|caps?|tablets?|амп\.?|флак\.?|саше|шт\.?|pcs?)\b)',
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
        tagString.contains('loratadine') ||
        tagString.contains('cetirizine') ||
        tagString.contains('цетиризин') ||
        tagString.contains('цетрин') ||
        tagString.contains('супрастин')) {
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
