import 'burial_record.dart';
import 'check_in.dart';
import 'delta_item.dart';
import 'enums.dart';
import 'staleness.dart';

/// Nach wie vielen Tagen Stille die Pausiert-oder-verhungert-Frage kommt.
const int kStaleQuestionDays = 21;

class Project {
  Project({
    required this.id,
    required this.name,
    required this.category,
    required this.definitionOfDone,
    required this.createdAt,
    this.status = ProjectStatus.aktiv,
    List<CheckIn>? checkIns,
    List<DeltaItem>? deltas,
    this.burial,
    this.pauseReason,
    this.resumeDate,
  })  : checkIns = checkIns ?? [],
        deltas = deltas ?? [];

  final String id;
  String name;
  Category category;
  String definitionOfDone;
  final DateTime createdAt;
  ProjectStatus status;

  final List<CheckIn> checkIns;
  final List<DeltaItem> deltas;

  BurialRecord? burial;
  String? pauseReason;
  DateTime? resumeDate;

  // ---------------------------------------------------------------------------
  // Abgeleitete Werte
  // ---------------------------------------------------------------------------

  List<CheckIn> get checkInsChrono =>
      [...checkIns]..sort((a, b) => a.date.compareTo(b.date));

  CheckIn? get lastCheckIn {
    if (checkIns.isEmpty) return null;
    return checkInsChrono.last;
  }

  /// Der gefühlte Stand (letzter Check-in), sonst 0.
  int get feltPercent => lastCheckIn?.feltPercent ?? 0;

  List<DeltaItem> get openDeltas =>
      deltas.where((d) => d.isOpen).toList(growable: false);

  List<DeltaItem> get resolvedDeltas =>
      deltas.where((d) => !d.isOpen).toList(growable: false);

  /// Der letzte Zeitpunkt mit *tatsächlicher Veränderung*:
  /// ein Delta wurde angelegt oder abgehakt. Nur Slider-Antippen zählt nicht.
  DateTime get lastMeaningfulChange {
    var latest = createdAt;
    for (final d in deltas) {
      if (d.createdAt.isAfter(latest)) latest = d.createdAt;
      final r = d.resolvedAt;
      if (r != null && r.isAfter(latest)) latest = r;
    }
    return latest;
  }

  int _daysSince(DateTime from) {
    final now = DateTime.now();
    final a = DateTime(from.year, from.month, from.day);
    final b = DateTime(now.year, now.month, now.day);
    return b.difference(a).inDays;
  }

  int get daysSinceMeaningfulChange => _daysSince(lastMeaningfulChange);

  int get daysSinceCheckIn =>
      _daysSince(lastCheckIn?.date ?? createdAt);

  /// Pausierte Projekte verrotten nicht — Decay stoppt.
  Staleness get staleness {
    if (status == ProjectStatus.pausiert ||
        status == ProjectStatus.abgeschlossen ||
        status == ProjectStatus.beerdigt) {
      return Staleness.frisch;
    }
    return Staleness.fromDays(daysSinceMeaningfulChange);
  }

  /// Richtung der letzten (bis zu drei) Check-ins.
  Momentum get momentum {
    final chrono = checkInsChrono;
    if (chrono.length < 2) return Momentum.flat;
    final window = chrono.length <= 3
        ? chrono
        : chrono.sublist(chrono.length - 3);
    final diff = window.last.feltPercent - window.first.feltPercent;
    if (diff > 2) return Momentum.up;
    if (diff < -2) return Momentum.down;
    return Momentum.flat;
  }

  /// Wie viele Check-ins am Stück das Momentum schon flach/fallend ist.
  int get flatStreak {
    final chrono = checkInsChrono;
    if (chrono.length < 2) return 0;
    var streak = 0;
    for (var i = chrono.length - 1; i > 0; i--) {
      final diff = chrono[i].feltPercent - chrono[i - 1].feltPercent;
      if (diff <= 2) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Die Todeszone: 70–95% mit flachem oder fallendem Momentum.
  /// Spezifisch dein Muster — die App macht daraus eine benannte Kategorie.
  bool get inDeathZone {
    if (!status.countsAgainstWip) return false;
    final p = feltPercent;
    return p >= 70 && p <= 95 && momentum != Momentum.up;
  }

  /// Soll beim Öffnen die Pausiert-oder-verhungert-Frage gestellt werden?
  bool get needsStaleDecision =>
      status == ProjectStatus.aktiv &&
      daysSinceMeaningfulChange >= kStaleQuestionDays;

  /// Ein Delta, das seit über 60 Tagen offen ist — meistens der wahre Grund,
  /// warum das Projekt steht.
  bool isDeltaStuck(DeltaItem d) {
    if (!d.isOpen) return false;
    final now = DateTime.now();
    return now.difference(d.createdAt).inDays >= 60;
  }

  // ---------------------------------------------------------------------------
  // Serialisierung
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'category': category.name,
        'definitionOfDone': definitionOfDone,
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'checkIns': checkIns.map((e) => e.toJson()).toList(),
        'deltas': deltas.map((e) => e.toJson()).toList(),
        'burial': burial?.toJson(),
        'pauseReason': pauseReason,
        'resumeDate': resumeDate?.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> json) => Project(
        id: json['id'] as String,
        name: json['name'] as String,
        category: Category.fromName(json['category'] as String),
        definitionOfDone: json['definitionOfDone'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        status: ProjectStatus.fromName(json['status'] as String),
        checkIns: (json['checkIns'] as List<dynamic>? ?? [])
            .map((e) => CheckIn.fromJson(e as Map<String, dynamic>))
            .toList(),
        deltas: (json['deltas'] as List<dynamic>? ?? [])
            .map((e) => DeltaItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        burial: json['burial'] == null
            ? null
            : BurialRecord.fromJson(json['burial'] as Map<String, dynamic>),
        pauseReason: json['pauseReason'] as String?,
        resumeDate: json['resumeDate'] == null
            ? null
            : DateTime.parse(json['resumeDate'] as String),
      );
}
