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

  /// Echte Check-ins (ohne Seed), chronologisch. Basis für Momentum/Todeszone.
  List<CheckIn> get realCheckIns =>
      checkInsChrono.where((c) => !c.isSeed).toList(growable: false);

  int get realCheckInCount => realCheckIns.length;

  CheckIn? get lastCheckIn {
    if (checkIns.isEmpty) return null;
    return checkInsChrono.last;
  }

  /// Der gefühlte Stand (letzter Check-in, Seed eingeschlossen), sonst 0.
  int get feltPercent => lastCheckIn?.feltPercent ?? 0;

  List<DeltaItem> get openDeltas =>
      deltas.where((d) => d.isOpen).toList(growable: false);

  List<DeltaItem> get resolvedDeltas =>
      deltas.where((d) => !d.isOpen).toList(growable: false);

  /// Der letzte Zeitpunkt mit *tatsächlicher Veränderung*. Aktualisiert sich,
  /// wenn bei einem Check-in mindestens eines passiert:
  ///  - ein Delta wurde abgehakt,
  ///  - ein neues Delta wurde angelegt,
  ///  - feltPercent hat sich um ≥ 1 verändert.
  /// Ein Check-in ohne jede Änderung (Slider auf denselben Wert) zählt nicht.
  DateTime get lastMeaningfulChange {
    var latest = createdAt;
    for (final d in deltas) {
      if (d.createdAt.isAfter(latest)) latest = d.createdAt;
      final r = d.resolvedAt;
      if (r != null && r.isAfter(latest)) latest = r;
    }
    // Check-ins, die den gefühlten Prozentsatz um ≥ 1 bewegt haben.
    final chrono = checkInsChrono;
    for (var i = 1; i < chrono.length; i++) {
      if ((chrono[i].feltPercent - chrono[i - 1].feltPercent).abs() >= 1) {
        if (chrono[i].date.isAfter(latest)) latest = chrono[i].date;
      }
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

  /// Richtung der letzten drei *echten* Check-ins. Ohne mindestens drei
  /// echte Check-ins gibt es kein Momentum (null → kein Pfeil, kein Bericht).
  ///
  ///   percentDelta   = feltPercent(n) − feltPercent(n−2)
  ///   deltasResolved = abgehakte Deltas über diese drei Check-ins
  ///   steigend: percentDelta >= +3  ODER  deltasResolved >= 2
  ///   fallend:  percentDelta <= −3
  ///   flach:    alles andere
  Momentum? get momentum {
    // Ein stillgelegtes Projekt hat kein Momentum — historisch korrekt
    // gerechnet wäre inhaltlich Unsinn.
    if (status == ProjectStatus.verhungert ||
        status == ProjectStatus.pausiert ||
        daysSinceMeaningfulChange > kStaleQuestionDays) {
      return null;
    }
    final real = realCheckIns;
    if (real.length < 3) return null;
    final n = real.length;
    final percentDelta = real[n - 1].feltPercent - real[n - 3].feltPercent;
    final windowStart = real[n - 3].date;
    final windowEnd = real[n - 1].date;
    var deltasResolved = 0;
    for (final d in deltas) {
      final r = d.resolvedAt;
      if (r != null && !r.isBefore(windowStart) && !r.isAfter(windowEnd)) {
        deltasResolved++;
      }
    }
    if (percentDelta >= 3 || deltasResolved >= 2) return Momentum.up;
    if (percentDelta <= -3) return Momentum.down;
    return Momentum.flat;
  }

  /// Anzahl aufeinanderfolgender nicht-steigender echter Check-ins am Ende.
  int get flatStreak {
    final real = realCheckIns;
    if (real.length < 3) return 0;
    var streak = 0;
    for (var i = real.length - 1; i > 0; i--) {
      final rising = (real[i].feltPercent - real[i - 1].feltPercent) >= 3;
      if (rising) break;
      streak++;
    }
    return streak;
  }

  /// Die Todeszone: 70–95% mit flachem oder fallendem Momentum — und erst ab
  /// drei echten Check-ins, sonst ist die Kategorie entwertet, bevor sie das
  /// erste Mal etwas bedeutet.
  ///
  /// `momentum == null` bedeutet „kein Momentum feststellbar" (z. B. seit über
  /// 21 Tagen still) — das qualifiziert für die Todeszone, es entwarnt nicht.
  /// Nur ein *steigendes* Momentum schließt aus. Deshalb wird die Drei-Check-in-
  /// Schwelle direkt über [realCheckInCount] geprüft und nicht über `momentum`,
  /// sonst fällt genau das todeszonigste Projekt (hoher Stand, lange still)
  /// durch die Lücke zwischen den beiden `null`-Ursachen.
  bool get inDeathZone {
    if (!status.countsAgainstWip) return false;
    if (realCheckInCount < 3) return false;
    final p = feltPercent;
    return p >= 70 && p <= 95 && momentum != Momentum.up;
  }

  /// Soll die Pausiert-oder-verhungert-Frage gestellt werden?
  bool get needsStaleDecision =>
      status == ProjectStatus.aktiv &&
      daysSinceMeaningfulChange > kStaleQuestionDays;

  /// Ein Delta, das seit über 30 Tagen offen ist — meistens der wahre Grund,
  /// warum das Projekt steht. Wird visuell markiert.
  bool isDeltaStuck(DeltaItem d) {
    if (!d.isOpen) return false;
    return d.ageInDays >= 30;
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
