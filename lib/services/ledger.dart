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
      ));
    }
    if (initialPercent != null) {
      project.checkIns.add(CheckIn(
        id: _uuid.v4(),
        date: now,
        feltPercent: initialPercent.clamp(0, 100),
      ));
    }
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
        if (!d.createdAt.isBefore(weekStart)) deltasNew++;
        final r = d.resolvedAt;
        if (r != null && !r.isBefore(weekStart)) deltasClosed++;
      }

      final chrono = p.checkInsChrono;
      if (chrono.isNotEmpty) {
        // Fortschritt der Woche: letzter Wert minus letzter Wert vor Wochenstart.
        final before = chrono.where((c) => c.date.isBefore(weekStart)).toList();
        final withinOrBefore = chrono.where((c) => !c.date.isAfter(now)).toList();
        if (withinOrBefore.isNotEmpty) {
          final startVal = before.isNotEmpty ? before.last.feltPercent : 0;
          final endVal = withinOrBefore.last.feltPercent;
          if (chrono.any((c) => !c.date.isBefore(weekStart))) {
            netProgress += endVal - startVal;
            projectsCounted++;
          }
        }
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
