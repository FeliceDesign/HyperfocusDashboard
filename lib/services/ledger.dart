import 'package:flutter/foundation.dart' hide Category;
import 'package:uuid/uuid.dart';

import '../models/burial_record.dart';
import '../models/check_in.dart';
import '../models/delta_item.dart';
import '../models/enums.dart';
import '../models/project.dart';
import '../utils/dates.dart';
import 'storage.dart';

/// Zentraler Zustand + Geschäftslogik. Ein einziger Input (Check-in)
/// speist alles.
class Ledger extends ChangeNotifier {
  Ledger(this._storage);

  final Storage _storage;
  final _uuid = const Uuid();

  List<Project> _projects = [];
  int _wipLimit = 4;
  int? _pendingWipLimit;
  DateTime? _pendingWipLimitEffectiveAt;
  bool _loaded = false;

  bool get loaded => _loaded;

  Future<void> init() async {
    final data = await _storage.load();
    _projects = data.projects;
    _wipLimit = data.wipLimit;
    _pendingWipLimit = data.pendingWipLimit;
    _pendingWipLimitEffectiveAt = data.pendingWipLimitEffectiveAt;
    _applyPendingWipIfDue();
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storage.save(LedgerData(
      projects: _projects,
      wipLimit: _wipLimit,
      pendingWipLimit: _pendingWipLimit,
      pendingWipLimitEffectiveAt: _pendingWipLimitEffectiveAt,
    ));
  }

  // ---------------------------------------------------------------------------
  // Selektoren
  // ---------------------------------------------------------------------------

  int get wipLimit => _wipLimit;
  int? get pendingWipLimit => _pendingWipLimit;
  DateTime? get pendingWipLimitEffectiveAt => _pendingWipLimitEffectiveAt;

  List<Project> get all => List.unmodifiable(_projects);

  int get activeCount =>
      _projects.where((p) => p.status.countsAgainstWip).length;

  bool get wipFull => activeCount >= _wipLimit;

  Project? byId(String id) {
    for (final p in _projects) {
      if (p.id == id) return p;
    }
    return null;
  }

  /// Live-Projekte, sortiert nach Dringlichkeit — was am meisten verrottet,
  /// steht oben. Nicht nach Name, nicht nach Datum.
  List<Project> get dashboardProjects {
    final live = _projects.where((p) => p.status.isLive).toList();
    live.sort((a, b) {
      // Pausierte immer nach unten.
      final ap = a.status == ProjectStatus.pausiert ? 1 : 0;
      final bp = b.status == ProjectStatus.pausiert ? 1 : 0;
      if (ap != bp) return ap - bp;
      // Danach: was am längsten brachliegt, oben.
      final byRot = b.daysSinceMeaningfulChange
          .compareTo(a.daysSinceMeaningfulChange);
      if (byRot != 0) return byRot;
      // Gleichstand: Todeszone zuerst.
      final az = a.inDeathZone ? 0 : 1;
      final bz = b.inDeathZone ? 0 : 1;
      if (az != bz) return az - bz;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return live;
  }

  List<Project> get buriedProjects =>
      _projects.where((p) => p.status == ProjectStatus.beerdigt).toList()
        ..sort((a, b) => (b.burial?.date ?? b.createdAt)
            .compareTo(a.burial?.date ?? a.createdAt));

  List<Project> get completedProjects =>
      _projects.where((p) => p.status == ProjectStatus.abgeschlossen).toList();

  List<Project> get deathZoneProjects =>
      dashboardProjects.where((p) => p.inDeathZone).toList();

  List<Project> get starvedProjects => _projects
      .where((p) => p.status == ProjectStatus.verhungert)
      .toList();

  /// Projekte, die beim Öffnen die Pausiert-oder-verhungert-Frage brauchen.
  List<Project> get projectsNeedingDecision =>
      _projects.where((p) => p.needsStaleDecision).toList();

  DateTime? get lastCompletionDate {
    DateTime? latest;
    for (final p in _projects) {
      if (p.status == ProjectStatus.abgeschlossen) {
        final d = p.lastCheckIn?.date ?? p.createdAt;
        if (latest == null || d.isAfter(latest)) latest = d;
      }
    }
    return latest;
  }

  // ---------------------------------------------------------------------------
  // Mutationen
  // ---------------------------------------------------------------------------

  Project createProject({
    required String name,
    required Category category,
    required String definitionOfDone,
    List<String> initialDeltas = const [],
    int? initialPercent,
  }) {
    final now = DateTime.now();
    final project = Project(
      id: _uuid.v4(),
      name: name.trim(),
      category: category,
      definitionOfDone: definitionOfDone.trim(),
      createdAt: now,
    );
    for (final t in initialDeltas) {
      final text = t.trim();
      if (text.isEmpty) continue;
      project.deltas.add(DeltaItem(
        id: _uuid.v4(),
        text: text,
        createdAt: now,
        isSeed: true,
      ));
    }
    // Der beim Anlegen erzeugte Start-Check-in ist ein Seed und zählt nie als
    // Fortschritt — sonst könnte man sich per Import eine Bilanz bauen.
    project.checkIns.add(CheckIn(
      id: _uuid.v4(),
      date: now,
      feltPercent: (initialPercent ?? 0).clamp(0, 100),
      isSeed: true,
    ));
    _projects.add(project);
    _persist();
    notifyListeners();
    return project;
  }

  /// Führt einen Check-in durch.
  /// [resolvedDeltaIds] — offene Deltas, die abgehakt wurden.
  /// [newDeltaTexts]    — neu hinzugekommene Deltas.
  void checkIn({
    required String projectId,
    required Set<String> resolvedDeltaIds,
    required List<String> newDeltaTexts,
    required int feltPercent,
    String? note,
  }) {
    final project = byId(projectId);
    if (project == null) return;
    final now = DateTime.now();

    for (final d in project.deltas) {
      if (resolvedDeltaIds.contains(d.id) && d.isOpen) {
        d.resolvedAt = now;
      }
    }
    for (final t in newDeltaTexts) {
      final text = t.trim();
      if (text.isEmpty) continue;
      project.deltas.add(DeltaItem(
        id: _uuid.v4(),
        text: text,
        createdAt: now,
      ));
    }

    project.checkIns.add(CheckIn(
      id: _uuid.v4(),
      date: now,
      feltPercent: feltPercent.clamp(0, 100),
      note: (note != null && note.trim().isNotEmpty) ? note.trim() : null,
    ));

    // Ein Check-in mit Bewegung holt ein verhungertes Projekt zurück ins Leben.
    if (project.status == ProjectStatus.verhungert &&
        (resolvedDeltaIds.isNotEmpty || newDeltaTexts.any((t) => t.trim().isNotEmpty))) {
      project.status = ProjectStatus.aktiv;
    }

    _persist();
    notifyListeners();
  }

  void pauseProject(String projectId, {required String reason, DateTime? resumeDate}) {
    final p = byId(projectId);
    if (p == null) return;
    p.status = ProjectStatus.pausiert;
    p.pauseReason = reason.trim();
    p.resumeDate = resumeDate;
    _persist();
    notifyListeners();
  }

  void resumeProject(String projectId) {
    final p = byId(projectId);
    if (p == null) return;
    p.status = ProjectStatus.aktiv;
    p.pauseReason = null;
    p.resumeDate = null;
    _persist();
    notifyListeners();
  }

  void markStarved(String projectId) {
    final p = byId(projectId);
    if (p == null) return;
    p.status = ProjectStatus.verhungert;
    _persist();
    notifyListeners();
  }

  void completeProject(String projectId) {
    final p = byId(projectId);
    if (p == null) return;
    final now = DateTime.now();
    // Ein Abschluss ist implizit 100%.
    p.checkIns.add(CheckIn(
      id: _uuid.v4(),
      date: now,
      feltPercent: 100,
      note: 'Abgeschlossen.',
    ));
    p.status = ProjectStatus.abgeschlossen;
    _persist();
    notifyListeners();
  }

  void buryProject(String projectId, {required String reason, required String learning}) {
    final p = byId(projectId);
    if (p == null) return;
    p.burial = BurialRecord(
      date: DateTime.now(),
      reason: reason.trim(),
      learning: learning.trim(),
    );
    p.status = ProjectStatus.beerdigt;
    _persist();
    notifyListeners();
  }

  void updateDefinitionOfDone(String projectId, String value) {
    final p = byId(projectId);
    if (p == null) return;
    p.definitionOfDone = value.trim();
    _persist();
    notifyListeners();
  }

  // --- WIP-Limit ------------------------------------------------------------

  /// Ändert das WIP-Limit — greift erst in einer Woche (kein Impuls-Upgrade
  /// um Mitternacht).
  void requestWipLimitChange(int newLimit) {
    if (newLimit == _wipLimit) {
      _pendingWipLimit = null;
      _pendingWipLimitEffectiveAt = null;
    } else {
      _pendingWipLimit = newLimit.clamp(1, 12);
      _pendingWipLimitEffectiveAt =
          DateTime.now().add(const Duration(days: 7));
    }
    _persist();
    notifyListeners();
  }

  void _applyPendingWipIfDue() {
    final due = _pendingWipLimitEffectiveAt;
    if (_pendingWipLimit != null && due != null && !DateTime.now().isBefore(due)) {
      _wipLimit = _pendingWipLimit!;
      _pendingWipLimit = null;
      _pendingWipLimitEffectiveAt = null;
    }
  }

  // ---------------------------------------------------------------------------
  // Demo-Daten / Reset
  // ---------------------------------------------------------------------------

  bool get hasProjects => _projects.isNotEmpty;

  /// Alle Daten löschen — die App wird wieder zum leeren Beichtstuhl.
  void clearAll() {
    _projects = [];
    _persist();
    notifyListeners();
  }

  /// Ein Demo-Datensatz, der alle Zustände gleichzeitig sichtbar macht:
  /// Todeszone, cracked/dust, verhungert, pausiert, abgeschlossen, beerdigt.
  void loadDemoData() {
    _projects = _buildDemo();
    _persist();
    notifyListeners();
  }

  List<Project> _buildDemo() {
    return [
      _demo(
        name: 'Spektra',
        category: Category.code,
        status: ProjectStatus.aktiv,
        dod: 'Wenn es im App-Store steht und die Doku vollständig ist.',
        // [tageZurück, prozent] — erster Eintrag ist der Seed.
        checkIns: [[70, 60], [55, 68], [44, 76], [33, 78], [26, 78], [19, 78]],
        deltas: [
          ('Grundgerüst steht', 60, 44),
          ('Doku-Kapitel 3', 44, null),
          ('Export-Test', 19, null),
        ],
      ),
      _demo(
        name: 'CouchControl',
        category: Category.code,
        status: ProjectStatus.aktiv,
        dod: 'Wenn ich den Fernseher komplett per App steuern kann.',
        checkIns: [
          [120, 70], [110, 78], [100, 85], [90, 91],
          [80, 91], [70, 91], [60, 91], [50, 91], [41, 91]
        ],
        deltas: [
          ('App-Store-Assets', 80, 70),
          ('Lizenz-Text klären', 65, null),
          ('Payment-Flow', 90, 41),
        ],
      ),
      _demo(
        name: 'MovieShare',
        category: Category.code, // Web-Projekt (Astro/SolidJS/SQLite)
        status: ProjectStatus.aktiv,
        dod: 'Wenn Freunde damit gemeinsam Filmlisten führen können.',
        checkIns: [[20, 15], [12, 22], [7, 28], [2, 34]],
        deltas: [
          ('Trailer-Schnitt', 12, null),
          ('Untertitel-Import', 7, null),
        ],
      ),
      _demo(
        name: 'Timeline-Kalender',
        category: Category.design,
        status: ProjectStatus.verhungert,
        dod: 'Wenn die Monatsansicht mit Sync funktioniert.',
        checkIns: [[90, 20], [80, 30], [70, 38], [60, 44], [47, 45]],
        deltas: [
          ('Sync-Bug', 70, null),
          ('Monatsansicht', 60, 47),
        ],
      ),
      _demo(
        name: 'Bike-Navigation',
        category: Category.code,
        status: ProjectStatus.pausiert,
        dod: 'Wenn Offline-Routing auf dem Lenker-Display läuft.',
        checkIns: [[60, 30], [48, 40], [40, 48], [30, 54], [22, 58], [16, 60], [12, 62]],
        deltas: [
          ('Offline-Karten', 40, 22),
          ('GPX-Import', 16, null),
        ],
        pauseReason: 'Wartet auf das neue Fahrrad im Frühjahr.',
        resumeInDays: 90,
      ),
      _demo(
        name: 'Portfolio-Website',
        category: Category.design,
        status: ProjectStatus.abgeschlossen,
        dod: 'Wenn sie online ist und drei Case Studies zeigt.',
        checkIns: [
          [130, 40], [115, 55], [100, 66], [85, 74],
          [70, 82], [50, 90], [30, 96], [8, 100]
        ],
        deltas: [
          ('Case Studies', 100, 30),
          ('Kontaktformular', 70, 50),
        ],
      ),
      _demo(
        name: 'Diffuser "Aura"',
        category: Category.foto,
        status: ProjectStatus.beerdigt,
        dod: 'Wenn ein Prototyp Duft per App zeitgesteuert abgibt.',
        checkIns: [[80, 20], [60, 40], [45, 55]],
        deltas: [
          ('Elektronik-Layout', 60, null),
        ],
        burial: BurialRecord(
          date: DateTime.now().subtract(const Duration(days: 30)),
          reason: 'Markt zu klein, Hardware-Stückkosten zu hoch.',
          learning: 'ESP32-Sensorik sitzt — wandert in ein anderes Projekt.',
        ),
      ),
    ];
  }

  Project _demo({
    required String name,
    required Category category,
    required ProjectStatus status,
    required String dod,
    required List<List<int>> checkIns,
    List<(String, int, int?)> deltas = const [],
    BurialRecord? burial,
    String? pauseReason,
    int? resumeInDays,
  }) {
    final now = DateTime.now();
    DateTime at(int daysAgo) => now.subtract(Duration(days: daysAgo));

    final createdAt = at(checkIns.first[0]);
    final project = Project(
      id: _uuid.v4(),
      name: name,
      category: category,
      definitionOfDone: dod,
      createdAt: createdAt,
      status: status,
      burial: burial,
      pauseReason: pauseReason,
      resumeDate: resumeInDays == null ? null : now.add(Duration(days: resumeInDays)),
    );

    for (var i = 0; i < checkIns.length; i++) {
      project.checkIns.add(CheckIn(
        id: _uuid.v4(),
        date: at(checkIns[i][0]),
        feltPercent: checkIns[i][1],
        isSeed: i == 0,
      ));
    }

    for (final d in deltas) {
      project.deltas.add(DeltaItem(
        id: _uuid.v4(),
        text: d.$1,
        createdAt: at(d.$2),
        resolvedAt: d.$3 == null ? null : at(d.$3!),
      ));
    }

    return project;
  }

  // ---------------------------------------------------------------------------
  // Wochenbericht
  // ---------------------------------------------------------------------------

  WeeklyReport weeklyReport() {
    final now = DateTime.now();
    final weekStart = startOfWeek(now);

    var deltasClosed = 0;
    var deltasNew = 0;
    var completions = 0;
    var netProgress = 0;
    var projectsCounted = 0;

    for (final p in _projects) {
      if (p.status == ProjectStatus.beerdigt) continue;

      for (final d in p.deltas) {
        // Beim Anlegen eingetragene Deltas zählen nicht als "neu".
        if (!d.isSeed && !d.createdAt.isBefore(weekStart)) deltasNew++;
        final r = d.resolvedAt;
        if (r != null && !r.isBefore(weekStart)) deltasClosed++;
      }

      // Netto-Fortschritt: nur echte Check-ins. Beitrag eines Projekts =
      // (letzter Check-in in der Woche) − (letzter Check-in vor der Woche).
      // Existiert kein echter Check-in vor der Woche, ist der Beitrag 0 —
      // nicht der Startwert.
      final real = p.realCheckIns;
      final before = real.where((c) => c.date.isBefore(weekStart)).toList();
      final inWeek = real
          .where((c) => !c.date.isBefore(weekStart) && !c.date.isAfter(now))
          .toList();
      if (before.isNotEmpty && inWeek.isNotEmpty) {
        netProgress += inWeek.last.feltPercent - before.last.feltPercent;
        projectsCounted++;
      }

      if (p.status == ProjectStatus.abgeschlossen) {
        final d = p.lastCheckIn?.date;
        if (d != null && !d.isBefore(weekStart)) completions++;
      }
    }

    final lastCompletion = lastCompletionDate;

    return WeeklyReport(
      week: isoWeekNumber(now),
      year: isoWeekYear(now),
      netProgress: netProgress,
      projectsCounted: projectsCounted,
      deltasClosed: deltasClosed,
      deltasNew: deltasNew,
      completions: completions,
      daysSinceLastCompletion:
          lastCompletion == null ? null : now.difference(lastCompletion).inDays,
      deathZone: deathZoneProjects,
      starved: starvedProjects,
    );
  }
}

class WeeklyReport {
  WeeklyReport({
    required this.week,
    required this.year,
    required this.netProgress,
    required this.projectsCounted,
    required this.deltasClosed,
    required this.deltasNew,
    required this.completions,
    required this.daysSinceLastCompletion,
    required this.deathZone,
    required this.starved,
  });

  final int week;
  final int year;
  final int netProgress;
  final int projectsCounted;
  final int deltasClosed;
  final int deltasNew;
  final int completions;
  final int? daysSinceLastCompletion;
  final List<Project> deathZone;
  final List<Project> starved;
}
