import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/constants/app_constants.dart';
import '../../providers/auth_providers.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/paris_backdrop.dart';

/// Écran 1 : accueil chaleureux. On peut aussi y retrouver un compte existant
/// (lié à Google) sur un nouveau téléphone.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _restoring = false;

  /// Nouveau téléphone : on se reconnecte avec Google. Le routeur envoie
  /// ensuite automatiquement vers l'accueil (profil et couple retrouvés), ou
  /// vers le prénom si ce compte Google n'avait pas encore de profil Duo.
  Future<void> _restore() async {
    setState(() => _restoring = true);
    final result = await ref.read(authControllerProvider).signInWithGoogle();
    if (!mounted) return;
    setState(() => _restoring = false);
    result.when(
      success: (_) {},
      failure: (message) =>
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(message))),
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
              const Text('❤️', style: TextStyle(fontSize: 72)),
              const SizedBox(height: 32),
              Text(
                'Un petit dessin pour\nquelqu\'un que tu aimes',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700, height: 1.3),
              ),
              const Spacer(),
              PrimaryButton(
                label: 'Commencer',
                onPressed: _restoring ? null : () => context.go('/name'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _restoring ? null : _restore,
                child: _restoring
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('J\'ai déjà un compte (Google)'),
              ),
              const SizedBox(height: 4),
              Text(
                AppConstants.appName,
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
