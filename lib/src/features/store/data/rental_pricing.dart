// Mirror of functions/src/store/pricing.ts (keep in sync). Used to show the
// price before sending a request; the server recomputes and stores the real one.

/// "yyyy-mm-dd" of a calendar day (no timezone shifts).
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

DateTime parseDayKey(String s) {
  final p = s.split('-').map(int.parse).toList();
  return DateTime.utc(p[0], p[1], p[2]);
}

/// Days from start to end, both included.
int rentalDays(DateTime start, DateTime end) =>
    DateTime.utc(end.year, end.month, end.day)
        .difference(DateTime.utc(start.year, start.month, start.day))
        .inDays +
    1;

/// A "weekend" rental: 2–3 days, only Fri/Sat/Sun, including Saturday and Sunday.
bool isWeekendRental(DateTime start, DateTime end) {
  final n = rentalDays(start, end);
  if (n < 2 || n > 3) return false;
  final days = List.generate(n, (i) => DateTime.utc(start.year, start.month, start.day + i).weekday);
  return days.contains(DateTime.saturday) &&
      days.contains(DateTime.sunday) &&
      days.every((d) => d == DateTime.friday || d == DateTime.saturday || d == DateTime.sunday);
}

/// Cheapest total combining daily, weekly and weekend prices.
double rentalPrice({
  required double perDay,
  double? perWeekend,
  double? perWeek,
  required DateTime start,
  required DateTime end,
}) {
  final days = rentalDays(start, end);
  if (days < 1) throw ArgumentError('end before start');
  final cost = List<double>.filled(days + 1, 0);
  for (var d = 1; d <= days; d++) {
    cost[d] = cost[d - 1] + perDay;
    if (perWeek != null) {
      final viaWeek = cost[d - 7 < 0 ? 0 : d - 7] + perWeek;
      if (viaWeek < cost[d]) cost[d] = viaWeek;
    }
  }
  var best = cost[days];
  if (perWeekend != null && isWeekendRental(start, end) && perWeekend < best) {
    best = perWeekend;
  }
  return (best * 100).round() / 100;
}
