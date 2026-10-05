import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../models/app_user.dart';

/// En-tête intime de l'écran d'accueil : avatar + prénom du partenaire.
class PartnerHeader extends StatelessWidget {
  const PartnerHeader({
    super.key,
    required this.partner,
    this.online = false,
  });

  final AppUser? partner;
  final bool online;

  @override
  Widget build(BuildContext context) {
    final name = partner?.displayName ?? '…';
    return Row(
      children: [
        _Avatar(photoUrl: partner?.photoUrl, name: name),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              name,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            if (online)
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFF43A047),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'En ligne',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.lightSubtext,
                        ),
                  ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.photoUrl, required this.name});
  final String? photoUrl;
  final String name;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isNotEmpty ? name.trim()[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: 24,
      backgroundColor: AppColors.accent.withOpacity(0.3),
      backgroundImage: (photoUrl != null && photoUrl!.isNotEmpty)
          ? NetworkImage(photoUrl!)
          : null,
      child: (photoUrl == null || photoUrl!.isEmpty)
          ? Text(
              initial,
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontWeight: FontWeight.w700,
                fontSize: 18,
              ),
            )
          : null,
    );
  }
}
