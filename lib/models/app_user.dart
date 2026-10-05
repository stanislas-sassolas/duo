import 'package:cloud_firestore/cloud_firestore.dart';

/// Profil d'un utilisateur.
///
/// Document Firestore : `users/{uid}`.
class AppUser {
  const AppUser({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.coupleId,
    this.signature,
    this.fcmTokens = const [],
    this.createdAt,
  });

  final String id;
  final String displayName;
  final String? photoUrl;

  /// `null` tant que l'utilisateur n'a pas rejoint/créé un couple.
  final String? coupleId;

  /// Petit surnom ou emojis affichés à côté du prénom (ex. « 🌻 »),
  /// visibles par le partenaire. `null` tant qu'il n'a jamais été défini.
  final String? signature;

  /// Jetons FCM (multi-appareils). On envoie une notif à chaque jeton.
  final List<String> fcmTokens;

  final DateTime? createdAt;

  bool get hasCouple => coupleId != null && coupleId!.isNotEmpty;

  /// Surnom nettoyé (chaîne vide si aucun).
  String get signatureText => signature?.trim() ?? '';

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    String? coupleId,
    List<String>? fcmTokens,
    bool clearCouple = false,
  }) {
    return AppUser(
      id: id,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      coupleId: clearCouple ? null : (coupleId ?? this.coupleId),
      signature: signature,
      fcmTokens: fcmTokens ?? this.fcmTokens,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toCreateJson() => {
        'displayName': displayName,
        'photoUrl': photoUrl,
        'coupleId': coupleId,
        'fcmTokens': fcmTokens,
        'createdAt': FieldValue.serverTimestamp(),
      };

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return AppUser(
      id: doc.id,
      displayName: (data['displayName'] as String?) ?? '',
      photoUrl: data['photoUrl'] as String?,
      coupleId: data['coupleId'] as String?,
      signature: data['signature'] as String?,
      fcmTokens: (data['fcmTokens'] as List<dynamic>?)
              ?.map((token) => token as String)
              .toList() ??
          const [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
