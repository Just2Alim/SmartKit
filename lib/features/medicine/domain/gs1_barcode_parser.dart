class Gs1BarcodeParser {
  static Map<String, dynamic>? parse(String rawCode) {
    final raw = rawCode.trim();
    if (raw.isEmpty) return null;

    final aiValues = _parseParenthesized(raw) ?? _parsePlain(raw);
    if (aiValues.isEmpty) return null;

    final gtin = aiValues['01'];
    final expiry = _parseExpiry(aiValues['17']);
    final batch = aiValues['10'];
    final serial = aiValues['21'];

    if (gtin == null && expiry == null && batch == null && serial == null) {
      return null;
    }

    return {
      'barcode': gtin ?? raw,
      'gtin': gtin,
      'expiryDate': expiry?.toIso8601String(),
      'batchNumber': batch,
      'serialNumber': serial,
      'source': 'GS1 DataMatrix',
      'confidence': 0.88,
      'needsPackageScan': gtin == null || expiry == null || batch == null,
      'lookupMessage':
          expiry != null || batch != null
              ? 'Считан GS1 DataMatrix: срок и серия перенесены автоматически.'
              : 'Считан GS1 DataMatrix. Досканируйте упаковку, чтобы уточнить название и дозировку.',
    }..removeWhere((_, value) => value == null || value == '');
  }

  static Map<String, String>? _parseParenthesized(String raw) {
    if (!raw.contains('(')) return null;

    final values = <String, String>{};
    final matches = RegExp(r'\((\d{2,4})\)([^\(]+)').allMatches(raw);
    for (final match in matches) {
      final ai = match.group(1);
      final value = match.group(2)?.trim();
      if (ai != null && value != null && value.isNotEmpty) {
        values[ai] = value;
      }
    }

    return values.isEmpty ? null : values;
  }

  static Map<String, String> _parsePlain(String raw) {
    var text = raw.replaceAll(RegExp(r'^\]d2', caseSensitive: false), '');
    text = text.replaceAll(RegExp(r'^\]C1', caseSensitive: false), '');

    final values = <String, String>{};
    var index = 0;

    while (index < text.length) {
      if (_isSeparator(text.codeUnitAt(index))) {
        index++;
        continue;
      }

      final ai = _readAi(text, index);
      if (ai == null) {
        index++;
        continue;
      }

      index += ai.length;
      final fixedLength = _fixedLengths[ai];

      if (fixedLength != null) {
        if (index + fixedLength > text.length) break;
        values[ai] = text.substring(index, index + fixedLength);
        index += fixedLength;
        continue;
      }

      final valueStart = index;
      while (index < text.length) {
        if (_isSeparator(text.codeUnitAt(index))) break;
        if (index > valueStart && _readAi(text, index) != null) break;
        index++;
      }

      final value = text.substring(valueStart, index).trim();
      if (value.isNotEmpty) values[ai] = value;
    }

    return values;
  }

  static String? _readAi(String text, int index) {
    for (final length in [4, 3, 2]) {
      if (index + length > text.length) continue;
      final candidate = text.substring(index, index + length);
      if (_knownAis.contains(candidate)) return candidate;
    }
    return null;
  }

  static DateTime? _parseExpiry(String? value) {
    if (value == null || value.length < 6) return null;

    final yy = int.tryParse(value.substring(0, 2));
    final mm = int.tryParse(value.substring(2, 4));
    final dd = int.tryParse(value.substring(4, 6));
    if (yy == null || mm == null || dd == null || mm < 1 || mm > 12) {
      return null;
    }

    final year = 2000 + yy;
    if (dd == 0) return DateTime(year, mm + 1, 0);

    final date = DateTime(year, mm, dd);
    if (date.year != year || date.month != mm || date.day != dd) return null;
    return date;
  }

  static bool _isSeparator(int codeUnit) {
    return codeUnit == 29 || codeUnit == 30;
  }

  static const _knownAis = {'01', '10', '17', '21', '240', '241', '422'};

  static const _fixedLengths = {'01': 14, '17': 6, '422': 3};
}
