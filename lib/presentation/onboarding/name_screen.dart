import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/paris_backdrop.dart';

/// Écran 2 : choix du prénom/pseudo. Crée le compte (anonyme) + profil.
class NameScreen extends ConsumerStatefulWidget {
  const NameScreen({super.key});

  @override
  ConsumerState<NameScreen> createState() => _NameScreenState();
}

class _NameScreenState extends ConsumerState<NameScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Entre au moins un prénom.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await ref
        .read(authControllerProvider)
        .signInAndCreateProfile(name);

    if (!mounted) return;
    result.when(
      success: (_) {
        // La redirection du router bascule automatiquement vers /connect.
      },
      failure: (message) => setState(() {
        _loading = false;
        _error = message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ParisScaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 12),
              Text(
                'Comment tu t\'appelles ?',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Ton partenaire verra ce prénom.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _controller,
                textInputAction: TextInputAction.done,
                textCapitalization: TextCapitalization.words,
                autofocus: true,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(hintText: 'Ton prénom'),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const Spacer(),
              PrimaryButton(
                label: 'Continuer',
                loading: _loading,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
