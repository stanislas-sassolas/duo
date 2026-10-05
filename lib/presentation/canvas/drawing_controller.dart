import 'package:flutter/material.dart';

import '../../models/draw_point.dart';
import '../../models/enums.dart';
import '../../models/placed_sticker.dart';
import '../../models/stroke.dart';

/// État en mémoire d'un dessin en cours d'édition.
///
/// [ChangeNotifier] utilisé comme `repaint` du [CustomPainter] : seule la zone
/// de dessin est repeinte, ce qui garde le tracé fluide (~60 FPS).
class CanvasController extends ChangeNotifier {
  CanvasController();

  final List<Stroke> _strokes = [];
  final List<PlacedSticker> _stickers = [];
  Stroke? _active;

  /// Ordre des ajouts (trait ou sticker), pour annuler dans le bon ordre.
  final List<bool> _history = []; // true = sticker, false = trait
  final List<Object> _redo = [];

  /// Sticker en cours d'édition (déplacer, agrandir, tourner), ou `null`.
  int? _selected;
  int? get selectedSticker => _selected;
  List<PlacedSticker> get stickers => List.unmodifiable(_stickers);

  Size _canvasSize = Size.zero;
  DateTime? _strokeStart;

  // Réglages courants
  BrushTool tool = BrushTool.pen;

  /// Dernier pinceau choisi (hors gomme) : on y revient en choisissant une
  /// couleur.
  BrushTool brush = BrushTool.pen;

  // --- Zoom (pincer à deux doigts) ---
  double _zoom = 1;
  Offset _pan = Offset.zero;
  double get zoom => _zoom;
  Offset get pan => _pan;
  bool get isZoomed => _zoom > 1.01;

  /// Point de l'écran (dans la zone de dessin) → point du dessin.
  Offset toCanvas(Offset local) => (local - _pan) / _zoom;

  /// Applique un zoom (1× à 5×) et un décalage, sans jamais laisser
  /// apparaître de vide autour de la feuille.
  void setView(double zoom, Offset pan) {
    final z = zoom.clamp(1.0, 5.0);
    final minX = _canvasSize.width * (1 - z);
    final minY = _canvasSize.height * (1 - z);
    _zoom = z;
    _pan = Offset(pan.dx.clamp(minX, 0.0), pan.dy.clamp(minY, 0.0));
    notifyListeners();
  }

  void resetView() => setView(1, Offset.zero);

  /// Abandonne le tracé en cours (ex. un 2e doigt se pose pour zoomer).
  void cancelStroke() {
    if (_active == null) return;
    _active = null;
    notifyListeners();
  }
  Color color = const Color(0xFF2B2530);
  BrushSize size = BrushSize.medium;

  /// Strokes validés (immuables). Copie défensive.
  List<Stroke> get strokes => List.unmodifiable(_strokes);

  /// Strokes à peindre = validés + tracé en cours.
  ///
  /// Toujours une **nouvelle** liste : [StrokePainter.shouldRepaint] compare
  /// les listes par identité, et renvoyer `_strokes` lui-même empêchait le
  /// canvas de se redessiner après annuler / rétablir / tout effacer.
  List<Stroke> get renderStrokes =>
      List.unmodifiable([..._strokes, if (_active != null) _active!]);

  bool get isEmpty => _strokes.isEmpty && _stickers.isEmpty;
  bool get canUndo => _history.isNotEmpty;
  bool get canRedo => _redo.isNotEmpty;

  set canvasSize(Size value) => _canvasSize = value;

  void selectPen(Color newColor) {
    tool = brush;
    color = newColor;
    notifyListeners();
  }

  void selectBrush(BrushTool newBrush) {
    brush = newBrush;
    tool = newBrush;
    notifyListeners();
  }

  void selectEraser() {
    tool = BrushTool.eraser;
    notifyListeners();
  }

  void selectSize(BrushSize newSize) {
    size = newSize;
    notifyListeners();
  }

  // --- Cycle de vie d'un tracé ---

  void startStroke(Offset position) {
    _strokeStart = DateTime.now();
    _active = Stroke(
      points: [DrawPoint.fromOffset(position, _canvasSize, t: 0)],
      color: color.toARGB32(),
      width: size.relativeWidth,
      tool: tool,
      startedAt: _strokeStart!.millisecondsSinceEpoch,
    );
    notifyListeners();
  }

  void addPoint(Offset position) {
    final active = _active;
    if (active == null) return;
    final t = DateTime.now().difference(_strokeStart!).inMilliseconds;
    active.points.add(DrawPoint.fromOffset(position, _canvasSize, t: t));
    notifyListeners();
  }

  void endStroke() {
    final active = _active;
    if (active == null) return;
    // Ignore les "taps" fantômes d'un seul point sans mouvement notable.
    if (active.points.isNotEmpty) {
      _strokes.add(active);
      _history.add(false);
      _redo.clear();
    }
    _active = null;
    notifyListeners();
  }

  /// Ajoute des traits tout faits (dessins secrets), comme s'ils venaient
  /// d'être tracés : ils s'annulent un par un comme les autres.
  void addStrokes(List<Stroke> strokes) {
    if (strokes.isEmpty) return;
    var start = DateTime.now().millisecondsSinceEpoch;
    for (final stroke in strokes) {
      _strokes.add(
        Stroke(
          points: stroke.points,
          color: stroke.color,
          width: stroke.width,
          tool: stroke.tool,
          startedAt: start,
        ),
      );
      _history.add(false);
      start += (stroke.points.isEmpty ? 0 : stroke.points.last.t) + 400;
    }
    _redo.clear();
    _selected = null;
    notifyListeners();
  }

  // --- Stickers ---

  /// Pose un sticker au centre de la vue et le sélectionne.
  void addSticker({String? stickerId, String? emoji}) {
    final size = _canvasSize == Size.zero ? const Size(1, 1) : _canvasSize;
    final center = toCanvas(size.center(Offset.zero));
    _stickers.add(
      PlacedSticker(
        stickerId: stickerId,
        emoji: emoji,
        x: center.dx / size.width,
        y: center.dy / size.height,
        width: 0.3 / _zoom,
      ),
    );
    _history.add(true);
    _redo.clear();
    _selected = _stickers.length - 1;
    notifyListeners();
  }

  /// Le point (en coordonnées du dessin) touche-t-il le sticker sélectionné ?
  bool hitsSelected(Offset canvasPoint) {
    final index = _selected;
    if (index == null || _canvasSize == Size.zero) return false;
    final sticker = _stickers[index];
    final center = Offset(
      sticker.x * _canvasSize.width,
      sticker.y * _canvasSize.height,
    );
    final radius = sticker.width * _canvasSize.width * 0.75 + 24 / _zoom;
    return (canvasPoint - center).distance <= radius;
  }

  /// Déplace le sticker sélectionné (delta en coordonnées du dessin).
  void moveSelected(Offset delta) {
    final index = _selected;
    if (index == null || _canvasSize == Size.zero) return;
    final sticker = _stickers[index];
    _stickers[index] = sticker.copyWith(
      x: sticker.x + delta.dx / _canvasSize.width,
      y: sticker.y + delta.dy / _canvasSize.height,
    );
    notifyListeners();
  }

  /// Agrandit / tourne le sticker sélectionné à partir de son état [base].
  void transformSelected(PlacedSticker base, double scale, double rotation) {
    final index = _selected;
    if (index == null) return;
    _stickers[index] = _stickers[index].copyWith(
      width: base.width * scale,
      rotation: base.rotation + rotation,
    );
    notifyListeners();
  }

  PlacedSticker? get selected =>
      _selected == null ? null : _stickers[_selected!];

  void deselect() {
    if (_selected == null) return;
    _selected = null;
    notifyListeners();
  }

  void deleteSelected() {
    final index = _selected;
    if (index == null) return;
    _stickers.removeAt(index);
    // Retire l'entrée d'historique correspondante (la n-ième « sticker »).
    var seen = -1;
    for (var i = 0; i < _history.length; i++) {
      if (_history[i]) seen++;
      if (seen == index) {
        _history.removeAt(i);
        break;
      }
    }
    _selected = null;
    notifyListeners();
  }

  // --- Actions ---

  void undo() {
    if (_history.isEmpty) return;
    _selected = null;
    final isSticker = _history.removeLast();
    _redo.add(isSticker ? _stickers.removeLast() : _strokes.removeLast());
    notifyListeners();
  }

  void redo() {
    if (_redo.isEmpty) return;
    final item = _redo.removeLast();
    if (item is PlacedSticker) {
      _stickers.add(item);
      _history.add(true);
    } else {
      _strokes.add(item as Stroke);
      _history.add(false);
    }
    notifyListeners();
  }

  void clear() {
    if (isEmpty && _active == null) return;
    _strokes.clear();
    _stickers.clear();
    _history.clear();
    _redo.clear();
    _active = null;
    _selected = null;
    notifyListeners();
  }
}
