/// Ein Delta-Item: was konkret zwischen jetzt und 100% liegt.
/// Nicht "noch Feinschliff" — konkrete, benennbare Dinge.
class DeltaItem {
  DeltaItem({
    required this.id,
    required this.text,
    required this.createdAt,
    this.resolvedAt,
    this.isSeed = false,
  });

  final String id;
  String text;
  final DateTime createdAt;
  DateTime? resolvedAt;

  /// Beim Anlegen des Projekts eingetragen — zählt nicht als "Delta neu"
  /// der Woche.
  final bool isSeed;

  bool get isOpen => resolvedAt == null;

  int get ageInDays => DateTime.now().difference(createdAt).inDays;

  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        'createdAt': createdAt.toIso8601String(),
        'resolvedAt': resolvedAt?.toIso8601String(),
        'isSeed': isSeed,
      };

  factory DeltaItem.fromJson(Map<String, dynamic> json) => DeltaItem(
        id: json['id'] as String,
        text: json['text'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        resolvedAt: json['resolvedAt'] == null
            ? null
            : DateTime.parse(json['resolvedAt'] as String),
        isSeed: json['isSeed'] as bool? ?? false,
      );
}
