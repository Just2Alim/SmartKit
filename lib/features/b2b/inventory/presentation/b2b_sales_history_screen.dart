import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/b2b_sales_repository.dart';
import '../models/b2b_sale_model.dart';

class B2BSalesHistoryScreen extends StatelessWidget {
  const B2BSalesHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final salesRepository = B2BSalesRepository();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: user == null
          ? const Center(child: Text('Пользователь не найден'))
          : StreamBuilder<List<B2BSaleModel>>(
              stream: salesRepository.getSalesByUser(user.uid),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: Color(0xFF10B981)));
                }

                final sales = snapshot.data ?? [];

                return CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    _buildAppBar(context),
                    if (sales.isEmpty)
                      _buildEmptyState()
                    else
                      SliverPadding(
                        padding: const EdgeInsets.all(20),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) => Padding(
                              padding: const EdgeInsets.only(bottom: 16),
                              child: _SaleCard(sale: sales[index]),
                            ),
                            childCount: sales.length,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 120,
      pinned: true,
      elevation: 0,
      backgroundColor: const Color(0xFF10B981),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
        title: const Text(
          'История продаж',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: -0.5,
          ),
        ),
        background: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF10B981), Color(0xFF059669)],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return SliverFillRemaining(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20),
                ],
              ),
              child: Icon(Icons.history_rounded, size: 48, color: Colors.grey[300]),
            ),
            const SizedBox(height: 24),
            const Text(
              'Продаж пока нет',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Все ваши транзакции будут здесь',
              style: TextStyle(color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleCard extends StatelessWidget {
  final B2BSaleModel sale;

  const _SaleCard({required this.sale});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '#${sale.id.substring(0, 8).toUpperCase()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                '${sale.totalAmount} ₸',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 20,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.access_time_rounded, size: 14, color: Color(0xFF94A3B8)),
              const SizedBox(width: 6),
              Text(
                dateFormat.format(sale.saleDate),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
          ...sale.items.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        item['name'] ?? item['medicineName'] ?? 'Неизвестно',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF334155),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'x${item['quantity']}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
