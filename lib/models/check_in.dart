/// Ein Check-in — das Herzstück. Ein einziger Input, der alles speist.
class CheckIn {
  CheckIn({
    required this.id,
    required this.date,
    required this.feltPercent,
    this.note,
    this.isSeed = false,
  });

  final String id;
  final DateTime date;

  /// 0–100, gefühlter Prozentsatz (Slider).
  final int feltPercent;

  /// Optionale freie Notiz.
  final String? note;

  /// Der beim Anlegen erzeugte Start-Check-in. Wird von allen Wochen-
  /// Statistiken und der Momentum-/Todeszonen-Berechnung ignoriert —
  /// sonst könnte man sich per Projekt-Import eine Erfolgsbilanz bauen.
  final bool isSeed;

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'feltPercent': feltPercent,
        'note': note,
        'isSeed': isSeed,
      };

  factory CheckIn.fromJson(Map<String, dynamic> json) => CheckIn(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        feltPercent: (json['feltPercent'] as num).round(),
        note: json['note'] as String?,
        isSeed: json['isSeed'] as bool? ?? false,
      );
}
