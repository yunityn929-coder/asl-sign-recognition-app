import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';

/// Prompts for a name to fingerspell in the "Spell Your Name" lesson.
/// Returns the sanitized (letters-only, uppercased) name, or null if the
/// user cancelled — callers should fall back to a default in that case.
class NameEntryDialog extends StatefulWidget {
  final String initialName;
  const NameEntryDialog({super.key, required this.initialName});

  @override
  State<NameEntryDialog> createState() => _NameEntryDialogState();
}

class _NameEntryDialogState extends State<NameEntryDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final sanitized =
        _controller.text.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    Navigator.pop(context, sanitized);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("What's your name?"),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[a-zA-Z]'))],
        decoration: const InputDecoration(hintText: 'e.g. ALEX'),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _submit,
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
          child: const Text('Start'),
        ),
      ],
    );
  }
}
