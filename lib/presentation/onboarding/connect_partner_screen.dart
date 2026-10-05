import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/invite_code.dart';
import '../../providers/couple_providers.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/paris_backdrop.dart';

/// Écran 3 : créer un espace (génère un code) ou rejoindre avec un code.
class ConnectPartnerScreen extends ConsumerStatefulWidget {
  const ConnectPartnerScreen({super.key});

  @override
  ConsumerState<ConnectPartnerScreen> createState() =>
      _ConnectPartnerScreenState();
}

class _ConnectPartnerScreenState extends ConsumerState<ConnectPartnerScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _create() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(coupleControllerProvider).create();
    if (!mounted) return;
    result.when(
      success: (_) {}, // router → écran d'attente
      failure: (message) => setState(() {
        _loading = false;
        _error = message;
      }),
    );
  }

  Future<void> _openJoinSheet() async {
    final code = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _JoinSheet(),
    );
    if (code == null || !mounted) return;

    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref.read(coupleControllerProvider).join(code);
    if (!mounted) return;
    result.when(
      success: (_) {},
      failure: (message) => setState(() {
        _loading = false;
        _error = message;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ParisScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              const Text('💌', style: TextStyle(fontSize: 64)),
              const SizedBox(height: 24),
              Text(
                'Invite ton partenaire',
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Crée votre espace, ou rejoins celui de ton partenaire.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const Spacer(),
              PrimaryButton(
                label: 'Créer notre espace ❤️',
                loading: _loading,
                onPressed: _create,
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _loading ? null : _openJoinSheet,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(56),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: const Text('J\'ai un code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JoinSheet extends StatefulWidget {
  const _JoinSheet();

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final code = InviteCode.normalize(_controller.text);
    if (!InviteCode.isValid(code)) {
      setState(() => _error = 'Code invalide (ex : LOVE-7K42QX).');
      return;
    }
    Navigator.of(context).pop(code);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Entre le code',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              textCapitalization: TextCapitalization.characters,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: 'LOVE-7K42QX',
                errorText: _error,
              ),
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Rejoindre', onPressed: _submit),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
