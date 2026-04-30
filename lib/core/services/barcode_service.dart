import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class BarcodeService {
  static const String _offApiUrl = 'https://world.openfoodfacts.org/api/v2/product/';
  static const String _fdaApiUrl = 'https://api.fda.gov/drug/label.json?search=openfda.package_ndc:';

  /// Пытается найти информацию о лекарстве по штрих-коду
  static Future<Map<String, dynamic>?> lookupBarcode(String barcode) async {
    try {
      debugPrint('Looking up barcode: $barcode');
      
      // 1. Пробуем OpenFoodFacts (хорошо работает для европейских/российских штрих-кодов)
      final offResult = await _lookupOpenFoodFacts(barcode);
      if (offResult != null) return offResult;

      // 2. Пробуем OpenFDA (для лекарств с NDC кодами, США)
      // Преобразуем штрих-код в NDC формат если это возможно (упрощенно)
      final fdaResult = await _lookupOpenFDA(barcode);
      if (fdaResult != null) return fdaResult;
      
      // 3. Локальный справочник самых популярных (для тестов)
      final localResult = _lookupLocalDatabase(barcode);
      if (localResult != null) return localResult;

      return null;
    } catch (e) {
      debugPrint('Barcode lookup error: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> _lookupOpenFoodFacts(String barcode) async {
    try {
      final response = await http.get(Uri.parse('$_offApiUrl$barcode.json')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['status'] == 1) {
          final product = data['product'];
          return {
            'name': product['product_name'] ?? product['product_name_ru'] ?? product['generic_name'] ?? 'Неизвестное лекарство',
            'category': _mapCategory(product['categories_tags'] ?? []),
            'brand': product['brands'] ?? '',
            'source': 'OpenFoodFacts',
          };
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> _lookupOpenFDA(String barcode) async {
    try {
      // OpenFDA использует NDC (National Drug Code). Часто штрих-коды UPC/EAN содержат NDC.
      // Попробуем поискать по всему коду
      final response = await http.get(Uri.parse('$_fdaApiUrl"$barcode"')).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['results'] != null && data['results'].isNotEmpty) {
          final result = data['results'][0];
          final openfda = result['openfda'];
          return {
            'name': openfda['brand_name']?[0] ?? openfda['generic_name']?[0] ?? 'Неизвестное лекарство',
            'category': _mapCategory(openfda['pharm_class_cs'] ?? []),
            'brand': openfda['manufacturer_name']?[0] ?? '',
            'source': 'OpenFDA',
          };
        }
      }
    } catch (_) {}
    return null;
  }

  static Map<String, dynamic>? _lookupLocalDatabase(String barcode) {
    // Демонстрационный локальный маппинг для популярных лекарств
    final Map<String, Map<String, dynamic>> localDb = {
      '4601669003515': {'name': 'Арбидол', 'category': 'Противовирусное', 'brand': 'Отисифарм'},
      '4601423000019': {'name': 'Анальгин', 'category': 'Обезболивающее', 'brand': 'Фармстандарт'},
      '300056434407': {'name': 'Advil (Ibuprofen)', 'category': 'Обезболивающее', 'brand': 'Pfizer'},
      '4607027766524': {'name': 'Парацетамол', 'category': 'Обезболивающее', 'brand': 'Озон'},
      '4607027766347': {'name': 'Нурофен Форте', 'category': 'Обезболивающее', 'brand': 'Reckitt Benckiser'},
      '4013054001555': {'name': 'Мезим Форте', 'category': 'Другое', 'brand': 'Berlin-Chemie'},
      '3574661413464': {'name': 'Терафлю', 'category': 'Другое', 'brand': 'GSK'},
      '7611628100104': {'name': 'Вольтарен Эмульгель', 'category': 'Обезболивающее', 'brand': 'Novartis'},
      '4600613000018': {'name': 'Аспирин', 'category': 'Обезболивающее', 'brand': 'Bayer'},
      '4607027765104': {'name': 'Цитрамон', 'category': 'Обезболивающее', 'brand': 'Обновление'},
      '4602509001353': {'name': 'Но-шпа', 'category': 'Обезболивающее', 'brand': 'Sanofi'},
      '4607027767429': {'name': 'Кеторол', 'category': 'Обезболивающее', 'brand': 'Dr. Reddy\'s'},
      '5995327165844': {'name': 'Супрастин', 'category': 'От аллергии', 'brand': 'Egis'},
      '3838957017721': {'name': 'Линекс', 'category': 'Другое', 'brand': 'Sandoz'},
      '3582182030006': {'name': 'Смекта', 'category': 'Другое', 'brand': 'Ipsen'},
      '4601669002570': {'name': 'Пенталгин', 'category': 'Обезболивающее', 'brand': 'Отисифарм'},
      '4607024100106': {'name': 'Кагоцел', 'category': 'Противовирусное', 'brand': 'Ниармедик'},
      '4602193001859': {'name': 'Ингавирин', 'category': 'Противовирусное', 'brand': 'Валента Фарм'},
      '4605423000010': {'name': 'Мирамистин', 'category': 'Другое', 'brand': 'Инфамед'},
      '4607027766026': {'name': 'Хлоргексидин', 'category': 'Другое', 'brand': 'Озон'},
      '4601423000323': {'name': 'Левомеколь', 'category': 'Противовоспалительное', 'brand': 'Нижфарм'},
      '4601423000088': {'name': 'Корвалол', 'category': 'Другое', 'brand': 'Фармстандарт'},
      '4008491113019': {'name': 'Глицин', 'category': 'Другое', 'brand': 'Биотики'},
      '4602509001353': {'name': 'Но-шпа', 'category': 'Обезболивающее', 'brand': 'Sanofi'},
      '4607027766623': {'name': 'Ибупрофен', 'category': 'Обезболивающее', 'brand': 'Озон'},
      '4601423000217': {'name': 'Уголь активированный', 'category': 'Другое', 'brand': 'Фармстандарт'},
      '4607027765104': {'name': 'Цитрамон П', 'category': 'Обезболивающее', 'brand': 'Обновление'},
    };

    if (localDb.containsKey(barcode)) {
      final item = localDb[barcode]!;
      return {
        ...item,
        'source': 'Local Database',
      };
    }
    return null;
  }

  static String _mapCategory(List<dynamic> tags) {
    if (tags.isEmpty) return 'Другое';
    
    final tagString = tags.join(' ').toLowerCase();
    
    if (tagString.contains('pain') || tagString.contains('analgesic') || tagString.contains('antipyretic')) return 'Обезболивающее';
    if (tagString.contains('vitamin') || tagString.contains('supplement')) return 'Витамины';
    if (tagString.contains('antibiotic') || tagString.contains('anti-infective')) return 'Антибиотик';
    if (tagString.contains('inflammatory') || tagString.contains('nsaid')) return 'Противовоспалительное';
    if (tagString.contains('cold') || tagString.contains('flu') || tagString.contains('cough')) return 'От простуды';
    if (tagString.contains('allergy') || tagString.contains('antihistamine')) return 'От аллергии';
    if (tagString.contains('antiviral')) return 'Противовирусное';
    
    return 'Другое';
  }
}
