import 'package:flutter_test/flutter_test.dart';
import 'package:smartkit/core/services/barcode_service.dart';
import 'package:smartkit/features/b2b/inventory/data/b2b_ocr_service.dart';

void main() {
  test('parses medicine package OCR text into receipt fields', () {
    final result = B2BOcrService().parsePackageText('''
Nurofen Forte
Ibuprofen 400 mg
LOT AB1234
EXP 12/2028
Bayer Pharma
4607027766347
''');

    expect(result.name, 'Nurofen Forte');
    expect(result.category, 'Обезболивающее');
    expect(result.dosage, '400 mg');
    expect(result.batchNumber, 'AB1234');
    expect(result.manufacturer, 'Bayer Pharma');
    expect(result.barcode, '4607027766347');
    expect(result.expiryDate?.year, 2028);
    expect(result.expiryDate?.month, 12);
  });

  test('uses medicine hints for noisy package text and form defaults', () {
    final result = B2BOcrService().parsePackageText('''
НУРОФЕН ФОРТЕ
ибупрофен 400мг
таблетки покрытые оболочкой N 12
Reckitt Benckiser
Годен до 12.2028
Серия AB1234
''');

    expect(result.name, 'Нурофен Форте');
    expect(result.category, 'Обезболивающее');
    expect(result.dosage, '400 мг');
    expect(result.packageSize, contains('12'));
    expect(result.manufacturer, 'Reckitt Benckiser');
    expect(result.batchNumber, 'AB1234');
    expect(result.suggestedStock, 1);
    expect(result.suggestedMinStock, greaterThan(0));
    expect(result.confidence, greaterThanOrEqualTo(0.75));
    expect(result.needsReview, isFalse);
  });

  test(
    'resolves known medicine barcode without waiting for network lookup',
    () async {
      final result = await BarcodeService.lookupBarcode('4607027766347');

      expect(result, isNotNull);
      expect(result?['name'], 'Нурофен Форте');
      expect(result?['category'], 'Обезболивающее');
      expect(result?['dosage'], '400 мг');
      expect(result?['barcode'], '4607027766347');
      expect(result?['source'], contains('Local fallback'));
    },
  );

  test(
    'returns an instant draft for unknown barcodes in fast scan mode',
    () async {
      final stopwatch = Stopwatch()..start();
      final result = await BarcodeService.lookupBarcode(
        '4871234567890',
        allowSlowNetwork: false,
      );
      stopwatch.stop();

      expect(result, isNotNull);
      expect(result?['barcode'], '4871234567890');
      expect(result?['needsPackageScan'], isTrue);
      expect(result?['isUnknown'], isTrue);
      expect(stopwatch.elapsedMilliseconds, lessThan(1200));
    },
  );

  test('recognizes common Cyrillic package text with minimal manual input', () {
    final result = B2BOcrService().parsePackageText('''
ЦЕТРИН
цетиризин 10мг
таблетки покрытые оболочкой №20
Dr. Reddy's Laboratories
Партия CT12345
Срок годности 05/2029
''');

    expect(result.name, 'Цетрин');
    expect(result.category, 'От аллергии');
    expect(result.dosage, '10 мг');
    expect(result.packageSize, contains('20'));
    expect(result.manufacturer, contains('Reddy'));
    expect(result.batchNumber, 'CT12345');
    expect(result.expiryDate?.year, 2029);
    expect(result.expiryDate?.month, 5);
    expect(result.suggestedStock, 1);
    expect(result.suggestedMinStock, greaterThan(0));
    expect(result.confidence, greaterThanOrEqualTo(0.75));
  });

  test('repairs mixed Latin/Cyrillic OCR noise before field extraction', () {
    final result = B2BOcrService().parsePackageText('''
HYPOFEH ФOPTE
IBYПPOFEH 400 Mr
TAБЛETKИ N 12
PECKITT BENCKISER
ГOДEH ДO 12/2028
CEPИЯ AB1234
''');

    expect(result.name, 'Нурофен Форте');
    expect(result.category, 'Обезболивающее');
    expect(result.dosage, '400 мг');
    expect(result.packageSize, contains('12'));
    expect(result.batchNumber, 'AB1234');
    expect(result.expiryDate?.year, 2028);
    expect(result.expiryDate?.month, 12);
    expect(result.form, isNotEmpty);
    expect(result.unitLabel, 'шт');
    expect(result.description, isNotEmpty);
  });
}
