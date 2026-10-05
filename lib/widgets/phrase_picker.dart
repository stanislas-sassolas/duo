import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Rangée de pastilles « petit mot » au-dessus du bouton d'envoi.
///
/// Un toucher choisit la phrase, un second la retire (le petit mot reste
/// optionnel). Sans phrase enregistrée, propose d'en ajouter.
class PhrasePicker extends StatelessWidget {
  const PhrasePicker({
    super.key,
    required this.phrases,
    required this.selected,
    required this.onChanged,
  });

  final List<String> phrases;
  final String? selected;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (phrases.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: () => context.push('/phrases'),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Ajouter mes petits mots'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            'Choisir un petit message',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.hintColor,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: phrases.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final phrase = phrases[index];
              final isSelected = phrase == selected;
              return ChoiceChip(
                label: Text(phrase),
                selected: isSelected,
                showCheckmark: false,
                onSelected: (_) => onChanged(isSelected ? null : phrase),
              );
            },
          ),
        ),
      ],
    );
  }
}
