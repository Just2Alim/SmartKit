import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/analytics_service.dart';
import '../../../core/services/barcode_service.dart';
import '../../family/data/family_repository.dart';
import '../../family/models/family_member_model.dart';
import '../../b2b/inventory/data/b2b_ocr_service.dart';
import '../data/medicine_repository.dart';
import '../domain/medicine_quick_parser.dart';
import '../models/medicine_model.dart';
import '../../../core/router/app_routes.dart';

class AddMedicineScreen extends StatefulWidget {
  final String? preselectedMemberId;
  final String? initialName;
  final String? initialCategory;
  final Map<String, dynamic>? initialData;

  const AddMedicineScreen({
    super.key,
    this.preselectedMemberId,
    this.initialName,
    this.initialCategory,
    this.initialData,
  });

  @override
  State<AddMedicineScreen> createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _repository = MedicineRepository();
  final _familyRepository = FamilyRepository();

  final nameCtrl = TextEditingController();
  final dosageCtrl = TextEditingController();
  final quantityCtrl = TextEditingController();
  final notesCtrl = TextEditingController();
  final barcodeCtrl = TextEditingController();
  final manufacturerCtrl = TextEditingController();
  final packageSizeCtrl = TextEditingController();
  final batchCtrl = TextEditingController();
  final quickCtrl = TextEditingController();
  final formCtrl = TextEditingController();
  final unitCtrl = TextEditingController(text: 'шт');
  final storageCtrl = TextEditingController();
  final lowStockCtrl = TextEditingController(text: '3');

  String selectedCategory = 'Обезболивающее';
  DateTime? selectedDate;
  DateTime? openedDate;
  bool isLoading = false;
  bool isScanningPackage = false;
  String? scanSource;

  String selectedOwner = 'me';
  List<FamilyMemberModel> familyMembers = [];

  final ImagePicker _imagePicker = ImagePicker();
  final B2BOcrService _ocrService = B2BOcrService();

  final categories = const [
    'Обезболивающее',
    'Жаропонижающее',
    'Антибиотик',
    'Витамины',
    'Противовоспалительное',
    'Антисептик',
    'От аллергии',
    'ЖКТ',
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
    _loadFamilyMembers();

    if (widget.preselectedMemberId != null) {
      selectedOwner = widget.preselectedMemberId!;
    }

    if (widget.initialName != null) {
      nameCtrl.text = widget.initialName!;
    }

    if (widget.initialCategory != null &&
        widget.initialCategory!.trim().isNotEmpty) {
      selectedCategory = widget.initialCategory!;
    }

    if (widget.initialData != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (widget.initialData!['openBulk'] == true) {
          _showBulkAddSheet();
        } else {
          _applyScanResult(widget.initialData!);
        }
      });
    }
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    dosageCtrl.dispose();
    quantityCtrl.dispose();
    notesCtrl.dispose();
    barcodeCtrl.dispose();
    manufacturerCtrl.dispose();
    packageSizeCtrl.dispose();
    batchCtrl.dispose();
    quickCtrl.dispose();
    formCtrl.dispose();
    unitCtrl.dispose();
    storageCtrl.dispose();
    lowStockCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadFamilyMembers() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _familyRepository.getFamilyMembersByUser(user.id).first.then((members) {
      if (!mounted) return;
      setState(() {
        familyMembers = members;
      });
    });
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 10),
    );

    if (result != null) {
      setState(() {
        selectedDate = result;
      });
    }
  }

  Future<void> pickOpenedDate() async {
    final now = DateTime.now();
    final result = await showDatePicker(
      context: context,
      initialDate: openedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );

    if (result != null) {
      setState(() {
        openedDate = result;
      });
    }
  }

  void _applyQuickInput() {
    final draft = MedicineQuickParser.parseLine(quickCtrl.text);
    final name = draft['name']?.toString().trim();
    if (name == null || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Напишите лекарство одной строкой')),
      );
      return;
    }

    _applyScanResult(draft);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Поля заполнены из быстрого ввода')),
    );
  }

  Future<void> _showBulkAddSheet() async {
    final controller = TextEditingController();
    final text = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder:
          (context) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              8,
              20,
              20 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Добавить списком',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Пример: Парацетамол 500мг №20 до 12.2026',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: controller,
                    minLines: 5,
                    maxLines: 9,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText:
                          'Парацетамол 500мг №20 до 12.2026\nСупрастин №20 до 03.2027\nСмекта 10 саше',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton.icon(
                      onPressed: () => Navigator.pop(context, controller.text),
                      icon: const Icon(Icons.playlist_add_check_rounded),
                      label: const Text('Разобрать и сохранить'),
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
    controller.dispose();

    if (text == null) return;
    final drafts = MedicineQuickParser.parseBulk(text);
    if (drafts.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не получилось найти лекарства в списке')),
      );
      return;
    }

    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text('Сохранить ${drafts.length} позиций?'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...drafts.take(5).map((draft) {
                  final dosage = draft['dosage']?.toString();
                  final quantity = draft['quantity']?.toString() ?? '1';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '${draft['name']} ${dosage ?? ''} - $quantity ${draft['unitLabel'] ?? 'шт'}',
                    ),
                  );
                }),
                if (drafts.length > 5)
                  Text('И еще ${drafts.length - 5} позиций...'),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Сохранить'),
              ),
            ],
          ),
    );

    if (confirm == true) {
      await _saveDrafts(drafts);
    }
  }

  Future<void> _saveDrafts(List<Map<String, dynamic>> drafts) async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пользователь не найден')));
      return;
    }

    setState(() => isLoading = true);

    try {
      final medicines =
          drafts
              .map((draft) {
                final quantity =
                    int.tryParse(draft['quantity']?.toString() ?? '') ?? 1;
                return MedicineModel(
                  id: '',
                  userId: user.id,
                  familyMemberId: selectedOwner == 'me' ? null : selectedOwner,
                  name: draft['name']?.toString().trim() ?? '',
                  dosage: draft['dosage']?.toString().trim() ?? '',
                  quantity: quantity,
                  category:
                      draft['category']?.toString().trim() ?? selectedCategory,
                  notes: null,
                  expiryDate: _parseDate(draft['expiryDate']),
                  createdAt: DateTime.now(),
                  packageSize: draft['packageSize']?.toString(),
                  scanSource: draft['source']?.toString(),
                  form: draft['form']?.toString(),
                  unitLabel: draft['unitLabel']?.toString() ?? 'шт',
                  storagePlace:
                      draft['storagePlace']?.toString() ??
                      _optional(storageCtrl.text),
                  lowStockThreshold:
                      int.tryParse(lowStockCtrl.text.trim()) ?? 3,
                  initialQuantity: quantity,
                );
              })
              .where((medicine) => medicine.name.isNotEmpty)
              .toList();

      await _repository.addMedicines(medicines);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Сохранено: ${medicines.length} позиций')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _scanBarcode() async {
    final result = await Navigator.pushNamed(context, AppRoutes.scanBarcode);
    if (!mounted || result == null || result is! Map<String, dynamic>) return;

    _applyScanResult(result);
    AnalyticsService.instance.trackFeature(
      'barcode_scanner',
      action: 'result_applied',
      properties: {'needs_package_scan': result['needsPackageScan'] == true},
    );

    if (result['needsPackageScan'] == true) {
      await _offerPackageScan(
        result['lookupMessage']?.toString() ??
            'Для дозировки и срока годности лучше досканировать упаковку.',
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
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                      child: const Text('Заполню вручную'),
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

  Future<void> _scanPackage() async {
    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR упаковки доступен в мобильной сборке приложения'),
        ),
      );
      return;
    }

    setState(() => isScanningPackage = true);
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.camera,
        imageQuality: 84,
        maxWidth: 1500,
      );
      if (image == null) return;

      final ocr = await _ocrService.scanPackageImage(image.path);
      final ocrMap = ocr.toMap();
      AnalyticsService.instance.trackFeature(
        'package_ocr',
        action: 'completed',
        properties: {'has_useful_data': ocr.hasUsefulData},
      );

      Map<String, dynamic> merged = {
        'barcode':
            barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
        'source': 'OCR упаковки',
        ...ocrMap,
      };

      final barcode = (ocr.barcode ?? barcodeCtrl.text).trim();
      if (barcode.isNotEmpty) {
        final lookup = await BarcodeService.lookupBarcode(
          barcode,
          allowSlowNetwork: false,
        );
        if (lookup != null) {
          merged.removeWhere((_, value) => value == null || value == '');
          merged = {
            ...lookup,
            ...merged,
            'barcode': barcode,
            'source': '${lookup['source'] ?? 'Barcode'} + OCR упаковки',
          };
        }
      }

      if (!mounted) return;

      _applyScanResult(merged);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ocr.hasUsefulData
                ? 'Упаковка распознана, проверьте поля перед сохранением'
                : 'Текст не распознан. Попробуйте фото ближе и ровнее',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка OCR: $e')));
    } finally {
      if (mounted) setState(() => isScanningPackage = false);
    }
  }

  void _applyScanResult(Map<String, dynamic> result) {
    setState(() {
      _fill(nameCtrl, result['name']);
      _fill(dosageCtrl, result['dosage']);
      _fill(barcodeCtrl, result['barcode']);
      _fill(manufacturerCtrl, result['manufacturer'] ?? result['brand']);
      _fill(packageSizeCtrl, result['packageSize']);
      _fill(batchCtrl, result['batchNumber']);
      _fill(formCtrl, result['form']);
      _fill(unitCtrl, result['unitLabel']);
      _fill(storageCtrl, result['storagePlace']);
      _fill(lowStockCtrl, result['lowStockThreshold']);
      _fill(notesCtrl, result['notes'] ?? result['description']);

      final category = result['category']?.toString().trim();
      if (category != null && category.isNotEmpty) {
        selectedCategory = category;
      }

      final expiry = _parseDate(result['expiryDate']);
      if (expiry != null) selectedDate = expiry;

      final quantity =
          int.tryParse(result['quantity']?.toString() ?? '') ??
          _extractQuantity(result['packageSize']);
      if (quantity != null && quantityCtrl.text.trim().isEmpty) {
        quantityCtrl.text = quantity.toString();
      }

      scanSource = result['source']?.toString();
    });
  }

  void _fill(TextEditingController controller, dynamic value) {
    final text = value?.toString().trim();
    if (text == null || text.isEmpty) return;
    controller.text = text;
  }

  DateTime? _parseDate(dynamic value) {
    if (value is DateTime) return value;
    if (value == null) return null;
    return DateTime.tryParse(value.toString());
  }

  int? _extractQuantity(dynamic value) {
    final text = value?.toString() ?? '';
    final match = RegExp(r'\d{1,4}').firstMatch(text);
    if (match == null) return null;
    return int.tryParse(match.group(0) ?? '');
  }

  String? _optional(String text) {
    final value = text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> saveMedicine() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пользователь не найден')));
      return;
    }

    if (nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажите название лекарства')),
      );
      return;
    }

    final quantity =
        quantityCtrl.text.trim().isEmpty
            ? 1
            : int.tryParse(quantityCtrl.text.trim());
    if (quantity == null || quantity < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Количество должно быть числом не меньше нуля'),
        ),
      );
      return;
    }

    final lowStockThreshold = int.tryParse(lowStockCtrl.text.trim()) ?? 3;

    setState(() => isLoading = true);

    try {
      final medicine = MedicineModel(
        id: '',
        userId: user.id,
        familyMemberId: selectedOwner == 'me' ? null : selectedOwner,
        name: nameCtrl.text.trim(),
        dosage: dosageCtrl.text.trim(),
        quantity: quantity,
        category: selectedCategory,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        expiryDate: selectedDate,
        createdAt: DateTime.now(),
        barcode: _optional(barcodeCtrl.text),
        manufacturer: _optional(manufacturerCtrl.text),
        packageSize: _optional(packageSizeCtrl.text),
        batchNumber: _optional(batchCtrl.text),
        scanSource: scanSource,
        form: _optional(formCtrl.text),
        unitLabel: _optional(unitCtrl.text) ?? 'шт',
        storagePlace: _optional(storageCtrl.text),
        lowStockThreshold: lowStockThreshold < 0 ? 3 : lowStockThreshold,
        initialQuantity: quantity,
        openedAt: openedDate,
      );

      await _repository.addMedicine(medicine);

      if (medicine.barcode != null) {
        await BarcodeService.rememberBarcode(
          barcode: medicine.barcode!,
          medicineData: {
            'name': medicine.name,
            'category': medicine.category,
            'manufacturer': medicine.manufacturer,
            'dosage': medicine.dosage,
            'packageSize': medicine.packageSize,
            'batchNumber': medicine.batchNumber,
            'source': medicine.scanSource,
          },
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Лекарство сохранено')));

      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка сохранения: $e')));
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
    );
  }

  Widget _buildQuickEntryCard() {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bolt_rounded, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Быстрое добавление',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: quickCtrl,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _applyQuickInput(),
            decoration: const InputDecoration(
              hintText: 'Парацетамол 500мг №20 до 12.2026',
              prefixIcon: Icon(Icons.edit_note_rounded),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : _applyQuickInput,
                  icon: const Icon(Icons.auto_fix_high_rounded),
                  label: const Text('Заполнить'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: isLoading ? null : _showBulkAddSheet,
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: const Text('Списком'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ownerItems = <DropdownMenuItem<String>>[
      const DropdownMenuItem(value: 'me', child: Text('Для меня')),
      ...familyMembers.map(
        (member) => DropdownMenuItem(
          value: member.id,
          child: Text('${member.name} (${member.relation})'),
        ),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Добавить лекарство')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Для кого'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedOwner,
                    isExpanded: true,
                    items: ownerItems,
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedOwner = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _buildQuickEntryCard(),
              const SizedBox(height: 20),

              _label('Название'),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  hintText: 'Например: Парацетамол',
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    onPressed: isLoading ? null : _scanBarcode,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed:
                      isLoading || isScanningPackage ? null : _scanPackage,
                  icon:
                      isScanningPackage
                          ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.document_scanner_rounded),
                  label: Text(
                    isScanningPackage
                        ? 'Распознаю упаковку...'
                        : 'AI OCR упаковки',
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Дозировка'),
              TextField(
                controller: dosageCtrl,
                decoration: const InputDecoration(hintText: 'Например: 500 мг'),
              ),
              const SizedBox(height: 16),

              _label('Количество'),
              TextField(
                controller: quantityCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Например: 20'),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Форма'),
                        TextField(
                          controller: formCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Таблетки, сироп, капли',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Ед. учета'),
                        TextField(
                          controller: unitCtrl,
                          decoration: const InputDecoration(hintText: 'шт'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Место хранения'),
                        TextField(
                          controller: storageCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Домашняя аптечка, холодильник',
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Мин. остаток'),
                        TextField(
                          controller: lowStockCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(hintText: '3'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _label('Категория'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedCategory,
                    isExpanded: true,
                    items:
                        _categoryOptions
                            .map(
                              (category) => DropdownMenuItem(
                                value: category,
                                child: Text(category),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedCategory = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Срок годности'),
              InkWell(
                onTap: pickDate,
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
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        selectedDate == null
                            ? 'Выбрать дату'
                            : '${selectedDate!.day.toString().padLeft(2, '0')}.${selectedDate!.month.toString().padLeft(2, '0')}.${selectedDate!.year}',
                        style: TextStyle(
                          color:
                              selectedDate == null
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant
                                  : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Дата вскрытия'),
              InkWell(
                onTap: pickOpenedDate,
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
                      color: Theme.of(context).colorScheme.outlineVariant,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.lock_open_rounded,
                        size: 18,
                        color: Color(0xFF6B7280),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        openedDate == null
                            ? 'Не указано'
                            : '${openedDate!.day.toString().padLeft(2, '0')}.${openedDate!.month.toString().padLeft(2, '0')}.${openedDate!.year}',
                        style: TextStyle(
                          color:
                              openedDate == null
                                  ? Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant
                                  : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Данные сканирования'),
              TextField(
                controller: barcodeCtrl,
                decoration: const InputDecoration(
                  hintText: 'Штрих-код',
                  prefixIcon: Icon(Icons.qr_code_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: manufacturerCtrl,
                decoration: const InputDecoration(
                  hintText: 'Производитель',
                  prefixIcon: Icon(Icons.factory_rounded),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: packageSizeCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Упаковка, напр. №20',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: batchCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Серия/партия',
                      ),
                    ),
                  ),
                ],
              ),
              if (scanSource != null) ...[
                const SizedBox(height: 10),
                Text(
                  'Источник: $scanSource',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 16),

              _label('Заметки'),
              TextField(
                controller: notesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Дополнительная информация...',
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveMedicine,
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
                          : const Text(
                            'Сохранить',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
