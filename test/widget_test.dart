import 'package:flutter_test/flutter_test.dart';
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
}
