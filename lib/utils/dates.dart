/// Deutsche, vorwurfsvolle Zeitangaben — ohne intl-Abhängigkeit.
String agoLabel(int days) {
  if (days <= 0) return 'heute';
  if (days == 1) return 'vor 1 Tag';
  return 'vor $days Tagen';
}

String shortDate(DateTime d) {
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd.$mm.${d.year}';
}

/// ISO-8601 Kalenderwoche.
int isoWeekNumber(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  // Donnerstag der aktuellen Woche bestimmt das Jahr.
  final thursday = d.add(Duration(days: 3 - ((d.weekday + 6) % 7)));
  final firstThursday = DateTime(thursday.year, 1, 4);
  final firstThursdayAdjusted = firstThursday
      .add(Duration(days: 3 - ((firstThursday.weekday + 6) % 7)));
  final diff = thursday.difference(firstThursdayAdjusted).inDays;
  return 1 + (diff ~/ 7);
}

int isoWeekYear(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  final thursday = d.add(Duration(days: 3 - ((d.weekday + 6) % 7)));
  return thursday.year;
}

/// Montag 00:00 der Woche, in der [date] liegt.
DateTime startOfWeek(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return d.subtract(Duration(days: (d.weekday + 6) % 7));
}
