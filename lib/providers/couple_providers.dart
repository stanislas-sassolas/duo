import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/utils/result.dart';
import '../models/app_user.dart';
import '../models/couple.dart';
import 'auth_providers.dart';
import 'service_providers.dart';

/// Couple courant (temps réel), dérivé du profil utilisateur.
final coupleProvider = StreamProvider<Couple?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final coupleId = user?.coupleId;
  if (coupleId == null || coupleId.isEmpty) return Stream.value(null);
  return ref.watch(coupleRepositoryProvider).watchCouple(coupleId);
});

/// Profil du partenaire (temps réel), ou null si le couple est incomplet.
final partnerProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  final couple = ref.watch(coupleProvider).valueOrNull;
  if (uid == null || couple == null) return Stream.value(null);
  final partnerId = couple.partnerOf(uid);
  if (partnerId == null) return Stream.value(null);
  return ref.watch(authRepositoryProvider).watchUser(partnerId);
});

/// `true` si l'utilisateur a un couple complet (deux membres liés).
final hasCompleteCoupleProvider = Provider<bool>((ref) {
  final couple = ref.watch(coupleProvider).valueOrNull;
  return couple?.isComplete ?? false;
});

final coupleControllerProvider =
    Provider<CoupleController>((ref) => CoupleController(ref));

class CoupleController {
  CoupleController(this._ref);
  final Ref _ref;

  Future<Result<Couple>> create() async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return const Failure('Non connecté.');
    return _ref.read(coupleRepositoryProvider).createCouple(uid);
  }

  Future<Result<Couple>> join(String code) async {
    final uid = _ref.read(currentUidProvider);
    if (uid == null) return const Failure('Non connecté.');
    return _ref
        .read(coupleRepositoryProvider)
        .joinCouple(uid: uid, inviteCode: code);
  }

  Future<Result<void>> unlink() async {
    final uid = _ref.read(currentUidProvider);
    final couple = _ref.read(coupleProvider).valueOrNull;
    if (uid == null || couple == null) return const Failure('Aucun couple.');
    return _ref
        .read(coupleRepositoryProvider)
        .unlink(coupleId: couple.id, uid: uid);
  }
}
