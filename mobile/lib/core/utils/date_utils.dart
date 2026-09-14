/// Date helpers shared across the app.
library;

import 'package:intl/intl.dart';

class AppDateUtils {
  AppDateUtils._();

  static String todayIso() => DateFormat('yyyy-MM-dd').format(DateTime.now());

  /// e.g. "11 Sep"
  static String shortDay(DateTime date) => DateFormat('d MMM').format(date);

  /// e.g. "11 September 2025"
  static String fullDay(DateTime date) => DateFormat('d MMMM yyyy').format(date);

  static DateTime fromIso(String iso) => DateTime.parse(iso);

  /// e.g. "2025-09-11" - the wire date format used by the API.
  static String toIso(DateTime date) => DateFormat('yyyy-MM-dd').format(date);

  /// e.g. "14:05"
  static String timeLabel(DateTime date) => DateFormat('HH:mm').format(date);
}