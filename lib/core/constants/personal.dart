/// Touches personnelles de Duo.
///
/// Tout ce qui est propre à un couple est regroupé ici : c'est le seul fichier
/// à modifier pour proposer un surnom par défaut, des petits mots ou un easter
/// egg. La version publique est volontairement neutre.
class Personal {
  Personal._();

  /// Surnom affiché à côté du prénom (visible par l'autre), proposé au
  /// premier lancement selon le prénom. Modifiable ensuite dans Paramètres.
  static const Map<String, String> defaultSignatures = {
    'alex': '🌻',
  };

  /// Petits mots proposés à l'envoi d'un dessin, **propres à chacun** (la
  /// liste de l'un n'apparaît jamais chez l'autre). Pré-remplis au premier
  /// lancement selon le prénom, puis modifiables dans Paramètres.
  static const Map<String, List<String>> defaultPhrases = {
    'sam': [
      '❤️ Bisous',
      '☀️ Bonne journée',
      '🌙 Bonne nuit',
    ],
  };

  /// Petits emojis qui s'envolent quand on appuie longuement sur le ❤️ de
  /// l'accueil.
  static const List<String> easterEggs = ['🐞', '⭐', '🌻', '☀️'];

  /// Emojis de l'animation « envoyé ».
  static const List<String> sentEmojis = ['❤️', '☀️', '⭐', '🌻'];

  /// Ligne discrète en bas des Paramètres.
  static const String storyLine = '';

  /// Citation affichée au démarrage (Le Petit Prince).
  static const String littlePrinceQuote = 'On ne voit bien qu\'avec le cœur.';

  /// Prénoms qui voient les dessins tout prêts (assets/sketches/sketches.json)
  /// dans la feuille des stickers. Invisibles pour les autres.
  static const Set<String> secretSketchesFor = {};

  static bool seesSecretSketches(String displayName) =>
      secretSketchesFor.contains(_key(displayName));

  static String _key(String displayName) =>
      displayName.trim().toLowerCase().split(RegExp(r'\s+')).first;

  static String defaultSignatureFor(String displayName) =>
      defaultSignatures[_key(displayName)] ?? '';

  static List<String> defaultPhrasesFor(String displayName) =>
      defaultPhrases[_key(displayName)] ?? const [];

  /// `true` si le surnom ne contient que des emojis / symboles (pas de
  /// lettres) : il s'affiche alors collé au prénom, sinon en dessous.
  static bool isEmojiOnly(String signature) =>
      signature.isNotEmpty && !RegExp(r'[A-Za-zÀ-ÿ0-9]').hasMatch(signature);
}
