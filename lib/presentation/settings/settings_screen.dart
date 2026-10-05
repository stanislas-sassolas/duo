import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../core/constants/personal.dart';
import '../../providers/auth_providers.dart';
import '../../providers/couple_providers.dart';
import '../../providers/drawing_providers.dart';
import '../../providers/personal_providers.dart';
import '../../providers/settings_providers.dart';
import '../../services/export/drawing_export_service.dart';
import '../../services/update/app_update_service.dart';

/// Paramètres : profil, préférences, gestion du couple et du compte.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).valueOrNull;
    final partner = ref.watch(partnerProvider).valueOrNull;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres')),
      // Largeur limitée : lisible aussi sur tablette.
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              _SectionTitle('Profil'),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Prénom'),
                subtitle: Text(me?.displayName ?? '…'),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () => _editName(context, ref, me?.displayName ?? ''),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('Mon petit surnom'),
                subtitle: Text(
                  (me?.signatureText.isNotEmpty ?? false)
                      ? me!.signatureText
                      : 'Emojis ou surnom affichés à côté de ton prénom',
                ),
                trailing: const Icon(Icons.edit_outlined, size: 20),
                onTap: () =>
                    _editSignature(context, ref, me?.signatureText ?? ''),
              ),
              ListTile(
                leading: const Icon(Icons.chat_bubble_outline_rounded),
                title: const Text('Mes petits mots'),
                subtitle: const Text("Phrases proposées à l'envoi d'un dessin"),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/phrases'),
              ),
              if (partner != null)
                ListTile(
                  leading: const Icon(Icons.favorite_border_rounded),
                  title: const Text('Partenaire'),
                  subtitle: Text(
                    [partner.displayName, partner.signatureText]
                        .where((part) => part.isNotEmpty)
                        .join(' '),
                  ),
                ),
              const Divider(),
              _SectionTitle('Préférences'),
              ListTile(
                leading: const Icon(Icons.wallpaper_rounded),
                title: const Text("Fonds d'écran"),
                subtitle:
                    const Text("Paris, Noël sous la neige, ou tes images"),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.push('/backgrounds'),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_outlined),
                title: const Text('Notifications'),
                value: settings.notificationsEnabled,
                onChanged: notifier.setNotificationsEnabled,
              ),
              SwitchListTile(
                secondary: const Icon(Icons.volume_up_outlined),
                title: const Text('Sons'),
                value: settings.soundEnabled,
                onChanged: notifier.setSoundEnabled,
              ),
              ListTile(
                leading: const Icon(Icons.brightness_6_outlined),
                title: const Text('Thème'),
                trailing: DropdownButton<ThemeMode>(
                  value: settings.themeMode,
                  underline: const SizedBox.shrink(),
                  onChanged: (mode) {
                    if (mode != null) notifier.setThemeMode(mode);
                  },
                  items: const [
                    DropdownMenuItem(
                      value: ThemeMode.system,
                      child: Text('Système'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.light,
                      child: Text('Clair'),
                    ),
                    DropdownMenuItem(
                      value: ThemeMode.dark,
                      child: Text('Sombre'),
                    ),
                  ],
                ),
              ),
              const Divider(),
              _SectionTitle('Souvenirs'),
              const _SaveAllTile(),
              const _UpdateTile(),
              const Divider(),
              _SectionTitle('Compte'),
              _GoogleAccountTile(email: ref.watch(googleLinkProvider)),
              ListTile(
                leading: const Icon(Icons.link_off_rounded),
                title: const Text('Dissocier le partenaire'),
                onTap: () => _confirmUnlink(context, ref),
              ),
              ListTile(
                leading: const Icon(Icons.logout_rounded),
                title: const Text('Se déconnecter'),
                onTap: () => _confirmSignOut(context, ref),
              ),
              ListTile(
                leading: Icon(
                  Icons.delete_forever_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Supprimer mon compte',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _confirmDelete(context, ref),
              ),
              const SizedBox(height: 24),
              Center(
                child: Text(
                  Personal.storyLine,
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).hintColor,
                    letterSpacing: 4,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _editName(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ton prénom'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (name != null && name.isNotEmpty) {
      await ref.read(authControllerProvider).updateDisplayName(name);
    }
  }

  Future<void> _editSignature(
    BuildContext context,
    WidgetRef ref,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    final signature = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Mon petit surnom'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 40,
          decoration: const InputDecoration(hintText: 'Ex : 🌻'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (signature != null) {
      await ref.read(personalControllerProvider).updateSignature(signature);
    }
  }

  Future<void> _confirmUnlink(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      title: 'Dissocier le partenaire ?',
      body: 'Vous ne pourrez plus vous envoyer de dessins, et tout votre '
          'historique de dessins sera effacé pour vous deux. Cette action est '
          'irréversible.',
      confirmLabel: 'Dissocier',
    );
    if (ok) await ref.read(coupleControllerProvider).unlink();
  }

  /// Le compte est anonyme (lié à cette installation) : se déconnecter le
  /// rend définitivement inaccessible. On prévient clairement.
  Future<void> _confirmSignOut(BuildContext context, WidgetRef ref) async {
    final googleEmail = ref.read(googleLinkProvider);
    final ok = await _confirm(
      context,
      title: 'Se déconnecter ?',
      body: googleEmail != null
          ? 'Tu pourras retrouver ton compte, ton partenaire et vos dessins en '
              'te reconnectant avec Google ($googleEmail).'
          : 'Ton compte Duo est lié à ce téléphone. Si tu te déconnectes, tu '
              'ne pourras plus le retrouver : ni ton partenaire, ni vos '
              "dessins. Sécurise-le d'abord avec Google (ci-dessus).",
      confirmLabel:
          googleEmail != null ? 'Me déconnecter' : 'Me déconnecter quand même',
    );
    if (ok) await ref.read(authControllerProvider).signOut();
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final ok = await _confirm(
      context,
      title: 'Supprimer ton compte ?',
      body: 'Ton compte, ton espace à deux et tous vos dessins seront '
          'supprimés définitivement.',
      confirmLabel: 'Supprimer',
    );
    if (ok) await ref.read(authControllerProvider).deleteAccount();
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

/// « Sécuriser mon compte avec Google » tant que le compte est anonyme,
/// puis l'adresse liée.
class _GoogleAccountTile extends ConsumerStatefulWidget {
  const _GoogleAccountTile({required this.email});

  final String? email;

  @override
  ConsumerState<_GoogleAccountTile> createState() => _GoogleAccountTileState();
}

class _GoogleAccountTileState extends ConsumerState<_GoogleAccountTile> {
  bool _busy = false;

  Future<void> _link() async {
    setState(() => _busy = true);
    final result = await ref.read(authControllerProvider).linkWithGoogle();
    if (!mounted) return;
    setState(() => _busy = false);
    result.when(
      success: (linked) {
        if (linked) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Compte sécurisé avec Google ✅'),
            ),
          );
        }
      },
      failure: (message) => ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final email = widget.email;
    if (email != null) {
      return ListTile(
        leading: const Icon(Icons.verified_user_outlined),
        title: const Text('Compte sécurisé avec Google'),
        subtitle:
            Text(email.isEmpty ? 'Récupérable sur un autre téléphone' : email),
      );
    }
    return ListTile(
      leading: Icon(
        Icons.shield_outlined,
        color: Theme.of(context).colorScheme.primary,
      ),
      title: const Text('Sécuriser mon compte avec Google'),
      subtitle: const Text(
        'Pour retrouver vos dessins si tu changes de téléphone',
      ),
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right_rounded),
      onTap: _busy ? null : _link,
    );
  }
}

/// « Sauvegarder tous nos dessins » : tout l'historique en photos polaroïd
/// dans la galerie (album Duo).
/// Recherche d'une nouvelle version de Duo, installée depuis l'app.
class _UpdateTile extends StatefulWidget {
  const _UpdateTile();

  @override
  State<_UpdateTile> createState() => _UpdateTileState();
}

class _UpdateTileState extends State<_UpdateTile> {
  final Future<String?> _version = AppUpdateService.version();
  bool _checking = false;

  Future<void> _check() async {
    setState(() => _checking = true);
    final status = await AppUpdateService.run(
      GoRouter.of(context).routerDelegate.navigatorKey,
    );
    if (!mounted) return;
    setState(() => _checking = false);
    final text = switch (status) {
      UpdateStatus.upToDate => 'Duo est à jour 🐞',
      UpdateStatus.started || UpdateStatus.canceled => null,
      UpdateStatus.error => "Impossible de vérifier pour l'instant.",
    };
    if (text != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _version,
      builder: (context, snapshot) => ListTile(
        leading: const Icon(Icons.system_update_rounded),
        title: const Text('Rechercher une mise à jour'),
        subtitle: snapshot.data == null ? null : Text('Version ${snapshot.data}'),
        trailing: _checking
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : null,
        onTap: _checking ? null : _check,
      ),
    );
  }
}

class _SaveAllTile extends ConsumerStatefulWidget {
  const _SaveAllTile();

  @override
  ConsumerState<_SaveAllTile> createState() => _SaveAllTileState();
}

class _SaveAllTileState extends ConsumerState<_SaveAllTile> {
  int? _done;

  Future<void> _saveAll() async {
    final drawings = ref.read(historyProvider).valueOrNull ?? const [];
    if (drawings.isEmpty) return;
    final uid = ref.read(currentUidProvider);
    final me = ref.read(currentUserProvider).valueOrNull?.displayName ?? 'Moi';
    final partner =
        ref.read(partnerProvider).valueOrNull?.displayName ?? 'Ton amour';

    setState(() => _done = 0);
    final result = await DrawingExportService.saveAllToGallery(
      drawings,
      subcaptionFor: (drawing) {
        final author = drawing.senderId == uid ? me : partner;
        final date = drawing.createdAt;
        return date == null
            ? author
            : '$author · ${DateFormat('d MMMM yyyy', 'fr').format(date)}';
      },
      onProgress: (done) {
        if (mounted) setState(() => _done = done);
      },
    );
    if (!mounted) return;
    setState(() => _done = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result.when(
            success: (count) =>
                '$count dessin${count > 1 ? 's' : ''} enregistré${count > 1 ? 's' : ''} dans ta galerie (album Duo) 📷',
            failure: (message) => message,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = ref.watch(historyProvider).valueOrNull?.length ?? 0;
    final done = _done;
    return ListTile(
      leading: const Icon(Icons.photo_library_outlined),
      title: const Text('Sauvegarder tous nos dessins'),
      subtitle: Text(
        done != null
            ? 'Enregistrement… $done / $count'
            : 'En photos dans ta galerie ($count dessin${count > 1 ? 's' : ''})',
      ),
      trailing: done != null
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded),
      onTap: done != null || count == 0 ? null : _saveAll,
    );
  }
}
