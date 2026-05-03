import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../data/b2b_ocr_service.dart';
import '../models/b2b_ocr_result.dart';

class B2BPackageOcrScreen extends StatefulWidget {
  const B2BPackageOcrScreen({super.key});

  @override
  State<B2BPackageOcrScreen> createState() => _B2BPackageOcrScreenState();
}

class _B2BPackageOcrScreenState extends State<B2BPackageOcrScreen> {
  final ImagePicker _picker = ImagePicker();
  final B2BOcrService _ocrService = B2BOcrService();

  B2BOcrResult? _result;
  Uint8List? _previewBytes;
  bool _isProcessing = false;
  String? _error;

  Future<void> _pickAndProcess(ImageSource source) async {
    if (kIsWeb) {
      setState(() {
        _error = 'OCR упаковок доступен в мобильной сборке приложения';
      });
      return;
    }

    final image = await _picker.pickImage(
      source: source,
      imageQuality: 88,
      maxWidth: 1800,
    );
    if (image == null) return;

    setState(() {
      _isProcessing = true;
      _error = null;
      _result = null;
    });

    try {
      final bytes = await image.readAsBytes();
      final result = await _ocrService.scanPackageImage(image.path);
      if (!mounted) return;
      setState(() {
        _previewBytes = bytes;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось распознать упаковку: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Не найдено';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('OCR упаковки'),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _actionButton(
                    label: 'Камера',
                    icon: Icons.photo_camera_rounded,
                    onTap:
                        _isProcessing
                            ? null
                            : () => _pickAndProcess(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _actionButton(
                    label: 'Галерея',
                    icon: Icons.photo_library_rounded,
                    onTap:
                        _isProcessing
                            ? null
                            : () => _pickAndProcess(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (_isProcessing) _processingCard(),
            if (_error != null) _errorCard(_error!),
            if (_previewBytes != null) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Image.memory(
                  _previewBytes!,
                  height: 220,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 20),
            ],
            if (_result != null) _resultCard(_result!),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: const Row(
        children: [
          Icon(Icons.document_scanner_rounded, color: Colors.white, size: 34),
          SizedBox(width: 16),
          Expanded(
            child: Text(
              'Сканирование прихода по фото упаковки',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).cardColor,
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      icon: Icon(icon, color: const Color(0xFF10B981)),
      label: Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
    );
  }

  Widget _processingCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: const Row(
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Color(0xFF10B981),
            ),
          ),
          SizedBox(width: 14),
          Text(
            'Распознавание...',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color:
            Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF450A0A)
                : const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color:
              Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF991B1B)
                  : const Color(0xFFFECACA),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFDC2626)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color:
                    Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFFECACA)
                        : const Color(0xFF991B1B),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _resultCard(B2BOcrResult result) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.04,
            ),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Найденные данные',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w900,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          _fieldTile('Название', result.name ?? 'Не найдено'),
          _fieldTile('Категория', result.category ?? 'Не найдено'),
          _fieldTile('Дозировка', result.dosage ?? 'Не найдено'),
          _fieldTile('Упаковка', result.packageSize ?? 'Не найдено'),
          _fieldTile('Производитель', result.manufacturer ?? 'Не найдено'),
          _fieldTile('Серия', result.batchNumber ?? 'Не найдено'),
          _fieldTile('Штрих-код', result.barcode ?? 'Не найдено'),
          _fieldTile('Срок годности', _formatDate(result.expiryDate)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed:
                  result.hasUsefulData
                      ? () => Navigator.pop(context, result.toMap())
                      : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF10B981),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              icon: const Icon(Icons.check_rounded),
              label: const Text(
                'Заполнить форму',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
          if (result.rawText.isNotEmpty) ...[
            const SizedBox(height: 18),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              title: const Text(
                'Распознанный текст',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    result.rawText,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _fieldTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
