import 'package:flutter/material.dart';
import 'package:smartkit/core/services/b2b_ai_service.dart';
import 'package:smartkit/core/services/analytics_service.dart';
import '../../models/b2b_inventory_model.dart';
import '../../models/b2b_sale_model.dart';

import '../../models/b2b_location_model.dart';

class B2BAiInsightsWidget extends StatefulWidget {
  final List<B2BInventoryModel> inventory;
  final List<B2BSaleModel> sales;
  final List<B2BLocationModel> locations;

  const B2BAiInsightsWidget({
    super.key,
    required this.inventory,
    required this.sales,
    required this.locations,
  });

  @override
  State<B2BAiInsightsWidget> createState() => _B2BAiInsightsWidgetState();
}

class _B2BAiInsightsWidgetState extends State<B2BAiInsightsWidget> {
  String? _analysis;
  bool _isLoading = false;

  Future<void> _runAnalysis() async {
    AnalyticsService.instance.trackFeature(
      'b2b_ai_analysis',
      action: 'requested',
    );
    setState(() {
      _isLoading = true;
    });

    try {
      B2BAiService.instance.init(
        widget.inventory,
        widget.sales,
        widget.locations,
      );
      final result = await B2BAiService.instance.getFullBusinessAnalysis();
      if (!mounted) return;
      setState(() {
        _analysis = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _analysis =
            'AI-аналитика временно недоступна. Проверьте остатки, сроки годности и продажи вручную.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 120,
              color: const Color(0xFF10B981).withOpacity(0.05),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: const Color(0xFF10B981).withOpacity(0.3),
                        ),
                      ),
                      child: const Icon(
                        Icons.auto_awesome_rounded,
                        color: Color(0xFF10B981),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Аналитик',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          Text(
                            'Умный анализ вашего склада',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_analysis != null && !_isLoading)
                      IconButton(
                        onPressed: _runAnalysis,
                        icon: const Icon(
                          Icons.refresh_rounded,
                          color: Colors.white54,
                          size: 20,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                if (_analysis == null && !_isLoading)
                  _buildEmptyState()
                else if (_isLoading)
                  _buildLoadingState()
                else
                  _buildAnalysisContent(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Готов провести глубокий анализ текущих остатков и динамики продаж.',
          style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _runAnalysis,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bolt_rounded, size: 20),
                SizedBox(width: 8),
                Text(
                  'Сформировать отчёт',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingState() {
    return Column(
      children: [
        const Center(
          child: SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: Color(0xFF10B981),
              strokeWidth: 3,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'ИИ анализирует данные...',
          style: TextStyle(
            color: Color(0xFF10B981).withOpacity(0.8),
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAnalysisContent() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Text(
        _analysis!,
        style: const TextStyle(
          color: Color(0xFFE2E8F0),
          fontSize: 14,
          height: 1.6,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
