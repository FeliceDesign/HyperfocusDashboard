import 'package:flutter_test/flutter_test.dart';

import 'package:focus_ledger/models/enums.dart';
import 'package:focus_ledger/models/project.dart';
import 'package:focus_ledger/models/staleness.dart';
import 'package:focus_ledger/models/delta_item.dart';
import 'package:focus_ledger/models/check_in.dart';

void main() {
  group('Staleness', () {
    test('Stufen nach Tagen', () {
      expect(Staleness.fromDays(0), Staleness.frisch);
      expect(Staleness.fromDays(6), Staleness.frisch);
      expect(Staleness.fromDays(7), Staleness.kuehl);
      expect(Staleness.fromDays(13), Staleness.kuehl);
      expect(Staleness.fromDays(14), Staleness.rissig);
      expect(Staleness.fromDays(29), Staleness.rissig);
      expect(Staleness.fromDays(30), Staleness.staub);
    });
  });

  group('Project', () {
    Project fresh() => Project(
          id: 'p1',
          name: 'Spektra',
          category: Category.code,
          definitionOfDone: 'Wenn es released ist.',
          createdAt: DateTime.now(),
        );

    test('feltPercent folgt dem letzten Check-in', () {
      final p = fresh();
      expect(p.feltPercent, 0);
      p.checkIns.add(CheckIn(id: 'c1', date: DateTime.now(), feltPercent: 42));
      expect(p.feltPercent, 42);
    });

    test('Momentum steigt, fällt und ist flach', () {
      final p = fresh();
      final base = DateTime(2026, 1, 1);
      p.checkIns.addAll([
        CheckIn(id: 'a', date: base, feltPercent: 50),
        CheckIn(id: 'b', date: base.add(const Duration(days: 1)), feltPercent: 60),
        CheckIn(id: 'c', date: base.add(const Duration(days: 2)), feltPercent: 70),
      ]);
      expect(p.momentum, Momentum.up);
    });

    test('Todeszone: 70-95% mit flachem Momentum', () {
      final p = fresh();
      final base = DateTime(2026, 1, 1);
      p.checkIns.addAll([
        CheckIn(id: 'a', date: base, feltPercent: 80),
        CheckIn(id: 'b', date: base.add(const Duration(days: 1)), feltPercent: 80),
      ]);
      expect(p.inDeathZone, isTrue);
    });

    test('lastMeaningfulChange folgt Delta-Aktivität, nicht dem Slider', () {
      final created = DateTime(2026, 1, 1);
      final p = Project(
        id: 'p2',
        name: 'X',
        category: Category.code,
        definitionOfDone: 'fertig',
        createdAt: created,
      );
      final deltaDate = DateTime(2026, 2, 1);
      p.deltas.add(DeltaItem(id: 'd1', text: 'Doku', createdAt: deltaDate));
      // Ein reiner Slider-Check-in danach darf lastMeaningfulChange nicht bewegen.
      p.checkIns.add(CheckIn(id: 'c', date: DateTime(2026, 3, 1), feltPercent: 90));
      expect(p.lastMeaningfulChange, deltaDate);
    });
  });

  group('WIP', () {
    test('verhungert zählt gegen WIP, pausiert nicht', () {
      expect(ProjectStatus.aktiv.countsAgainstWip, isTrue);
      expect(ProjectStatus.verhungert.countsAgainstWip, isTrue);
      expect(ProjectStatus.pausiert.countsAgainstWip, isFalse);
      expect(ProjectStatus.beerdigt.countsAgainstWip, isFalse);
      expect(ProjectStatus.abgeschlossen.countsAgainstWip, isFalse);
    });
  });
}
