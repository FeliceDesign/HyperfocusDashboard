import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:focus_ledger/models/enums.dart';
import 'package:focus_ledger/models/project.dart';
import 'package:focus_ledger/models/staleness.dart';
import 'package:focus_ledger/models/delta_item.dart';
import 'package:focus_ledger/models/check_in.dart';
import 'package:focus_ledger/utils/dates.dart';
import 'package:focus_ledger/theme/app_theme.dart';
import 'package:focus_ledger/widgets/project_card.dart';

void main() {
  Project fresh({DateTime? createdAt}) => Project(
        id: 'p1',
        name: 'Spektra',
        category: Category.code,
        definitionOfDone: 'Wenn es released ist.',
        createdAt: createdAt ?? DateTime.now(),
      );

  DateTime daysAgo(int d) => DateTime.now().subtract(Duration(days: d));

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

  group('Momentum', () {
    test('null bei weniger als drei echten Check-ins', () {
      final p = fresh();
      p.checkIns.add(CheckIn(id: 'a', date: daysAgo(3), feltPercent: 80));
      p.checkIns.add(CheckIn(id: 'b', date: daysAgo(1), feltPercent: 80));
      expect(p.realCheckInCount, 2);
      expect(p.momentum, isNull);
    });

    test('Seed-Check-in zählt nicht als echter Check-in', () {
      final p = fresh();
      p.checkIns.add(CheckIn(id: 's', date: daysAgo(5), feltPercent: 90, isSeed: true));
      expect(p.realCheckInCount, 0);
      expect(p.momentum, isNull);
    });

    test('steigend bei percentDelta >= 3 über drei Check-ins', () {
      final p = fresh();
      p.checkIns.addAll([
        CheckIn(id: 'a', date: daysAgo(3), feltPercent: 50),
        CheckIn(id: 'b', date: daysAgo(2), feltPercent: 60),
        CheckIn(id: 'c', date: daysAgo(1), feltPercent: 70),
      ]);
      expect(p.momentum, Momentum.up);
    });

    test('flach bei identischen Werten', () {
      final p = fresh();
      p.checkIns.addAll([
        CheckIn(id: 'a', date: daysAgo(3), feltPercent: 80),
        CheckIn(id: 'b', date: daysAgo(2), feltPercent: 80),
        CheckIn(id: 'c', date: daysAgo(1), feltPercent: 80),
      ]);
      expect(p.momentum, Momentum.flat);
    });
  });

  group('Todeszone', () {
    test('erfordert mindestens drei echte Check-ins', () {
      final p = fresh();
      p.checkIns.addAll([
        CheckIn(id: 'a', date: daysAgo(2), feltPercent: 90),
        CheckIn(id: 'b', date: daysAgo(1), feltPercent: 90),
      ]);
      // 90% im Bereich, aber nur zwei Check-ins → keine Todeszone.
      expect(p.inDeathZone, isFalse);
    });

    test('70-95% mit flachem Momentum und drei Check-ins', () {
      final p = fresh();
      p.checkIns.addAll([
        CheckIn(id: 'a', date: daysAgo(3), feltPercent: 80),
        CheckIn(id: 'b', date: daysAgo(2), feltPercent: 80),
        CheckIn(id: 'c', date: daysAgo(1), feltPercent: 80),
      ]);
      expect(p.inDeathZone, isTrue);
    });
  });

  group('Seed / Fortschritt', () {
    test('Neu angelegtes Projekt mit Startwert 90% hat keinen echten Check-in', () {
      final p = fresh();
      p.checkIns.add(CheckIn(id: 's', date: DateTime.now(), feltPercent: 90, isSeed: true));
      // Kein echter Check-in → kein Fortschritt möglich, keine Todeszone.
      expect(p.realCheckInCount, 0);
      expect(p.inDeathZone, isFalse);
      expect(p.feltPercent, 90); // angezeigter Stand bleibt 90
    });
  });

  group('lastMeaningfulChange', () {
    test('Check-in ohne Änderung bewegt sie nicht — Karte bleibt verblasst', () {
      final created = daysAgo(40);
      final p = fresh(createdAt: created);
      p.checkIns.add(CheckIn(id: 's', date: created, feltPercent: 50, isSeed: true));
      // Slider auf denselben Wert, keine Deltas.
      p.checkIns.add(CheckIn(id: 'c', date: daysAgo(2), feltPercent: 50));
      expect(p.daysSinceMeaningfulChange, greaterThanOrEqualTo(30));
      expect(p.staleness, Staleness.staub);
    });

    test('feltPercent-Änderung >= 1 aktualisiert sie', () {
      final created = daysAgo(40);
      final p = fresh(createdAt: created);
      p.checkIns.add(CheckIn(id: 's', date: created, feltPercent: 50, isSeed: true));
      p.checkIns.add(CheckIn(id: 'c', date: daysAgo(1), feltPercent: 52));
      expect(p.daysSinceMeaningfulChange, lessThanOrEqualTo(2));
      expect(p.staleness, Staleness.frisch);
    });

    test('neues Delta aktualisiert sie', () {
      final created = daysAgo(40);
      final p = fresh(createdAt: created);
      p.deltas.add(DeltaItem(id: 'd', text: 'Doku', createdAt: daysAgo(1)));
      expect(p.daysSinceMeaningfulChange, lessThanOrEqualTo(2));
    });
  });

  group('ISO-Kalenderwoche', () {
    test('24.07.2026 ist KW 30', () {
      expect(isoWeekNumber(DateTime(2026, 7, 24)), 30);
      expect(isoWeekYear(DateTime(2026, 7, 24)), 2026);
    });

    test('Jahresübergang 2025', () {
      // 29.12.2025 (Montag) liegt bereits in KW 1 / 2026.
      expect(isoWeekNumber(DateTime(2025, 12, 29)), 1);
      expect(isoWeekYear(DateTime(2025, 12, 29)), 2026);
    });
  });

  group('ProjectCard-Rendering', () {
    testWidgets('rendert mit Höhe > 0 in einer ListView (kein Kollaps)',
        (tester) async {
      final p = fresh();
      p.checkIns.add(CheckIn(id: 's', date: DateTime.now(), feltPercent: 78));
      p.deltas.add(DeltaItem(id: 'd', text: 'Doku-Kapitel 3', createdAt: DateTime.now()));

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.build(),
        home: Scaffold(
          body: ListView(
            children: [ProjectCard(project: p, onTap: () {})],
          ),
        ),
      ));

      final size = tester.getSize(find.byType(ProjectCard));
      expect(size.height, greaterThan(0));
      expect(find.text('SPEKTRA'), findsOneWidget);
      expect(find.textContaining('78%'), findsOneWidget);
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
