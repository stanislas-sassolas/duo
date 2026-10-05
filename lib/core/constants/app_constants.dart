/// Constantes globales de l'application.
class AppConstants {
  AppConstants._();

  static const String appName = 'Duo';
  static const String appTagline = 'Un petit dessin pour quelqu\'un que tu aimes';

  // Collections Firestore
  static const String usersCollection = 'users';
  static const String couplesCollection = 'couples';
  static const String invitesCollection = 'invites';
  static const String drawingsSubcollection = 'drawings';

  /// Durée de validité d'un code d'invitation.
  static const Duration inviteValidity = Duration(days: 7);

  // Storage
  static const String thumbnailsPath = 'thumbnails';

  // Canvas
  /// Ratio largeur / hauteur fixe du canvas (portrait 3:4). Identique sur tous
  /// les écrans : un dessin n'est jamais déformé, où qu'il soit affiché.
  static const double canvasAspectRatio = 3 / 4;

  /// Largeur de canvas de référence (px logiques). Sert à convertir les
  /// épaisseurs de pinceau en fraction de la largeur, et à relire les anciens
  /// dessins dont l'épaisseur était stockée en pixels absolus.
  static const double referenceCanvasWidth = 360;

  // Limites (cohérentes avec les Security Rules)
  static const int maxStrokesPerDrawing = 5000;

  /// Plafond de points par dessin (après simplification). Un point pèse
  /// ~60 octets dans Firestore : 12 000 points ≈ 700 Ko, sous la limite de
  /// 1 Mio par document.
  static const int maxPointsPerDrawing = 12000;
  static const int maxMessageLength = 140;

  // Clés de préférences locales
  static const String prefSoundEnabled = 'pref_sound_enabled';
  static const String prefNotificationsEnabled = 'pref_notifications_enabled';
  static const String prefThemeMode = 'pref_theme_mode';
  static const String prefMusicEnabled = 'pref_music_enabled';
  static const String prefCustomBackgrounds = 'pref_custom_backgrounds';
  static const String prefRecentColors = 'pref_recent_colors';
  static const String prefOutbox = 'pref_outbox_drawings';
  static const String prefDisplayName = 'pref_display_name';
  static const String prefUpdateAsked = 'pref_update_asked';
  static const String prefLastNotifiedDrawingAt = 'pref_last_notified_drawing_at';
}
