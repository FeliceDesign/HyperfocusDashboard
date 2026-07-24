import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/project.dart';

/// Einfache, robuste JSON-Persistenz in einer einzigen Datei im
/// App-Dokumentenverzeichnis. Keine zweite Datenquelle, kein Import.
class Storage {
  static const _fileName = 'focus_ledger.json';

  Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  Future<LedgerData> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return LedgerData.empty();
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return LedgerData.empty();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return LedgerData.fromJson(json);
    } catch (_) {
      // Beschädigte Daten sollen die App nicht sprengen.
      return LedgerData.empty();
    }
  }

  Future<void> save(LedgerData data) async {
    final file = await _file();
    final tmp = File('${file.path}.tmp');
    await tmp.writeAsString(jsonEncode(data.toJson()));
    await tmp.rename(file.path);
  }
}

/// Der komplette gespeicherte Zustand.
class LedgerData {
  LedgerData({
    required this.projects,
    required this.wipLimit,
    required this.pendingWipLimit,
    required this.pendingWipLimitEffectiveAt,
  });

  final List<Project> projects;
  final int wipLimit;

  /// Geplante Änderung des WIP-Limits — greift erst mit einer Woche Verzögerung.
  final int? pendingWipLimit;
  final DateTime? pendingWipLimitEffectiveAt;

  factory LedgerData.empty() => LedgerData(
        projects: [],
        wipLimit: 4,
        pendingWipLimit: null,
        pendingWipLimitEffectiveAt: null,
      );

  Map<String, dynamic> toJson() => {
        'wipLimit': wipLimit,
        'pendingWipLimit': pendingWipLimit,
        'pendingWipLimitEffectiveAt':
            pendingWipLimitEffectiveAt?.toIso8601String(),
        'projects': projects.map((e) => e.toJson()).toList(),
      };

  factory LedgerData.fromJson(Map<String, dynamic> json) => LedgerData(
        wipLimit: (json['wipLimit'] as num?)?.toInt() ?? 4,
        pendingWipLimit: (json['pendingWipLimit'] as num?)?.toInt(),
        pendingWipLimitEffectiveAt: json['pendingWipLimitEffectiveAt'] == null
            ? null
            : DateTime.parse(json['pendingWipLimitEffectiveAt'] as String),
        projects: (json['projects'] as List<dynamic>? ?? [])
            .map((e) => Project.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
