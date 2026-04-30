import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../data/family_repository.dart';
import '../models/family_member_model.dart';

class AddFamilyMemberScreen extends StatefulWidget {
  const AddFamilyMemberScreen({super.key});

  @override
  State<AddFamilyMemberScreen> createState() => _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen> {
  final _repository = FamilyRepository();

  final nameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  String selectedRelation = 'Мама';
  bool isLoading = false;

  final relations = const [
    'Мама',
    'Папа',
    'Брат',
    'Сестра',
    'Ребенок',
    'Бабушка',
    'Дедушка',
    'Другое',
  ];

  @override
  void dispose() {
    nameCtrl.dispose();
    ageCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> saveMember() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Пользователь не найден')));
      return;
    }

    if (nameCtrl.text.trim().isEmpty || ageCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Заполните обязательные поля')),
      );
      return;
    }

    final age = int.tryParse(ageCtrl.text.trim());
    if (age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Возраст должен быть числом')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      final member = FamilyMemberModel(
        id: '',
        userId: user.uid,
        name: nameCtrl.text.trim(),
        relation: selectedRelation,
        age: age,
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
        createdAt: DateTime.now(),
      );

      await _repository.addFamilyMember(member);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Член семьи добавлен')));

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(

      appBar: AppBar(title: const Text('Добавить члена семьи')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('Имя'),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(hintText: 'Например: Алия'),
              ),
              const SizedBox(height: 16),

              _label('Кем приходится'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: selectedRelation,
                    isExpanded: true,
                    items:
                        relations
                            .map(
                              (relation) => DropdownMenuItem(
                                value: relation,
                                child: Text(relation),
                              ),
                            )
                            .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() {
                        selectedRelation = value;
                      });
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              _label('Возраст'),
              TextField(
                controller: ageCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Например: 45'),
              ),
              const SizedBox(height: 16),

              _label('Заметки'),
              TextField(
                controller: notesCtrl,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Аллергии, особенности и т.д.',
                ),
              ),
              const SizedBox(height: 28),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : saveMember,
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
