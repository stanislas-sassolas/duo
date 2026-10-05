import 'package:cloud_firestore/cloud_firestore.dart';

/// Lien entre deux utilisateurs.
///
/// Document Firestore : `couples/{coupleId}`.
///
/// [members] contient les uid des deux partenaires et sert de base aux
/// Security Rules (`request.auth.uid in resource.data.members`).
class Couple {
  const Couple({
    required this.id,
    required this.userA,
    this.userB,
    required this.inviteCode,
    required this.members,
    this.createdAt,
    this.lastDrawingAt,
  });

  final String id;

  /// Créateur du couple. Toujours présent.
  final String userA;

  /// Deuxième partenaire. `null` tant que l'invitation n'est pas acceptée.
  final String? userB;

  /// Code type `LOVE-7K42QX` permettant de rejoindre.
  final String inviteCode;

  /// Liste plate des membres pour des règles/queries simples.
  final List<String> members;

  final DateTime? createdAt;
  final DateTime? lastDrawingAt;

  bool get isComplete => userB != null && userB!.isNotEmpty;

  /// Retourne l'uid du partenaire de [uid], ou `null`.
  String? partnerOf(String uid) {
    if (uid == userA) return userB;
    if (uid == userB) return userA;
    return null;
  }

  Map<String, dynamic> toCreateJson() => {
        'userA': userA,
        'userB': userB,
        'inviteCode': inviteCode,
        'members': members,
        'createdAt': FieldValue.serverTimestamp(),
        'lastDrawingAt': null,
      };

  factory Couple.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const {};
    return Couple(
      id: doc.id,
      userA: (data['userA'] as String?) ?? '',
      userB: data['userB'] as String?,
      inviteCode: (data['inviteCode'] as String?) ?? '',
      members: (data['members'] as List<dynamic>?)
              ?.map((member) => member as String)
              .toList() ??
          const [],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      lastDrawingAt: (data['lastDrawingAt'] as Timestamp?)?.toDate(),
    );
  }
}
