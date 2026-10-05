import 'package:intl/intl.dart';

/// Libellés de temps doux, en français (« il y a 5 min », « hier à 21:04 »).
class TimeLabels {
  TimeLabels._();

  /// Moment d'un dessin, relatif à [now].
  static String relative(DateTime? date, {DateTime? now}) {
    if (date == null) return '';
    final current = now ?? DateTime.now();
    final diff = current.difference(date);
    if (diff.inMinutes < 1) return 'à l\'instant';
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (_sameDay(date, current)) {
      return 'aujourd\'hui à ${DateFormat.Hm('fr').format(date)}';
    }
    if (_sameDay(date, current.subtract(const Duration(days: 1)))) {
      return 'hier à ${DateFormat.Hm('fr').format(date)}';
    }
    return DateFormat('d MMM', 'fr').format(date);
  }

  /// Titre de section d'un jour (« Aujourd'hui », « Hier », « 12 septembre »).
  static String day(DateTime date, {DateTime? now}) {
    final current = now ?? DateTime.now();
    if (_sameDay(date, current)) return 'Aujourd\'hui';
    if (_sameDay(date, current.subtract(const Duration(days: 1)))) {
      return 'Hier';
    }
    final pattern = date.year == current.year ? 'd MMMM' : 'd MMMM yyyy';
    return DateFormat(pattern, 'fr').format(date);
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
