# Non Finito

Ein Dashboard für kreative Projekte, das nicht motiviert, sondern **konfrontiert**.

> *Non finito* — aus der Kunstgeschichte: ein bewusst unvollendetes Werk.
> Genau das, was diese App verwaltet — ohne zu beschämen.

Die meisten Produktivitäts-Apps optimieren fürs *Anfangen*. Focus Ledger
optimiert fürs **Abschließen**. Jede Design-Entscheidung folgt einer Frage:

> Macht dieses Feature es leichter, ein Projekt fertig zu machen — oder leichter,
> ein neues anzufangen?

Eine native Flutter-App für Android, gebaut nach dem
[Konzept](docs/focus-ledger-konzept.md).

---

## Was drin ist

| Feature | Beschreibung |
|---|---|
| **Projekt anlegen** | Mit `Definition of Done` als Pflichtfeld — die erste Hürde. |
| **Check-in-Flow** | Das Herzstück. Vier Schritte: offene Deltas abhaken, neue Deltas benennen, gefühlten Prozentsatz setzen (mit Geisterlinie), Notiz. |
| **Dashboard** | Vertikale Liste (Warteschlange, kein Grid), sortiert nach Dringlichkeit. Balken, Momentum-Pfeil, Top-Deltas als Klartext, Tageszähler. |
| **Staleness-Decay** | Karten verlieren Belichtung, je länger sie liegen — Sättigungsverlust, Bruchkante, Grain-Overlay. Gerechnet ab der letzten *echten* Veränderung. |
| **Todeszone** | 70–95 % mit flachem/fallendem Momentum bekommen eine eigene Markierung. |
| **WIP-Limit** | Maximal N aktive Projekte. Voll = kein „Trotzdem". Änderung greift erst nach einer Woche. |
| **Pausiert vs. verhungert** | Nach 21 Tagen Stille: bewusste Entscheidung oder Versäumnis? |
| **Beerdigen** | Eigener Flow mit Grund + Learning. Ein bewusster Abschied ist ein Erfolg. |
| **Verlaufsgraph** | % über Zeit — die Plateaus sind sofort sichtbar. |
| **Wochenbericht** | Zahlen und Klartext, kein „Gut gemacht!". |

Alle Daten liegen **lokal** auf dem Gerät (eine JSON-Datei). Kein Konto,
kein Import, keine Cloud, keine Push-Notifications. Der visuelle Verfall ist
die Benachrichtigung.

---

## APK herunterladen

Jeder Push auf `main` oder einen `claude/**`-Branch baut automatisch eine
Release-APK über GitHub Actions:

1. Reiter **Actions** → Workflow **Build Android APK** → letzter Lauf →
   Artefakt **non-finito-release-apk**, **oder**
2. Reiter **Releases** → aktuellster `build-*`-Eintrag → `app-release.apk`.

APK aufs Android-Gerät kopieren und installieren (Installation aus unbekannten
Quellen muss erlaubt sein).

---

## Lokal bauen

Voraussetzung: [Flutter](https://docs.flutter.dev/get-started/install) (stable)
und ein Android-SDK.

```bash
# Plattform-Ordner erzeugen (android/ ist nicht eingecheckt)
flutter create --platforms=android --org com.felicedesign --project-name focus_ledger .

flutter pub get
flutter test
flutter run              # auf angeschlossenem Gerät/Emulator
flutter build apk --release
```

Die fertige APK liegt unter `build/app/outputs/flutter-apk/app-release.apk`.

> **Hinweis:** Die Ordner `android/`, `ios/` usw. sind bewusst nicht im Repo —
> sie werden von `flutter create` passend zur installierten Flutter-Version
> generiert. So gibt es keine Gradle-Versionskonflikte. Der eigene Code liegt
> vollständig in `lib/`.

---

## Projektstruktur

```
lib/
  main.dart                 App-Einstieg, Provider-Setup
  models/                   Project, CheckIn, DeltaItem, BurialRecord, Enums, Staleness
  services/
    storage.dart            JSON-Persistenz (path_provider)
    ledger.dart             Zentraler Zustand + Geschäftslogik (ChangeNotifier)
  theme/app_theme.dart      Warmes Anthrazit, Kategorie-Farben, Staleness-Entsättigung
  utils/dates.dart          Deutsche Zeitangaben, ISO-Kalenderwoche
  widgets/                  ProjectCard, ProgressBar, GrainOverlay, HistoryGraph
  screens/                  Dashboard, NewProject, CheckIn, ProjectDetail,
                            WeeklyReport, Burial, Archive, Settings, WipBlock
test/widget_test.dart       Kernlogik-Tests (Staleness, Momentum, Todeszone, WIP)
```
