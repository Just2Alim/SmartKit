import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import '../../../core/router/app_routes.dart';

import '../data/medicine_repository.dart';
import '../models/medicine_model.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController searchCtrl = TextEditingController();
  final MedicineRepository _repository = MedicineRepository();

  String selectedCategory = 'Все';

  @override
  void dispose() {
    searchCtrl.dispose();
    super.dispose();
  }

  List<String> _extractCategories(List<MedicineModel> medicines) {
    final categories =
        medicines.map((m) => m.category).toSet().toList()..sort();
    return ['Все', ...categories];
  }

  List<MedicineModel> _filterMedicines(List<MedicineModel> medicines) {
    final query = searchCtrl.text.trim().toLowerCase();

    return medicines.where((medicine) {
      final matchesQuery =
          medicine.name.toLowerCase().contains(query) ||
          medicine.category.toLowerCase().contains(query) ||
          medicine.dosage.toLowerCase().contains(query);

      final matchesCategory =
          selectedCategory == 'Все' || medicine.category == selectedCategory;

      return matchesQuery && matchesCategory;
    }).toList();
  }

  Color _categoryColor(String category, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (category.toLowerCase()) {
      case 'обезболивающее':
        return isDark
            ? const Color(0xFF1E3A8A).withOpacity(0.3)
            : const Color(0xFFDBEAFE);
      case 'антибиотик':
        return isDark
            ? const Color(0xFF7F1D1D).withOpacity(0.3)
            : const Color(0xFFFEE2E2);
      case 'витамины':
        return isDark
            ? const Color(0xFF78350F).withOpacity(0.3)
            : const Color(0xFFFEF3C7);
      case 'противовоспалительное':
        return isDark
            ? const Color(0xFF4C1D95).withOpacity(0.3)
            : const Color(0xFFEDE9FE);
      default:
        return isDark
            ? Colors.white.withOpacity(0.05)
            : const Color(0xFFF3F4F6);
    }
  }

  Color _categoryIconColor(String category) {
    switch (category.toLowerCase()) {
      case 'обезболивающее':
        return const Color(0xFF2563EB);
      case 'антибиотик':
        return const Color(0xFFDC2626);
      case 'витамины':
        return const Color(0xFFD97706);
      case 'противовоспалительное':
        return const Color(0xFF7C3AED);
      default:
        return const Color(0xFF6B7280);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Лекарства'),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.addMedicine);
            },
            icon: const Icon(Icons.add_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child:
            user == null
                ? const Center(child: Text('Пользователь не найден'))
                : StreamBuilder<List<MedicineModel>>(
                  stream: _repository.getMedicinesByUser(user.id),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (snapshot.hasError) {
                      return Center(child: Text('Ошибка: ${snapshot.error}'));
                    }

                    final medicines = snapshot.data ?? [];
                    final categories = _extractCategories(medicines);
                    final filteredMedicines = _filterMedicines(medicines);

                    if (!categories.contains(selectedCategory)) {
                      selectedCategory = 'Все';
                    }

                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                          child: TextField(
                            controller: searchCtrl,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText: 'Найти лекарство...',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon:
                                  searchCtrl.text.isNotEmpty
                                      ? IconButton(
                                        onPressed: () {
                                          searchCtrl.clear();
                                          setState(() {});
                                        },
                                        icon: const Icon(Icons.close_rounded),
                                      )
                                      : null,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: SizedBox(
                            height: 38,
                            child: ListView.separated(
                              scrollDirection: Axis.horizontal,
                              itemCount: categories.length,
                              separatorBuilder:
                                  (_, __) => const SizedBox(width: 8),
                              itemBuilder: (context, index) {
                                final category = categories[index];
                                final isSelected = selectedCategory == category;

                                return InkWell(
                                  onTap: () {
                                    setState(() {
                                      selectedCategory = category;
                                    });
                                  },
                                  borderRadius: BorderRadius.circular(999),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 14,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? Theme.of(
                                                context,
                                              ).colorScheme.primary
                                              : Theme.of(context).cardColor,
                                      borderRadius: BorderRadius.circular(999),
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? Theme.of(
                                                  context,
                                                ).colorScheme.primary
                                                : Theme.of(
                                                  context,
                                                ).colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Text(
                                      category,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child:
                              medicines.isEmpty
                                  ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: Text(
                                          'Пока нет добавленных лекарств',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  : filteredMedicines.isEmpty
                                  ? Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(20),
                                      child: Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.all(18),
                                        decoration: BoxDecoration(
                                          color: Theme.of(context).cardColor,
                                          borderRadius: BorderRadius.circular(
                                            24,
                                          ),
                                        ),
                                        child: Text(
                                          'Ничего не найдено по текущему запросу',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color:
                                                Theme.of(
                                                  context,
                                                ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ),
                                  )
                                  : ListView.separated(
                                    padding: const EdgeInsets.fromLTRB(
                                      20,
                                      8,
                                      20,
                                      24,
                                    ),
                                    itemCount: filteredMedicines.length,
                                    separatorBuilder:
                                        (_, __) => const SizedBox(height: 12),
                                    itemBuilder: (context, index) {
                                      final medicine = filteredMedicines[index];

                                      return InkWell(
                                        onTap: () {
                                          Navigator.pushNamed(
                                            context,
                                            AppRoutes.medicineDetail,
                                            arguments: medicine.id,
                                          );
                                        },
                                        borderRadius: BorderRadius.circular(24),
                                        child: Container(
                                          padding: const EdgeInsets.all(18),
                                          decoration: BoxDecoration(
                                            color: Theme.of(context).cardColor,
                                            borderRadius: BorderRadius.circular(
                                              24,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                                color: Colors.black.withOpacity(
                                                  0.04,
                                                ),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 54,
                                                height: 54,
                                                decoration: BoxDecoration(
                                                  color: _categoryColor(
                                                    medicine.category,
                                                    context,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(16),
                                                ),
                                                child: Icon(
                                                  Icons.medication_rounded,
                                                  color: _categoryIconColor(
                                                    medicine.category,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 14),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      medicine.name,
                                                      style: TextStyle(
                                                        fontSize: 16,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .onSurface,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '${medicine.category} • ${medicine.dosage}',
                                                      style: TextStyle(
                                                        fontSize: 13,
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .onSurfaceVariant,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Text(
                                                      medicine.familyMemberId ==
                                                              null
                                                          ? 'Для меня'
                                                          : 'Для члена семьи',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color:
                                                            Theme.of(context)
                                                                .colorScheme
                                                                .primary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 6,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color:
                                                      Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerHighest,
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                        999,
                                                      ),
                                                ),
                                                child: Text(
                                                  '${medicine.quantity} шт',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color:
                                                        Theme.of(
                                                          context,
                                                        ).colorScheme.onSurface,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                        ),
                      ],
                    );
                  },
                ),
      ),
    );
  }
}
