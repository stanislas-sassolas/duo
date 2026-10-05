import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_constants.dart';
import '../core/theme/app_colors.dart';
import '../models/placed_sticker.dart';
import '../models/stroke.dart';
import '../presentation/canvas/drawing_controller.dart';
import '../providers/sticker_providers.dart';
import 'stroke_painter.dart';

/// Zone de dessin interactive reliée à un [CanvasController].
///
/// Utilise [Listener] (événements pointeur bruts) pour capter aussi bien le
/// doigt que le stylet, avec une latence minimale.
///
/// Le canvas a un ratio fixe ([AppConstants.canvasAspectRatio]) centré dans
/// l'espace disponible : les coordonnées normalisées ont ainsi le même sens
/// sur tous les écrans, et le dessin n'est jamais étiré à l'affichage.
class DrawingCanvas extends StatefulWidget {
  const DrawingCanvas({
    super.key,
    required this.controller,
    this.background = Colors.white,
    this.elevated = false,
    this.stickerImages = const {},
  });

  final CanvasController controller;
  final Color background;

  /// Ombre douce sous la feuille (écran de dessin).
  final bool elevated;

  /// Images des stickers importés (id → image).
  final Map<String, ui.Image> stickerImages;

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

/// Un doigt dessine ; deux doigts zooment (1× à 5×) et déplacent la feuille.
///
/// Quand un sticker vient d'être posé (sélectionné) : un doigt le déplace,
/// deux doigts l'agrandissent et le tournent ; toucher ailleurs le valide.
class _DrawingCanvasState extends State<DrawingCanvas> {
  final Map<int, Offset> _pointers = {};

  // Édition du sticker sélectionné.
  bool _draggingSticker = false;
  bool _transformingSticker = false;
  bool _ignoreTouch = false;
  Offset _lastCanvasPoint = Offset.zero;
  PlacedSticker? _stickerBase;
  double _startAngle = 0;

  /// Vrai dès qu'un 2e doigt s'est posé, jusqu'à ce que tous soient levés :
  /// on ne dessine plus pendant ce geste.
  bool _gesture = false;
  bool _drawing = false;

  /// Stylet en train de dessiner : les doigts (la paume posée sur la
  /// tablette) sont alors ignorés.
  int? _stylus;

  static bool _isStylus(PointerEvent event) =>
      event.kind == PointerDeviceKind.stylus ||
      event.kind == PointerDeviceKind.invertedStylus;

  // Début du geste à deux doigts.
  double _startZoom = 1;
  Offset _startPan = Offset.zero;
  Offset _startFocal = Offset.zero;
  double _startDistance = 1;

  CanvasController get _c => widget.controller;

  (Offset, double) _focalAndDistance() {
    final points = _pointers.values.take(2).toList();
    final focal = (points[0] + points[1]) / 2;
    final distance = (points[0] - points[1]).distance;
    return (focal, distance < 1 ? 1 : distance);
  }

  double _angle() {
    final points = _pointers.values.take(2).toList();
    final d = points[1] - points[0];
    return math.atan2(d.dy, d.dx);
  }

  void _onDown(PointerDownEvent event) {
    _pointers[event.pointer] = event.localPosition;

    // Un sticker est en cours d'édition.
    if (_c.selectedSticker != null || _draggingSticker || _transformingSticker) {
      if (_pointers.length == 1) {
        final point = _c.toCanvas(event.localPosition);
        if (_c.hitsSelected(point)) {
          _draggingSticker = true;
          _lastCanvasPoint = point;
        } else {
          // Toucher ailleurs : le sticker est validé, ce toucher ne dessine pas.
          _c.deselect();
          _ignoreTouch = true;
        }
        return;
      }
      if (_pointers.length == 2 && _c.selectedSticker != null) {
        _draggingSticker = false;
        _transformingSticker = true;
        _stickerBase = _c.selected;
        _startDistance = _focalAndDistance().$2;
        _startAngle = _angle();
        return;
      }
    }
    if (_ignoreTouch) return;

    // Stylet : il dessine toujours, même si la paume touche déjà l'écran.
    if (_isStylus(event)) {
      if (_drawing) _c.cancelStroke();
      _pointers
        ..clear()
        ..[event.pointer] = event.localPosition;
      _stylus = event.pointer;
      _gesture = false;
      _drawing = true;
      _c.startStroke(_c.toCanvas(event.localPosition));
      return;
    }
    if (_stylus != null) {
      _pointers.remove(event.pointer);
      return;
    }

    if (_pointers.length == 1 && !_gesture) {
      _drawing = true;
      _c.startStroke(_c.toCanvas(event.localPosition));
    } else if (_pointers.length == 2) {
      // Deuxième doigt : ce n'était pas un trait, mais un zoom.
      if (_drawing) _c.cancelStroke();
      _drawing = false;
      _gesture = true;
      final (focal, distance) = _focalAndDistance();
      _startZoom = _c.zoom;
      _startPan = _c.pan;
      _startFocal = focal;
      _startDistance = distance;
    }
  }

  void _onMove(PointerMoveEvent event) {
    if (!_pointers.containsKey(event.pointer)) return;
    _pointers[event.pointer] = event.localPosition;
    if (_transformingSticker && _pointers.length >= 2 && _stickerBase != null) {
      final scale = _focalAndDistance().$2 / _startDistance;
      _c.transformSelected(_stickerBase!, scale, _angle() - _startAngle);
      return;
    }
    if (_draggingSticker) {
      final point = _c.toCanvas(event.localPosition);
      _c.moveSelected(point - _lastCanvasPoint);
      _lastCanvasPoint = point;
      return;
    }
    if (_ignoreTouch) return;
    if (_drawing) {
      _c.addPoint(_c.toCanvas(event.localPosition));
    } else if (_gesture && _pointers.length >= 2) {
      final (focal, distance) = _focalAndDistance();
      final zoom = (_startZoom * distance / _startDistance).clamp(1.0, 5.0);
      // Le point du dessin sous les doigts au départ suit les doigts.
      final anchor = (_startFocal - _startPan) / _startZoom;
      _c.setView(zoom, focal - anchor * zoom);
    }
  }

  void _onUp(PointerEvent event) {
    _pointers.remove(event.pointer);
    if (event.pointer == _stylus) _stylus = null;
    if (_drawing) {
      _drawing = false;
      _c.endStroke();
    }
    if (_pointers.length < 2) _transformingSticker = false;
    if (_pointers.isEmpty) {
      _gesture = false;
      _draggingSticker = false;
      _ignoreTouch = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: AspectRatio(
        aspectRatio: AppConstants.canvasAspectRatio,
        child: widget.elevated
            ? DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1A3A1F2A),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: _buildCanvas(),
              )
            : _buildCanvas(),
      ),
    );
  }

  Widget _buildCanvas() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _c.canvasSize = size;

        return ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            children: [
              Container(
                width: size.width,
                height: size.height,
                color: widget.background,
                child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: _onDown,
                  onPointerMove: _onMove,
                  onPointerUp: _onUp,
                  onPointerCancel: _onUp,
                  child: RepaintBoundary(
                    // AnimatedBuilder reconstruit le peintre à CHAQUE point ajouté :
                    // le trait en cours s'affiche en direct.
                    child: AnimatedBuilder(
                      animation: _c,
                      builder: (context, _) => Stack(
                        children: [
                          Positioned.fill(
                            child: Transform(
                              transform: Matrix4.identity()
                                ..translateByDouble(_c.pan.dx, _c.pan.dy, 0, 1)
                                ..scaleByDouble(_c.zoom, _c.zoom, 1, 1),
                              child: CustomPaint(
                                isComplex: true,
                                willChange: true,
                                painter: StrokePainter(
                                  strokes: _c.renderStrokes,
                                  background: widget.background,
                                  stickers: _c.stickers,
                                  stickerImages: widget.stickerImages,
                                  selectedSticker: _c.selectedSticker,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Revenir à la feuille entière (hors de la zone de dessin : le
              // toucher ne trace rien).
              // Retirer le sticker en cours d'édition.
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  final sticker = _c.selected;
                  if (sticker == null) return const SizedBox.shrink();
                  final half = sticker.width * size.width * _c.zoom / 2;
                  final center = _c.pan +
                      Offset(
                        sticker.x * size.width,
                        sticker.y * size.height,
                      ) * _c.zoom;
                  return Positioned(
                    left: (center.dx + half - 4).clamp(0.0, size.width - 40),
                    top: (center.dy - half - 36).clamp(0.0, size.height - 40),
                    child: IconButton.filled(
                      tooltip: 'Retirer le sticker',
                      visualDensity: VisualDensity.compact,
                      iconSize: 18,
                      onPressed: _c.deleteSelected,
                      icon: const Icon(Icons.close_rounded),
                    ),
                  );
                },
              ),
              AnimatedBuilder(
                animation: _c,
                builder: (context, _) => _c.isZoomed
                    ? Positioned(
                        top: 10,
                        right: 10,
                        child: IconButton.filledTonal(
                          tooltip: 'Voir toute la feuille',
                          onPressed: _c.resetView,
                          icon: const Icon(Icons.zoom_out_map_rounded),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Aperçu non interactif d'un dessin (historique, home, détail).
class DrawingPreview extends ConsumerWidget {
  const DrawingPreview({
    super.key,
    required this.strokes,
    this.stickers = const [],
    this.aspectRatio = AppConstants.canvasAspectRatio,
    this.background = Colors.white,
    this.progress = 1.0,
    this.repaint,
    this.bordered = true,
  });

  final List<Stroke> strokes;
  final List<PlacedSticker> stickers;

  /// Cadre arrondi avec bordure (désactivé dans un [Polaroid]).
  final bool bordered;

  /// Ratio largeur / hauteur du canvas d'origine (voir [Drawing.aspectRatio]).
  final double aspectRatio;
  final Color background;
  final double progress;
  final Listenable? repaint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final images = stickers.any((s) => !s.isEmoji)
        ? ref.watch(stickerImagesProvider).valueOrNull ??
            const <String, ui.Image>{}
        : const <String, ui.Image>{};
    final painter = StrokePainter(
      strokes: strokes,
      background: background,
      progress: progress,
      repaint: repaint,
      stickers: stickers,
      stickerImages: images,
    );
    return Center(
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: bordered
            ? DecoratedBox(
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.lightBorder),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: CustomPaint(
                    painter: painter,
                    child: const SizedBox.expand(),
                  ),
                ),
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: CustomPaint(
                  painter: painter,
                  child: const SizedBox.expand(),
                ),
              ),
      ),
    );
  }
}
