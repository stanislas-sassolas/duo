import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_providers.dart';
import '../../providers/couple_providers.dart';

/// Étape du parcours utilisateur, dérivée de l'état auth / profil / couple.
enum AppFlow {
  /// Chargement initial (on ne sait pas encore où envoyer l'utilisateur).
  loading,

  /// Pas encore de compte/profil → onboarding (bienvenue, prénom).
  onboarding,

  /// Connecté mais sans partenaire → écran de connexion du couple.
  needsCouple,

  /// Couple créé, en attente que le partenaire rejoigne.
  waiting,

  /// Couple complet → application principale.
  ready,
}

/// Calcule l'étape courante. Le router écoute ce provider pour rediriger.
final appFlowProvider = Provider<AppFlow>((ref) {
  final auth = ref.watch(authStateProvider);
  if (auth.isLoading) return AppFlow.loading;

  final uid = auth.valueOrNull;
  if (uid == null) return AppFlow.onboarding;

  final userAsync = ref.watch(currentUserProvider);
  if (userAsync.isLoading) return AppFlow.loading;

  final user = userAsync.valueOrNull;
  // Connecté mais profil pas encore écrit (fenêtre courte de l'onboarding).
  if (user == null) return AppFlow.onboarding;
  if (!user.hasCouple) return AppFlow.needsCouple;

  final coupleAsync = ref.watch(coupleProvider);
  if (coupleAsync.isLoading) return AppFlow.loading;

  final couple = coupleAsync.valueOrNull;
  if (couple == null) return AppFlow.needsCouple;
  if (!couple.isComplete) return AppFlow.waiting;

  return AppFlow.ready;
});
