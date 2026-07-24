# Focus Ledger — Konzept

Ein Dashboard für kreative Projekte, das nicht motiviert, sondern konfrontiert.

---

## 1. Grundprinzip

Die meisten Produktivitäts-Apps optimieren für **Anfangen**. Neues Projekt, leere Liste, Dopamin. Genau das ist das Problem, das nicht gelöst werden muss.

Focus Ledger optimiert für **Abschließen**. Jede Design-Entscheidung folgt einer Frage:

> Macht dieses Feature es leichter, ein Projekt fertig zu machen — oder leichter, ein neues anzufangen?

Wenn zweiteres: raus.

Drei Kernannahmen:

1. **Fortschritt ist gefühlt, nicht messbar.** Kein Auto-Tracking, keine Git-Commits, keine Zeitmessung. Selbsteinschätzung ist ehrlicher als jede Metrik — aber nur, wenn sie erzwungenermaßen begründet wird.
2. **Zeit ist kein Fortschritt.** Zwei Stunden Herumschieben an einer Farbpalette sind kein Fortschritt. Die App interessiert sich nicht dafür, wie lange du gearbeitet hast.
3. **Stillstand ist die eigentliche Information.** Nicht "was habe ich geschafft", sondern "was liegt seit wann brach".

---

## 2. Datenmodell

Bewusst minimal. Vier Entitäten.

### Project
```
id
name
kategorie          // z.B. Code, Foto, Design, Schreiben
definitionOfDone   // Pflichtfeld beim Anlegen. Ein Satz.
status             // aktiv | pausiert | verhungert | abgeschlossen | beerdigt
createdAt
```

**`definitionOfDone` ist Pflicht.** Du kannst kein Projekt anlegen ohne zu definieren, was "fertig" heißt. Das ist die erste Hürde und filtert schon die Hälfte der spontanen Ideen raus. Wenn du nicht in einem Satz sagen kannst, wann es fertig ist, ist es keine Projekt-Idee, sondern eine Stimmung.

### CheckIn
```
id
projectId
date
feltPercent        // 0-100, Slider
note               // optional, freier Text
```

### DeltaItem
```
id
projectId
text               // "Doku fehlt", "Export-Test fehlt"
createdAtCheckIn
resolvedAtCheckIn  // null = offen
```

Das Delta ist der Kern. Bei jedem Check-in musst du benennen, **was konkret zwischen jetzt und 100% liegt**. Nicht "noch Feinschliff". Konkrete Items.

### BurialRecord
```
projectId
date
reason             // warum beerdigt
learning           // was hast du mitgenommen
```

---

## 3. Der Check-in — das Herzstück

Alles andere in der App ist nur Visualisierung dieses einen Flows. Er dauert 30–60 Sekunden und läuft in vier Schritten.

**Schritt 1 — Deine offenen Deltas.**
Die App zeigt dir die Delta-Items aus dem letzten Check-in. Jedes bekommt einen Toggle: erledigt / noch offen.

> Beim letzten Mal fehlte:
> - [ ] Export-Test
> - [ ] Doku-Kapitel 3
> - [ ] Onboarding-Screen

Das ist der Moment, wo Selbstbetrug schwierig wird. Du kannst dir nicht einreden, dass du vorangekommen bist, wenn dieselben drei Items seit sechs Wochen offen sind — sie stehen wörtlich vor dir.

**Schritt 2 — Neue Deltas.**
Was ist seit dem letzten Check-in dazugekommen? (Fast immer: mehr als du erwartet hast. Das ist normal und wichtig zu sehen.)

**Schritt 3 — Gefühlter Prozentsatz.**
Slider. Der alte Wert ist als Geisterlinie sichtbar, damit du siehst, ob du dich gerade hoch- oder runterlügst.

Wenn du den Wert erhöhst, aber **kein einziges Delta abgehakt hast**, fragt die App genau einmal nach: *"Prozent gestiegen, aber nichts abgeschlossen. Was ist passiert?"* Keine Blockade — nur eine Notiz-Zeile. Manchmal gibt es gute Gründe. Meistens nicht.

**Schritt 4 — Status-Check bei Bedarf.**
Nur wenn das Projekt länger als 21 Tage still war (siehe Abschnitt 5).

---

## 4. UI

### 4.1 Dashboard (Startscreen)

**Vertikale Liste, kein Grid.** Ein Grid sieht aus wie eine Sammlung und lädt zum Sammeln ein. Eine Liste sieht aus wie eine Warteschlange.

Sortierung: **nach Dringlichkeit**, nicht nach Name oder Datum. Ganz oben steht, was am meisten verrottet — nicht, woran du zuletzt Spaß hattest.

**Header-Zeile:**
```
FOCUS LEDGER                    aktiv: 4 / 4
```
Der WIP-Zähler ist immer sichtbar. Wenn er voll ist, ist er rot. (Mehr dazu in 5.3.)

**Projekt-Karte:**
```
┌────────────────────────────────────────────┐
│  SPEKTRA                        Code       │
│  ████████████████████████░░░░░░░  78%  →   │
│  Fehlt: Doku-Kapitel 3, Export-Test  +2    │
│  letzter Check-in: vor 19 Tagen            │
└────────────────────────────────────────────┘
```

Vier Informationsebenen pro Karte:
- **Balken + %** — der gefühlte Stand
- **Momentum-Pfeil** (↗ → ↘) — Richtung der letzten drei Check-ins
- **Top-Deltas als Klartext** — das Wichtigste. Ein Prozentbalken ist abstrakt, "Doku-Kapitel 3 fehlt" ist konkret. Du siehst beim Scrollen, was zu tun ist, ohne irgendwo reinzutappen.
- **Tage seit Check-in** — der Vorwurf

### 4.2 Visueller Verfall (Staleness Decay)

Der interessanteste Teil, und der, der fotografisch denkt: Karten **verlieren Belichtung**, je länger sie liegen.

| Zustand | Tage | Visuell |
|---|---|---|
| Frisch | 0–6 | Volle Sättigung, voller Kontrast |
| Kühl | 7–13 | Sättigung −30%, Text leicht ausgegraut |
| Rissig | 14–29 | Sättigung −60%, Balken bekommt sichtbare Bruchkante |
| Staub | 30+ | Fast monochrom, Karte visuell "unterbelichtet", leichtes Grain-Overlay |

Kein Popup, keine Push-Notification, kein "Hey, du hast Projekt X vernachlässigt!". Die Information liegt einfach da und wird jeden Tag ein bisschen unangenehmer anzusehen. Das ist eleganter als jede Benachrichtigung — und du kannst es nicht wegwischen.

**Wichtiges Detail:** Staleness rechnet nicht ab dem letzten Check-in, sondern ab dem **letzten Check-in mit tatsächlicher Veränderung** (Delta abgehakt oder neues Delta angelegt). Sonst reicht dreimal Slider antippen, um die Farbe zurückzuholen — und dann hast du eine Cheat-Mechanik statt eines Spiegels.

### 4.3 Die Todeszone

Der Bereich zwischen **70% und 95% mit flachem oder fallendem Momentum** ist dein persönlicher Friedhof. Er bekommt eine eigene visuelle Behandlung: eine dünne Markierungslinie am Kartenrand und eine eigene Sektion im Wochenbericht.

Das ist keine allgemeine Produktivitäts-Weisheit, das ist spezifisch dein Muster. Die App macht daraus eine benannte, sichtbare Kategorie — weil ein Ding, das einen Namen hat, schwerer zu ignorieren ist.

### 4.4 Projekt-Detail

- **Definition of Done** oben angepinnt, immer sichtbar, nicht wegklappbar. Das ist der Nordstern und gleichzeitig die Erinnerung daran, was du dir mal vorgenommen hast.
- **Verlaufsgraph:** % über Zeit. Sofort erkennbar sind die Plateaus — die flachen Strecken, wo drei Monate lang nichts passiert ist. Diese Linie ist ehrlicher als jede Selbsteinschätzung.
- **Delta-Historie:** offene Items oben, erledigte darunter mit Datum. Ein Item, das seit vier Monaten offen ist, wird visuell markiert — meistens ist genau das der Grund, warum das Projekt steht.
- **Check-in-Timeline:** chronologisch, mit Notizen.

### 4.5 Der Wochenbericht

Sonntagabend, ein Screen. Keine Grafiken-Orgie, nur Zahlen und Klartext.

```
WOCHE 30 / 2026

Netto-Fortschritt:        +3%   über 4 Projekte
Deltas geschlossen:       2
Deltas neu:               7
Abschlüsse:               0
Letzter Abschluss:        vor 94 Tagen

IN DER TODESZONE:
  Spektra              78%   flach seit 3 Check-ins
  CouchControl         91%   flach seit 5 Check-ins

VERHUNGERT:
  Timeline-Kalender    45%   47 Tage still
```

Kein "Gut gemacht!", kein Ausgleich mit positiven Zahlen. Wenn die Woche schlecht war, sieht der Bericht schlecht aus. Das ist der ganze Punkt.

Die brutalste Zeile ist **"Letzter Abschluss: vor 94 Tagen"** — sie steht permanent da, unabhängig davon, wie viel Aktivität sonst läuft.

---

## 5. Systeme und ihre Verbindungen

### 5.1 Pausiert vs. Verhungert

Nach 21 Tagen Stille fragt die App beim nächsten Öffnen genau einmal:

> **Timeline-Kalender** liegt seit 24 Tagen.
> Bewusst pausiert oder entglitten?

- **Pausiert** → Projekt geht in einen ruhigen Zustand, Staleness-Decay stoppt, es zählt nicht mehr gegen dein WIP-Limit. Du musst einen Grund und optional ein Wiederaufnahme-Datum angeben. Das ist eine legitime, respektierte Entscheidung.
- **Entglitten** → Status `verhungert`. Kein Decay-Stopp, bleibt im WIP-Limit, bleibt im Wochenbericht. Es zählt weiter gegen dich, bis du dich entscheidest.

Der Unterschied ist psychologisch entscheidend: "on hold" ist ein Wort, mit dem man sich selbst beruhigt. Die App zwingt dich, zwischen einer Entscheidung und einem Versäumnis zu unterscheiden — und Versäumnisse bekommen keinen hübschen Namen.

### 5.2 Beerdigen

Ein Projekt für tot erklären ist ein **echtes Feature mit eigenem Flow**, kein Löschen im Kontextmenü. Du gibst einen Grund an und einen Satz dazu, was du mitgenommen hast.

Beerdigte Projekte landen in einem eigenen Archiv. Sie verschwinden nicht — sie sind Teil deiner Statistik und Teil deiner Geschichte.

Warum das wichtig ist: Ein bewusst beerdigtes Projekt ist ein **Erfolg**, kein Scheitern. Es befreit WIP-Kapazität und beendet den schleichenden Schuldgefühl-Overhead. Die meisten Tools erlauben nur "erledigt" oder "gelöscht" — dazwischen liegt der ehrlichste Zustand von allen.

### 5.3 Das WIP-Limit

Der schmerzhafteste und nützlichste Mechanismus der ganzen App.

**Maximal vier aktive Projekte.** Zahl beim Setup einmalig festlegbar, danach nur mit einer Woche Verzögerung änderbar (kein Impuls-Upgrade um Mitternacht, wenn dir gerade eine geile Idee gekommen ist).

Wenn du ein neues Projekt anlegen willst und das Limit voll ist, gibt es keinen "Trotzdem"-Button. Du musst ein bestehendes Projekt **abschließen, pausieren oder beerdigen**. Die App zeigt dir dabei deine vier aktuellen Projekte mit Prozentstand — und die Frage steht im Raum:

> Ist die neue Idee wirklich wichtiger als CouchControl bei 91%?

Meistens ist sie es nicht. Aber du musst es aktiv entscheiden, statt einfach danebenzustapeln.

### 5.4 Wie alles zusammenhängt

```
Check-in  ──► erzeugt/schließt ──►  Delta-Items
    │                                    │
    │                                    ▼
    ├──► setzt feltPercent ──► Verlaufsgraph ──► Momentum
    │                                                │
    └──► setzt lastMeaningfulChange                  │
                    │                                │
                    ▼                                ▼
              Staleness-Decay              Todeszone-Erkennung
                    │                       (%-Höhe × Momentum)
                    ▼                                │
        Pausiert-oder-verhungert-Frage               │
                    │                                │
                    ▼                                ▼
              WIP-Limit  ◄────────────────  Wochenbericht
                    │
                    ▼
        Blockiert neue Projekte
```

Ein einziger Input (der Check-in) speist alles. Es gibt keine zweite Datenquelle, kein Import, keine Integration. Wenn du nicht eincheckst, funktioniert die App nicht — und genau das ist die einzige Gewohnheit, die sie von dir verlangt.

---

## 6. Was bewusst NICHT drin ist

| Nicht drin | Warum |
|---|---|
| Streaks, Badges, Konfetti | Führt dazu, dass du das System spielst statt Projekte fertig machst |
| Zeiterfassung | Zeit ≠ Fortschritt. Und du würdest anfangen, Stunden zu optimieren |
| Kanban-Board mit Subtasks | Du hast schon fünf Tools dafür. Das hier ist eine Metaebene, kein Task-Manager |
| Team-Features, Sharing | Das ist ein Beichtstuhl, kein Portfolio |
| Push-Notifications | Der visuelle Verfall ist die Benachrichtigung |
| Kalender-Integration | Deadlines von außen sind ein anderes Problem |
| KI-Vorschläge ("Du solltest an X arbeiten") | Du weißt es selbst. Das Problem ist nicht Information, sondern Konfrontation |

---

## 7. Visuelle Richtung

Ein Vorschlag, keine Vorschrift — du bist der Designer.

- **Dunkel**, aber nicht das übliche Dev-Tool-Grau. Eher ein warmes Anthrazit, damit der Sättigungsverlust der verrottenden Karten überhaupt wirkt.
- **Farbe ist Information, nicht Dekoration.** Jede Kategorie bekommt einen Farbton, und dieser Farbton wird durch Staleness entzogen. Volle Farbe muss man sich verdienen.
- **Typografie trägt die Hierarchie**, nicht Boxen und Rahmen. Der Prozentwert groß, das Delta lesbar, die Metadaten klein.
- **Grain-Overlay** bei Staub-Zustand. Als Fotograf verstehst du sofort, was ein unterbelichtetes, verrauschtes Bild bedeutet: da war zu wenig Licht.
- **Keine Animationen beim Fortschritt.** Ein Balken, der befriedigend hochwächst, ist Belohnung für den Check-in — nicht für die Arbeit. Werte ändern sich hart.

---

## 8. Offene Fragen

1. **Selbstbetrug bleibt möglich.** Du kannst Deltas absichtlich vage halten oder gar nicht eintragen. Die App kann das nicht verhindern. Ist das ein akzeptables Restrisiko oder braucht es einen Mechanismus?
2. **Was passiert, wenn du wochenlang gar nicht eincheckst?** Die App verwaltet dann Karteileichen und wird selbst zu einem verhungerten Projekt. Ironisch, aber real.
3. **Granularität:** Ist "Spektra" ein Projekt — oder sind "Spektra Core", "Spektra Doku" und "Spektra Website" drei? Zu grob und der Balken bewegt sich nie. Zu fein und du hast wieder einen Task-Manager gebaut.
4. **Startwert-Problem:** Wenn du deine fünf laufenden Projekte einträgst, sind vier davon sofort über 70% und in der Todeszone. Ist das ein guter Weckruf oder demotivierend am Tag eins?

---

## 9. Erster Meilenstein

Wenn das gebaut wird, dann in dieser Reihenfolge — und *nur* das, bis es benutzbar ist:

1. Projekt anlegen (mit Definition of Done als Pflichtfeld)
2. Check-in-Flow mit Deltas und %
3. Dashboard-Liste mit Balken und Tageszähler
4. Staleness-Decay

Das ist die kleinste Version, die schon weh tut. Alles danach — Wochenbericht, WIP-Limit, Beerdigung, Verlaufsgraph — ist Ausbau.

Wäre auch irgendwie peinlich, wenn ausgerechnet diese App bei 78% hängenbleibt.
