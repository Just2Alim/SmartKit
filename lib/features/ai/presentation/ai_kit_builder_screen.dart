import 'package:flutter/material.dart';

class AiKitBuilderScreen extends StatefulWidget {
  const AiKitBuilderScreen({super.key});

  @override
  State<AiKitBuilderScreen> createState() => _AiKitBuilderScreenState();
}

class _AiKitBuilderScreenState extends State<AiKitBuilderScreen> {
  String selectedKit = 'Домашняя аптечка';

  final Map<String, List<String>> kitTemplates = {
    'Домашняя аптечка': [
      'Обезболивающее',
      'Жаропонижающее',
      'Антисептик',
      'Пластыри',
      'Бинт',
      'Термометр',
      'Средство от аллергии',
    ],
    'Аптечка в поездку': [
      'Обезболивающее',
      'Жаропонижающее',
      'Антисептик',
      'Пластыри',
      'Средство от укачивания',
      'Таблетки для желудка',
      'Салфетки/маски',
    ],
    'Для ребёнка': [
      'Детское жаропонижающее',
      'Термометр',
      'Антисептик',
      'Пластыри',
      'Сироп от кашля',
      'Капли/спрей по возрасту',
      'Средство от аллергии',
    ],
    'Минимальный базовый набор': [
      'Парацетамол или аналог',
      'Антисептик',
      'Пластыри',
      'Бинт',
      'Термометр',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final currentItems = kitTemplates[selectedKit] ?? [];

    return Scaffold(

      appBar: AppBar(title: const Text('AI сбор аптечки')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF60A5FA), Color(0xFF2563EB)],
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                      color: const Color(0xFF2563EB).withOpacity(0.25),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: const Icon(
                        Icons.medical_services_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 16),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Конструктор аптечки',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Выбери сценарий и получи базовый набор',
                            style: TextStyle(fontSize: 13, color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Тип аптечки',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedKit,
                    isExpanded: true,
                    items:
                        kitTemplates.keys
                            .map(
                              (kit) => DropdownMenuItem(
                                value: kit,
                                child: Text(kit),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedKit = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Рекомендуемый состав',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 12),
              ...currentItems.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                          color: Colors.black.withOpacity(0.04),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: const Color(0xFFDBEAFE),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.check_rounded,
                            color: Color(0xFF2563EB),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            item,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111827),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                      color: Colors.black.withOpacity(0.04),
                    ),
                  ],
                ),
                child: const Text(
                  'Подсказка: этот список — базовая рекомендация. Реальный состав аптечки зависит от возраста, хронических состояний, аллергий и советов врача.',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Color(0xFF6B7280),
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
