/// Ein Projekt für tot erklären ist ein echtes Feature mit eigenem Flow —
/// kein Löschen im Kontextmenü. Grund + Learning sind Pflicht.
class BurialRecord {
  BurialRecord({
    required this.date,
    required this.reason,
    required this.learning,
  });

  final DateTime date;
  final String reason;
  final String learning;

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'reason': reason,
        'learning': learning,
      };

  factory BurialRecord.fromJson(Map<String, dynamic> json) => BurialRecord(
        date: DateTime.parse(json['date'] as String),
        reason: json['reason'] as String,
        learning: json['learning'] as String,
      );
}
