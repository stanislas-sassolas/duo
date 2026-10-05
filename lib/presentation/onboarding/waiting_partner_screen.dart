import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/couple_providers.dart';
import '../../widgets/paris_backdrop.dart';

/// Écran d'attente : le code est affiché et partageable tant que le partenaire
/// n'a pas rejoint. La bascule vers l'accueil est automatique (router).
class WaitingPartnerScreen extends ConsumerWidget {
  const WaitingPartnerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couple = ref.watch(coupleProvider).valueOrNull;
    final code = couple?.inviteCode ?? '…';

    return ParisScaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            children: [
              const Spacer(),
              const Text('⏳', style: TextStyle(fontSize: 56)),
              const SizedBox(height: 24),
              Text(
                'En attente de ton partenaire',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Partage ce code avec la personne que tu aimes.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: code));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Code copié ❤️')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            code,
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Icon(Icons.copy_rounded, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
              const Spacer(),
              // Permet de revenir en arrière (ex : c'est finalement l'autre
              // qui a créé l'espace) : supprime cet espace en attente.
              TextButton(
                onPressed: () => ref.read(coupleControllerProvider).unlink(),
                child: const Text("Annuler, j'ai plutôt un code"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
