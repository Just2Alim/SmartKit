import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/barcode_service.dart';
import '../data/b2b_inventory_repository.dart';
import '../data/b2b_locations_repository.dart';
import '../models/b2b_inventory_model.dart';
import '../models/b2b_location_model.dart';
import '../models/b2b_ocr_result.dart';

class B2BAddMedicineScreen extends StatefulWidget {
  final String? medicineId;

  const B2BAddMedicineScreen({super.key, this.medicineId});

  bool get isEditing => medicineId != null;

  @override
  State<B2BAddMedicineScreen> createState() => _B2BAddMedicineScreenState();
}

class _B2BAddMedicineScreenState extends State<B2BAddMedicineScreen> {
  final _repository = B2BInventoryRepository();
  final _locationsRepository = B2BLocationsRepository();

  final nameCtrl = TextEditingController();
  final stockCtrl = TextEditingController();
  final minStockCtrl = TextEditingController();
  final priceCtrl = TextEditingController();
  final manufacturerCtrl = TextEditingController();
  final barcodeCtrl = TextEditingController();
  final batchCtrl = TextEditingController();
  final dosageCtrl = TextEditingController();
  final packageSizeCtrl = TextEditingController();
  final descriptionCtrl = TextEditingController();
  final receiptQuantityCtrl = TextEditingController();

  String selectedCategory = 'Обезболивающее';
  String? selectedLocationId;
  DateTime? selectedExpiryDate;
  bool isLoading = false;
  bool isInitialLoading = false;
  List<B2BLocationModel> locations = [];
  B2BInventoryModel? editingItem;

  final categories = const [
    'Обезболивающее',
    'Жаропонижающее',
    'Антибиотик',
    'Витамины',
    'Противовоспалительное',
    'Антисептик',
    'Аллергия',
    'ЖКТ',
    'Сердце',
    'Сорбенты',
    'Противовирусное',
    'От простуды',
    'Другое',
  ];

  List<String> get _categoryOptions {
    final options = [...categories];
    if (!options.contains(selectedCategory)) {
      options.add(selectedCategory);
    }
    return options;
  }

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    setState(() => isInitialLoading = true);
    try {
      await _fetchLocations();
      if (widget.medicineId != null) {
        await _loadItem(widget.medicineId!);
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Не удалось загрузить часть данных: $e');
      }
    } finally {
      if (mounted) {
        setState(() => isInitialLoading = false);
      }
    }
  }

  Future<void> _fetchLocations() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    final locs = await _locationsRepository
        .getLocationsByUser(user.id)
        .first
        .timeout(const Duration(seconds: 4), onTimeout: () => []);
    if (!mounted) return;

    setState(() {
      locations = locs;
      selectedLocationId = locs.isEmpty ? null : locs.first.id;
    });
  }

  Future<void> _loadItem(String itemId) async {
    final item = await _repository.getItemById(itemId);
    if (!mounted) return;

    if (item == null) {
      _showSnack('Товар не найден');
      return;
    }

    setState(() {
      editingItem = item;
      nameCtrl.text = item.name;
      stockCtrl.text = item.stock.toString();
      minStockCtrl.text = item.minStock.toString();
      priceCtrl.text = item.price.toString();
      manufacturerCtrl.text = item.manufacturer ?? '';
      barcodeCtrl.text = item.barcode ?? '';
      batchCtrl.text = item.batchNumber ?? '';
      dosageCtrl.text = item.dosage ?? '';
      packageSizeCtrl.text = item.packageSize ?? '';
      descriptionCtrl.text = item.description ?? '';
      selectedCategory =
          item.category.isEmpty ? selectedCategory : item.category;
      selectedExpiryDate = item.expiryDate;
      selectedLocationId =
          locations.any((loc) => loc.id == item.locationId)
              ? item.locationId
              : null;
    });
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    stockCtrl.dispose();
    minStockCtrl.dispose();
    priceCtrl.dispose();
    manufacturerCtrl.dispose();
    barcodeCtrl.dispose();
    batchCtrl.dispose();
    dosageCtrl.dispose();
    packageSizeCtrl.dispose();
    descriptionCtrl.dispose();
    receiptQuantityCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanPackage() async {
    final result = await Navigator.pushNamed(context, AppRoutes.b2bPackageOcr);
    if (result is! Map<String, dynamic>) return;

    AnalyticsService.instance.trackFeature(
      'b2b_package_ocr',
      action: 'result_applied',
    );
    var merged = Map<String, dynamic>.from(result);
    final currentBarcode =
        (merged['barcode']?.toString().trim().isNotEmpty ?? false)
            ? merged['barcode'].toString().trim()
            : barcodeCtrl.text.trim();

    if (currentBarcode.isNotEmpty) {
      final lookup = await BarcodeService.lookupBarcode(
        currentBarcode,
        allowSlowNetwork: false,
      );
      if (lookup != null) {
        merged = {
          ...lookup,
          ...merged,
          'barcode': currentBarcode,
          'source': _combineSources(lookup['source'], merged['source']),
        };
      } else {
        merged['barcode'] = currentBarcode;
      }
    }

    _applyScanResult(merged);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Данные упаковки добавлены в форму')),
    );
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.pushNamed(context, AppRoutes.scanBarcode);
    if (!mounted || result == null || result is! Map<String, dynamic>) return;

    _applyScanResult(result);
    AnalyticsService.instance.trackFeature(
      'b2b_barcode_scanner',
      action: 'result_applied',
      properties: {'needs_package_scan': result['needsPackageScan'] == true},
    );

    if (result['needsPackageScan'] == true) {
      await _offerPackageScan(
        result['lookupMessage']?.toString() ??
            'Штрих-код считан. Чтобы заполнить дозировку, срок и серию, сфотографируйте упаковку.',
      );
    }
  }

  Future<void> _offerPackageScan(String message) async {
    final shouldScan = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder:
          (context) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Досканировать упаковку?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  Text(message),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.document_scanner_rounded),
                      label: const Text('Сфотографировать упаковку'),
                    ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Оставить как есть'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );

    if (shouldScan == true && mounted) {
      await _scanPackage();
    }
  }

  void _applyScanResult(Map<String, dynamic> result) {
    final ocr = B2BOcrResult.fromMap(result);

    setState(() {
      _fill(nameCtrl, ocr.name ?? result['name']);
      _fill(manufacturerCtrl, ocr.manufacturer ?? result['brand']);
      _fill(barcodeCtrl, ocr.barcode ?? result['barcode']);
      _fill(batchCtrl, ocr.batchNumber ?? result['batchNumber']);
      _fill(dosageCtrl, ocr.dosage ?? result['dosage']);
      _fill(packageSizeCtrl, ocr.packageSize ?? result['packageSize']);
      _fill(descriptionCtrl, ocr.description ?? result['description']);

      final category = ocr.category ?? result['category']?.toString().trim();
      if (category != null && category.isNotEmpty) {
        selectedCategory = category;
      }

      selectedExpiryDate =
          ocr.expiryDate ??
          _parseDate(result['expiryDate']) ??
          selectedExpiryDate;

      final suggestedStock =
          ocr.suggestedStock ?? _intFrom(result['suggestedStock']) ?? 1;
      if (stockCtrl.text.trim().isEmpty) {
        stockCtrl.text = suggestedStock.toString();
      }

      final suggestedMinStock =
          ocr.suggestedMinStock ?? _intFrom(result['suggestedMinStock']);
      if (suggestedMinStock != null && minStockCtrl.text.trim().isEmpty) {
        minStockCtrl.text = suggestedMinStock.toString();
      }

      final suggestedPrice =
          ocr.suggestedPrice ?? _intFrom(result['suggestedPrice']);
      if (suggestedPrice != null && priceCtrl.text.trim().isEmpty) {
        priceCtrl.text = suggestedPrice.toString();
      }
    });
  }

  void _fill(TextEditingController controller, dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return;
    if (!widget.isEditing || controller.text.trim().isEmpty) {
      controller.text = text;
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  int? _intFrom(dynamic value) {
    if (value is num) return value.toInt();
    if (value == null) return null;
    return int.tryParse(value.toString());
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

  Future<void> pickExpiryDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate:
          selectedExpiryDate ?? DateTime(now.year + 1, now.month, now.day),
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 10),
    );

    if (result != null) {
      setState(() => selectedExpiryDate = result);
    }
  }

  Future<void> saveItem() async {
    final user = Supabase.instance.client.auth.currentUser;
    final ownerId = editingItem?.userId ?? user?.id;

    if (ownerId == null) {
      _showSnack('Пользователь не найден');
      return;
    }

    if (nameCtrl.text.trim().isEmpty) {
      _showSnack('Укажите название товара');
      return;
    }

    final stock = int.tryParse(stockCtrl.text.trim()) ?? 1;
    final minStock = int.tryParse(minStockCtrl.text.trim()) ?? 4;
    final price = int.tryParse(priceCtrl.text.trim()) ?? 0;

    if (stock < 0 || minStock < 0 || price < 0) {
      _showSnack('Числовые значения не могут быть отрицательными');
      return;
    }

    if (stockCtrl.text.trim().isEmpty ||
        minStockCtrl.text.trim().isEmpty ||
        priceCtrl.text.trim().isEmpty) {
      setState(() {
        stockCtrl.text = stock.toString();
        minStockCtrl.text = minStock.toString();
        priceCtrl.text = price.toString();
      });
    }

    setState(() => isLoading = true);

    try {
      final now = DateTime.now();
      final item = B2BInventoryModel(
        id: editingItem?.id ?? '',
        userId: ownerId,
        name: nameCtrl.text.trim(),
        category: selectedCategory,
        description: _optional(descriptionCtrl.text),
        manufacturer: _optional(manufacturerCtrl.text),
        barcode: _optional(barcodeCtrl.text),
        batchNumber: _optional(batchCtrl.text),
        dosage: _optional(dosageCtrl.text),
        packageSize: _optional(packageSizeCtrl.text),
        stock: stock,
        minStock: minStock,
        price: price,
        locationId: selectedLocationId,
        expiryDate: selectedExpiryDate,
        createdAt: editingItem?.createdAt ?? now,
        updatedAt: widget.isEditing ? now : null,
      );

      if (widget.isEditing) {
        await _repository.updateItem(item);
      } else {
        await _repository.addItem(item);
      }

      if (item.barcode != null) {
        await BarcodeService.rememberBarcode(
          barcode: item.barcode!,
          medicineData: {
            'name': item.name,
            'category': item.category,
            'manufacturer': item.manufacturer,
            'dosage': item.dosage,
            'packageSize': item.packageSize,
            'batchNumber': item.batchNumber,
            'source': 'B2B inventory',
          },
        );
      }

      if (!mounted) return;
      _showSnack(widget.isEditing ? 'Товар обновлен' : 'Товар добавлен');
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      _showSnack('Ошибка сохранения: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Future<void> receiveStock() async {
    if (editingItem == null) return;

    final quantity = int.tryParse(receiptQuantityCtrl.text.trim());
    if (quantity == null || quantity <= 0) {
      _showSnack('Укажите количество прихода');
      return;
    }

    setState(() => isLoading = true);

    try {
      await _repository.receiveStock(
        itemId: editingItem!.id,
        quantity: quantity,
        batchNumber: _optional(batchCtrl.text),
        expiryDate: selectedExpiryDate,
        source: barcodeCtrl.text.trim().isEmpty ? 'manual' : 'ocr_or_barcode',
      );

      final newStock =
          (int.tryParse(stockCtrl.text.trim()) ?? editingItem!.stock) +
          quantity;
      setState(() {
        stockCtrl.text = newStock.toString();
        receiptQuantityCtrl.clear();
      });

      if (!mounted) return;
      _showSnack('Приход добавлен: +$quantity шт.');
    } catch (e) {
      if (!mounted) return;
      _showSnack('Ошибка прихода: $e');
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  void _showSnack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Выбрать дату';
    return '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w800,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required String hint,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(label),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(hintText: hint),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _section({
    required String title,
    required List<Widget> children,
    IconData? icon,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha:
                  Theme.of(context).brightness == Brightness.dark ? 0.22 : 0.04,
            ),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: const Color(0xFF10B981)),
                const SizedBox(width: 10),
              ],
              Text(
                title,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isEditing ? 'Редактировать товар' : 'Добавить товар';

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: const Color(0xFF10B981),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            onPressed: isLoading ? null : _scanBarcode,
            icon: const Icon(Icons.qr_code_scanner_rounded),
            tooltip: 'Сканировать штрих-код',
          ),
          IconButton(
            onPressed: isLoading ? null : _scanPackage,
            icon: const Icon(Icons.document_scanner_rounded),
            tooltip: 'OCR упаковки',
          ),
        ],
      ),
      body: SafeArea(
        child:
            isInitialLoading
                ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF10B981)),
                )
                : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  children: [
                    _ocrBanner(),
                    const SizedBox(height: 18),
                    _section(
                      title: 'Карточка товара',
                      icon: Icons.medication_rounded,
                      children: [
                        _textField(
                          label: 'Название',
                          controller: nameCtrl,
                          hint: 'Например: Парацетамол',
                        ),
                        _label('Категория'),
                        _dropdown(
                          value: selectedCategory,
                          items: _categoryOptions,
                          onChanged: (value) {
                            if (value == null) return;
                            setState(() => selectedCategory = value);
                          },
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          label: 'Дозировка',
                          controller: dosageCtrl,
                          hint: 'Например: 500 мг',
                        ),
                        _textField(
                          label: 'Упаковка',
                          controller: packageSizeCtrl,
                          hint: 'Например: №20 таблеток',
                        ),
                        _textField(
                          label: 'Описание для магазина',
                          controller: descriptionCtrl,
                          hint: 'Короткое описание товара',
                          maxLines: 3,
                        ),
                      ],
                    ),
                    _section(
                      title: 'Партия и поставка',
                      icon: Icons.fact_check_rounded,
                      children: [
                        _textField(
                          label: 'Производитель',
                          controller: manufacturerCtrl,
                          hint: 'Например: Bayer',
                        ),
                        _textField(
                          label: 'Штрих-код',
                          controller: barcodeCtrl,
                          hint: 'EAN/GTIN',
                          keyboardType: TextInputType.number,
                        ),
                        _textField(
                          label: 'Серия партии',
                          controller: batchCtrl,
                          hint: 'Например: A24B901',
                        ),
                        _label('Срок годности'),
                        InkWell(
                          onTap: pickExpiryDate,
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color:
                                    Theme.of(
                                      context,
                                    ).colorScheme.outlineVariant,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 18,
                                  color:
                                      Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  _formatDate(selectedExpiryDate),
                                  style: TextStyle(
                                    color:
                                        selectedExpiryDate == null
                                            ? Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant
                                            : Theme.of(
                                              context,
                                            ).colorScheme.onSurface,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    _section(
                      title: 'Склад и цена',
                      icon: Icons.warehouse_rounded,
                      children: [
                        _label('Локация хранения'),
                        _locationDropdown(),
                        const SizedBox(height: 16),
                        _textField(
                          label: 'Остаток на складе',
                          controller: stockCtrl,
                          hint: 'Например: 100',
                          keyboardType: TextInputType.number,
                        ),
                        _textField(
                          label: 'Минимальный остаток',
                          controller: minStockCtrl,
                          hint: 'Например: 10',
                          keyboardType: TextInputType.number,
                        ),
                        _textField(
                          label: 'Цена, ₸',
                          controller: priceCtrl,
                          hint: 'Например: 2500 или 0, если заполните позже',
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    ),
                    if (widget.isEditing) _receiptSection(),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: isLoading ? null : saveItem,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        child:
                            isLoading
                                ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                : Text(
                                  widget.isEditing
                                      ? 'Сохранить изменения'
                                      : 'Сохранить товар',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                      ),
                    ),
                  ],
                ),
      ),
    );
  }

  Widget _ocrBanner() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: isLoading ? null : _scanBarcode,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF064E3B) : const Color(0xFFECFDF5),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF10B981) : const Color(0xFFA7F3D0),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.document_scanner_rounded,
              color: Color(0xFF10B981),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Сканировать штрих-код или упаковку для автозаполнения',
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF065F46),
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              onPressed: isLoading ? null : _scanPackage,
              icon: const Icon(
                Icons.document_scanner_rounded,
                color: Color(0xFF10B981),
              ),
              tooltip: 'Фото упаковки',
            ),
            const Icon(Icons.arrow_forward_rounded, color: Color(0xFF10B981)),
          ],
        ),
      ),
    );
  }

  Widget _dropdown({
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          items:
              items
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _locationDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value:
              locations.any((loc) => loc.id == selectedLocationId)
                  ? selectedLocationId
                  : null,
          isExpanded: true,
          hint: const Text('Без локации'),
          items: [
            const DropdownMenuItem<String>(
              value: null,
              child: Text('Без локации'),
            ),
            ...locations.map(
              (loc) => DropdownMenuItem(value: loc.id, child: Text(loc.name)),
            ),
          ],
          onChanged: (value) => setState(() => selectedLocationId = value),
        ),
      ),
    );
  }

  Widget _receiptSection() {
    return _section(
      title: 'Быстрый приход',
      icon: Icons.add_box_rounded,
      children: [
        _textField(
          label: 'Количество прихода',
          controller: receiptQuantityCtrl,
          hint: 'Например: 50',
          keyboardType: TextInputType.number,
        ),
        SizedBox(
          width: double.infinity,
          height: 52,
          child: OutlinedButton.icon(
            onPressed: isLoading ? null : receiveStock,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF10B981),
              side: const BorderSide(color: Color(0xFF10B981)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.playlist_add_check_rounded),
            label: const Text(
              'Добавить приход к остатку',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ),
      ],
    );
  }
}
