import '../core/constants/app_constants.dart';

/// Outils de dessin disponibles sur le canvas.
///
/// Sérialisé sous forme de [String] stable pour rester compatible même si
/// l'ordre de l'enum change plus tard.
enum BrushTool {
  /// Feutre (trait plein).
  pen('pen'),

  /// Surligneur : large et transparent.
  highlighter('highlighter'),

  /// Néon : trait lumineux avec un halo.
  neon('neon'),

  eraser('eraser');

  const BrushTool(this.id);

  /// Identifiant stable stocké dans Firestore.
  final String id;

  static BrushTool fromId(String? id) {
    return BrushTool.values.firstWhere(
      (tool) => tool.id == id,
      orElse: () => BrushTool.pen,
    );
  }
}

/// Tailles de pinceau proposées à l'utilisateur.
enum BrushSize {
  /// Très fin, pour les détails (au stylet, sur tablette).
  hairline('hairline', 1.2),
  thin('thin', 4),
  medium('medium', 9),
  thick('thick', 18);

  const BrushSize(this.id, this.strokeWidth);

  /// Identifiant stable stocké dans Firestore.
  final String id;

  /// Largeur en pixels sur le canvas de référence (aussi utilisée pour
  /// l'aperçu du sélecteur).
  final double strokeWidth;

  /// Largeur exprimée en fraction de la largeur du canvas : c'est la valeur
  /// stockée dans un [Stroke], pour un rendu identique sur tous les écrans.
  double get relativeWidth => strokeWidth / AppConstants.referenceCanvasWidth;

  static BrushSize fromId(String? id) {
    return BrushSize.values.firstWhere(
      (size) => size.id == id,
      orElse: () => BrushSize.medium,
    );
  }
}
