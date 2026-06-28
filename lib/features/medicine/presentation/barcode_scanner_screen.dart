import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/barcode_service.dart';

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController controller = MobileScannerController(
    formats: [BarcodeFormat.all],
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  late AnimationController _animationController;
  bool _isScanning = false; // To prevent multiple simultaneous lookups

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isScanning || !mounted) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isNotEmpty) {
      final String? code = barcodes.first.rawValue;
      if (code != null && code.isNotEmpty) {
        debugPrint('MOBILE_SCANNER: Detected $code');
        // Show a brief toast to confirm detection
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Обнаружен код: $code'),
            duration: const Duration(seconds: 1),
            behavior: SnackBarBehavior.floating,
          ),
        );
        _handleBarcode(code);
      }
    }
  }

  Future<void> _handleBarcode(String barcode) async {
    setState(() => _isScanning = true);

    _showLoadingDialog();

    try {
      final medicineInfo = await BarcodeService.lookupBarcode(
        barcode,
        allowSlowNetwork: false,
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      if (medicineInfo != null) {
        AnalyticsService.instance.trackFeature(
          'barcode_scanner',
          action: 'catalog_match',
        );
        debugPrint('DEBUG: Medicine found: ${medicineInfo['name']}');
        // Return result instead of navigating directly
        Navigator.pop(context, medicineInfo);
      } else {
        AnalyticsService.instance.trackFeature(
          'barcode_scanner',
          action: 'manual_fallback',
        );
        debugPrint('DEBUG: Medicine not found for barcode: $barcode');
        _showBarcodeDraftDialog(barcode);
      }
    } catch (e) {
      debugPrint('DEBUG: Error looking up barcode: $e');
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка при поиске: $e')));
        setState(() => _isScanning = false);
      }
    }
  }

  void _showLoadingDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.all(30),
                  color: Colors.white.withValues(alpha: 0.1),
                  child: const CircularProgressIndicator(
                    color: Color(0xFF6366F1),
                  ),
                ),
              ),
            ),
          ),
    );
  }

  void _showBarcodeDraftDialog(String barcode) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E1E2E),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Штрих-код считан',
              style: TextStyle(color: Colors.white),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Код $barcode сохранится в карточке. Если справочник не нашел название, досканируйте упаковку на следующем экране.',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                TextButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: barcode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Штрих-код скопирован')),
                    );
                  },
                  icon: const Icon(
                    Icons.copy_rounded,
                    size: 18,
                    color: Color(0xFF6366F1),
                  ),
                  label: const Text(
                    'Копировать код',
                    style: TextStyle(color: Color(0xFF6366F1)),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _isScanning = false);
                },
                child: const Text(
                  'Отмена',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF6366F1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // Close dialog
                  Navigator.pop(context, {
                    'barcode': barcode,
                    'category': 'Другое',
                    'source': 'Barcode only',
                    'needsPackageScan': true,
                    'isUnknown': true,
                    'lookupMessage':
                        'Справочник не нашел карточку. Сфотографируйте упаковку, чтобы распознать название, дозировку и срок.',
                  }); // Close scanner
                },
                child: const Text('Продолжить'),
              ),
            ],
          ),
    ).then((_) {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Scanner Layer
          MobileScanner(
            controller: controller,
            fit: BoxFit.cover,
            onDetect: _onDetect,
            errorBuilder: (context, error, child) {
              debugPrint('DEBUG: Scanner Error: ${error.errorCode}');
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.no_photography_outlined,
                      color: Colors.white54,
                      size: 80,
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Ошибка камеры: ${error.errorCode}',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Вернуться'),
                    ),
                  ],
                ),
              );
            },
          ),

          // 2. Custom Masked Overlay
          Positioned.fill(
            child: ColorFiltered(
              colorFilter: ColorFilter.mode(
                Colors.black.withValues(alpha: 0.7),
                BlendMode.srcOut,
              ),
              child: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      backgroundBlendMode: BlendMode.dstOut,
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 280,
                      height: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 3. Frame Corners & Animation Line
          Center(
            child: SizedBox(
              width: 280,
              height: 200,
              child: Stack(
                children: [
                  _buildCorner(0, 0),
                  _buildCorner(1, 0),
                  _buildCorner(0, 1),
                  _buildCorner(1, 1),

                  AnimatedBuilder(
                    animation: _animationController,
                    builder: (context, child) {
                      return Positioned(
                        top: 10 + (180 * _animationController.value),
                        left: 20,
                        right: 20,
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF6366F1,
                                ).withValues(alpha: 0.8),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                            gradient: const LinearGradient(
                              colors: [
                                Colors.transparent,
                                Color(0xFF6366F1),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),

          // 4. Header Controls
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildGlassButton(
                    icon: Icons.close,
                    onTap: () => Navigator.pop(context),
                  ),
                  Row(
                    children: [
                      // Hidden test button (for debugging)
                      if (kDebugMode)
                        _buildGlassButton(
                          icon: Icons.bug_report_outlined,
                          onTap: () {
                            const testBarcode = '4607027766347'; // Nurofen
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Тестовое сканирование: Нурофен'),
                              ),
                            );
                            _handleBarcode(testBarcode);
                          },
                        ),
                      if (kDebugMode) const SizedBox(width: 12),
                      ValueListenableBuilder<MobileScannerState>(
                        valueListenable: controller,
                        builder: (context, state, child) {
                          return _buildGlassButton(
                            icon:
                                state.torchState == TorchState.on
                                    ? Icons.flash_on
                                    : Icons.flash_off,
                            onTap: () => controller.toggleTorch(),
                            isActive: state.torchState == TorchState.on,
                          );
                        },
                      ),
                      const SizedBox(width: 12),
                      _buildGlassButton(
                        icon: Icons.flip_camera_ios,
                        onTap: () => controller.switchCamera(),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // 5. Bottom Instructions & Manual Entry
          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              children: [
                const Text(
                  'Наведите на штрих-код лекарства',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 32),
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: InkWell(
                      onTap: () {
                        Navigator.pop(context, {'manual': true});
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 32,
                          vertical: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.2),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.keyboard_outlined, color: Colors.white),
                            SizedBox(width: 12),
                            Text(
                              'Ввести вручную',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorner(double x, double y) {
    return Positioned(
      top: y == 0 ? 0 : null,
      bottom: y == 1 ? 0 : null,
      left: x == 0 ? 0 : null,
      right: x == 1 ? 0 : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          border: Border(
            top:
                y == 0
                    ? const BorderSide(color: Color(0xFF6366F1), width: 4)
                    : BorderSide.none,
            bottom:
                y == 1
                    ? const BorderSide(color: Color(0xFF6366F1), width: 4)
                    : BorderSide.none,
            left:
                x == 0
                    ? const BorderSide(color: Color(0xFF6366F1), width: 4)
                    : BorderSide.none,
            right:
                x == 1
                    ? const BorderSide(color: Color(0xFF6366F1), width: 4)
                    : BorderSide.none,
          ),
          borderRadius: BorderRadius.only(
            topLeft: x == 0 && y == 0 ? const Radius.circular(20) : Radius.zero,
            topRight:
                x == 1 && y == 0 ? const Radius.circular(20) : Radius.zero,
            bottomLeft:
                x == 0 && y == 1 ? const Radius.circular(20) : Radius.zero,
            bottomRight:
                x == 1 && y == 1 ? const Radius.circular(20) : Radius.zero,
          ),
        ),
      ),
    );
  }

  Widget _buildGlassButton({
    required IconData icon,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: InkWell(
          onTap: onTap,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: isActive ? Colors.yellow : Colors.white),
          ),
        ),
      ),
    );
  }
}
