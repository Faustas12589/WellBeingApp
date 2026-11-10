import 'package:flutter/material.dart';
import '../models/models.dart';
import 'package:provider/provider.dart';
import '../../../theme/app_theme.dart';
import '../../../services/language_notifier.dart';

class HabitEditorDialog extends StatefulWidget {
  final Habit? initial;
  const HabitEditorDialog({super.key, this.initial});

  @override
  State<HabitEditorDialog> createState() => _HabitEditorDialogState();
}

class IconPickerField extends StatefulWidget {
  final String? initial;
  final ValueChanged<String?> onChanged;
  const IconPickerField({super.key, this.initial, required this.onChanged});

  @override
  State<IconPickerField> createState() => _IconPickerFieldState();
}

class _IconPickerFieldState extends State<IconPickerField> {
  static const _icons = {
    'run':        Icons.directions_run,
    'water':      Icons.water_drop,
    'book':       Icons.menu_book,
    'sleep':      Icons.bedtime,
    'food':       Icons.restaurant,
    'heart':      Icons.favorite,
    'gym':        Icons.fitness_center,
    'meditation': Icons.self_improvement,
    'music':      Icons.music_note,
    'code':       Icons.code,
    'study':      Icons.school,
    'money':      Icons.attach_money,
    'walk':       Icons.directions_walk,
    'bike':       Icons.directions_bike,
    'clean':      Icons.cleaning_services,
    'journal':    Icons.edit_note,
  };

  String? _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initial;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.watch<LanguageNotifier>().t('icon_label'), style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _icons.entries.map((e) {
            final isSelected = _selected == e.key;
            return GestureDetector(
              onTap: () {
                setState(() => _selected = e.key);
                widget.onChanged(e.key);
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isSelected ? colors.primary : colors.background2,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isSelected ? colors.primary : colors.background2,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Icon(e.value, size: 24),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

class _HabitEditorDialogState extends State<HabitEditorDialog> {
  final _nameCtrl     = TextEditingController();
  final _minCtrl      = TextEditingController();
  final _maxCtrl      = TextEditingController();
  final _optionsCtrl  = TextEditingController();
  final _stepGoalCtrl = TextEditingController();

  RatingKind _kind = RatingKind.checkbox;
  String? _selectedIcon;

  @override
  void initState() {
    super.initState();
    final h = widget.initial;
    if (h != null) {
      _nameCtrl.text = h.name;
      _kind = h.kind;
      _selectedIcon = h.icon;
      if (h.min != null) _minCtrl.text = '${h.min}';
      if (h.max != null) _maxCtrl.text = '${h.max}';
      if (h.stepGoal != null) _stepGoalCtrl.text = '${h.stepGoal}';
      if (h.options != null && h.options!.isNotEmpty) {
        _optionsCtrl.text = h.options!.join(', ');
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _minCtrl.dispose();
    _maxCtrl.dispose();
    _optionsCtrl.dispose();
    _stepGoalCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final editing = widget.initial != null;
    final lang = context.watch<LanguageNotifier>();

    return AlertDialog(

      title: Text(lang.t(editing ? 'edit_habit' : 'new_habit')),
      content: SingleChildScrollView(
        child: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: InputDecoration(labelText: lang.t('title_label')),
            ),
            const SizedBox(height: 16),

            IconPickerField(
              initial: _selectedIcon,
              onChanged: (key) => setState(() => _selectedIcon = key),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<RatingKind>(
              value: _kind,
              decoration: InputDecoration(labelText: lang.t('type_label')),
              items: RatingKind.values.map((k) {
                return DropdownMenuItem(
                  value: k,
                  child: Text(
                    switch (k) {
                      RatingKind.checkbox   => lang.t('type_checkbox'),
                      RatingKind.number     => lang.t('type_number'),
                      RatingKind.scale      => lang.t('type_scale'),
                      RatingKind.enumerator => lang.t('type_category'),
                      RatingKind.steps      => lang.t('type_steps'),
                    },
                  ),
                );
              }).toList(),
              onChanged: (k) => setState(() => _kind = k ?? RatingKind.checkbox),
            ),

            // Number / Scale fields
            if (_kind == RatingKind.number || _kind == RatingKind.scale) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _minCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Min"),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _maxCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Max"),
              ),
            ],

            // Enumerator fields
            if (_kind == RatingKind.enumerator) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _optionsCtrl,
                decoration: InputDecoration(
                  labelText: lang.t('options_label'),
                ),
              ),
            ],

            // Steps field
            if (_kind == RatingKind.steps) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _stepGoalCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: lang.t('steps_goal_label'),
                  hintText: lang.t('steps_goal_hint'),
                  prefixIcon: const Icon(Icons.directions_walk),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                lang.t('steps_auto_complete'),
                style: TextStyle(fontSize: 12, color : colors.textColor),
              ),
            ],
          ],
        ),
      ),

      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(lang.t('cancel')),
        ),
        TextButton(
          onPressed: _submit,
          child: Text(lang.t(editing ? 'save' : 'add')),
        ),
      ],
    );
  }

  void _submit() {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    int? min = int.tryParse(_minCtrl.text);
    int? max = int.tryParse(_maxCtrl.text);
    int? stepGoal = int.tryParse(_stepGoalCtrl.text);

    // Clear irrelevant fields per kind
    if (!(_kind == RatingKind.number || _kind == RatingKind.scale)) {
      min = null;
      max = null;
    }
    if (_kind != RatingKind.steps) {
      stepGoal = null;
    }

    List<String>? opts;
    if (_kind == RatingKind.enumerator) {
      final raw = _optionsCtrl.text
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty && s != '---')
          .toList();
      opts = ['---', ...raw];
    }

    final id = widget.initial?.id ??
        "${name.toLowerCase().replaceAll(' ', '-')}-${DateTime.now().millisecondsSinceEpoch}";

    final habit = Habit(
      id: id,
      name: name,
      kind: _kind,
      min: min,
      max: max,
      options: opts,
      icon: _selectedIcon,
      stepGoal: stepGoal, 
    );

    Navigator.pop(context, habit);
  }
}