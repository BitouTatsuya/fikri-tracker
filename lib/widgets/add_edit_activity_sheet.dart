import 'package:flutter/material.dart';

import '../models/activity_model.dart';
import '../providers/activity_provider.dart';
import '../theme/app_theme.dart';

const List<String> kEmojiChoices = [
  '😴', '💻', '💪', '🎮', '👥', '📚', '🧘', '🍳', '🚗', '🎨',
  '🛒', '🧹', '📞', '🎵', '⚽', '🐶', '💰', '🙏', '🛌', '🌱',
];

const List<int> kColorChoices = [
  0xFF22C55E, // emerald (default accent)
  0xFF3B82F6, // blue
  0xFFF59E0B, // amber
  0xFFEF4444, // red
  0xFFA855F7, // purple
  0xFFEC4899, // pink
  0xFF14B8A6, // teal
  0xFF64748B, // slate
];

/// Shows the Add/Edit activity form as a modal bottom sheet.
Future<void> showAddEditActivitySheet(
  BuildContext context, {
  required ActivityProvider provider,
  ActivityModel? existing,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(ctx).viewInsets.bottom,
      ),
      child: _AddEditActivityForm(provider: provider, existing: existing),
    ),
  );
}

class _AddEditActivityForm extends StatefulWidget {
  final ActivityProvider provider;
  final ActivityModel? existing;

  const _AddEditActivityForm({required this.provider, this.existing});

  @override
  State<_AddEditActivityForm> createState() => _AddEditActivityFormState();
}

class _AddEditActivityFormState extends State<_AddEditActivityForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late String _selectedEmoji;
  late int _selectedColor;
  late int _hours;
  late int _minutes;

  bool get isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _nameController = TextEditingController(text: e?.name ?? '');
    _selectedEmoji = e?.emoji ?? kEmojiChoices.first;
    _selectedColor = e?.colorValue ?? kColorChoices.first;
    _hours = e != null ? e.targetSeconds ~/ 3600 : 1;
    _minutes = e != null ? (e.targetSeconds % 3600) ~/ 60 : 0;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final targetSeconds = _hours * 3600 + _minutes * 60;
    if (targetSeconds <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Target duration must be more than 0 minutes')),
      );
      return;
    }

    if (isEditing) {
      await widget.provider.editActivity(
        id: widget.existing!.id,
        name: _nameController.text.trim(),
        emoji: _selectedEmoji,
        colorValue: _selectedColor,
        targetSeconds: targetSeconds,
      );
    } else {
      await widget.provider.addActivity(
        name: _nameController.text.trim(),
        emoji: _selectedEmoji,
        colorValue: _selectedColor,
        targetSeconds: targetSeconds,
      );
    }

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.secondaryText.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isEditing ? 'Edit Activity' : 'Add Activity',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Activity name'),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Enter a name' : null,
              ),
              const SizedBox(height: 16),
              const Text('Icon', style: TextStyle(color: AppColors.secondaryText)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kEmojiChoices.map((emoji) {
                  final selected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.accent.withOpacity(0.25)
                            : Colors.black26,
                        borderRadius: BorderRadius.circular(12),
                        border: selected
                            ? Border.all(color: AppColors.accent, width: 1.5)
                            : null,
                      ),
                      child: Text(emoji, style: const TextStyle(fontSize: 20)),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Card color', style: TextStyle(color: AppColors.secondaryText)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                children: kColorChoices.map((color) {
                  final selected = color == _selectedColor;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColor = color),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Color(color),
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(color: Colors.white, width: 2)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 16),
              const Text('Target duration', style: TextStyle(color: AppColors.secondaryText)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _NumberField(
                      label: 'Hours',
                      value: _hours,
                      max: 23,
                      onChanged: (v) => setState(() => _hours = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _NumberField(
                      label: 'Minutes',
                      value: _minutes,
                      max: 59,
                      step: 5,
                      onChanged: (v) => setState(() => _minutes = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _submit,
                  child: Text(isEditing ? 'Save Changes' : 'Add Activity'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final int value;
  final int max;
  final int step;
  final ValueChanged<int> onChanged;

  const _NumberField({
    required this.label,
    required this.value,
    required this.max,
    required this.onChanged,
    this.step = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: AppColors.secondaryText, fontSize: 12)),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.remove, size: 18),
                onPressed: () => onChanged((value - step).clamp(0, max)),
              ),
              Text('$value', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              IconButton(
                icon: const Icon(Icons.add, size: 18),
                onPressed: () => onChanged((value + step).clamp(0, max)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
