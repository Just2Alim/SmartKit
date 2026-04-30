import 'package:flutter/material.dart';
import '../data/family_repository.dart';

class EditFamilyMemberScreen extends StatefulWidget {
  final String memberId;

  const EditFamilyMemberScreen({super.key, required this.memberId});

  @override
  State<EditFamilyMemberScreen> createState() => _EditFamilyMemberScreenState();
}

class _EditFamilyMemberScreenState extends State<EditFamilyMemberScreen> {
  final FamilyRepository _repository = FamilyRepository();

  final nameCtrl = TextEditingController();
  final ageCtrl = TextEditingController();
  final notesCtrl = TextEditingController();

  String selectedRelation = 'Мама';
  bool isLoading = true;
  bool isSaving = false;

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
  void initState() {
    super.initState();
    _loadMember();
  }

  @override
  void dispose() {
    nameCtrl.dispose();
    ageCtrl.dispose();
    notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadMember() async {
    final member = await _repository.getFamilyMemberById(widget.memberId);

    if (member == null) {
      if (!mounted) return;
      Navigator.pop(context);
      return;
    }

    nameCtrl.text = member.name;
    ageCtrl.text = member.age.toString();
    notesCtrl.text = member.notes ?? '';
    selectedRelation = member.relation;

    setState(() {
      isLoading = false;
    });
  }

  Future<void> saveChanges() async {
    if (nameCtrl.text.isEmpty || ageCtrl.text.isEmpty) {
      return;
    }

    final age = int.tryParse(ageCtrl.text);
    if (age == null) return;

    setState(() => isSaving = true);

    await _repository.updateFamilyMember(
      memberId: widget.memberId,
      name: nameCtrl.text,
      relation: selectedRelation,
      age: age,
      notes: notesCtrl.text,
    );

    if (!mounted) return;

    Navigator.pop(context, true);
  }

  Widget _label(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Редактировать')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _label('Имя'),
            TextField(controller: nameCtrl),

            const SizedBox(height: 16),

            _label('Кем приходится'),
            DropdownButton<String>(
              value: selectedRelation,
              isExpanded: true,
              items:
                  relations
                      .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                      .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    selectedRelation = value;
                  });
                }
              },
            ),

            const SizedBox(height: 16),

            _label('Возраст'),
            TextField(controller: ageCtrl, keyboardType: TextInputType.number),

            const SizedBox(height: 16),

            _label('Заметки'),
            TextField(controller: notesCtrl, maxLines: 3),

            const Spacer(),

            ElevatedButton(
              onPressed: isSaving ? null : saveChanges,
              child:
                  isSaving
                      ? const CircularProgressIndicator()
                      : const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }
}
