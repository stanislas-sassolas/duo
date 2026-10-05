import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/personal_providers.dart';

/// « Mes petits mots » : les phrases que je peux joindre à mes dessins.
///
/// Liste privée : mon partenaire ne la voit pas (il ne reçoit que la phrase
/// choisie avec chaque dessin).
class PhrasesScreen extends ConsumerStatefulWidget {
  const PhrasesScreen({super.key});

  @override
  ConsumerState<PhrasesScreen> createState() => _PhrasesScreenState();
}

class _PhrasesScreenState extends ConsumerState<PhrasesScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(List<String> phrases) async {
    final result =
        await ref.read(personalControllerProvider).savePhrases(phrases);
    if (!mounted) return;
    result.when(
      success: (_) {},
      failure: (message) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message))),
    );
  }

  Future<void> _add(List<String> current) async {
    final phrase = _controller.text.trim();
    if (phrase.isEmpty) return;
    _controller.clear();
    await _save([...current, phrase]);
  }

  @override
  Widget build(BuildContext context) {
    final phrases = ref.watch(myPhrasesProvider).valueOrNull ?? const [];
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes petits mots')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
              child: Text(
                'Proposés quand tu envoies un dessin. '
                'Ils ne sont visibles que par toi.',
                style: theme.textTheme.bodyMedium
                    ?.copyWith(color: theme.hintColor),
              ),
            ),
            Expanded(
              child: ReorderableListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                onReorder: (oldIndex, newIndex) {
                  final updated = [...phrases];
                  if (newIndex > oldIndex) newIndex -= 1;
                  updated.insert(newIndex, updated.removeAt(oldIndex));
                  _save(updated);
                },
                children: [
                  for (var i = 0; i < phrases.length; i++)
                    ListTile(
                      key: ValueKey('phrase-$i-${phrases[i]}'),
                      title: Text(phrases[i]),
                      leading: const Icon(Icons.drag_indicator_rounded),
                      trailing: IconButton(
                        tooltip: 'Supprimer',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => _save([...phrases]..removeAt(i)),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      maxLength: AppConstants.maxMessageLength,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(phrases),
                      decoration: const InputDecoration(
                        hintText: 'Ex : ☀️ Bonne journée mon cœur',
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Ajouter',
                    onPressed: () => _add(phrases),
                    icon: const Icon(Icons.add_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
