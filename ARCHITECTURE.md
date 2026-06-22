# Mission Résistance — Architecture de l'application Flutter

> **Statut** : architecture cible (v1) · **Repo** : `app/` (dépôt Flutter indépendant)
> **Objet** : décrire l'architecture *du code* de l'app mobile « Poste Radio TSF » — couches, dépendances, conventions, et la place de chaque brique (verrouillage, émission, réception, scénario, appel QG, thème, hors‑ligne).
> **Source de vérité produit** : la spécification [`../BRIEF.md`](../BRIEF.md) (= `design/SPEC.md`) + le prototype `design/prototype/final.html` + les tokens `design/tokens/design-tokens.json`.

L'app est l'accessoire d'un grand jeu de colonie sur le thème d'une **radio militaire WWII** : chaque équipe a un « poste » verrouillé par un **code**, d'où elle peut **émettre** (push‑to‑talk), **réécouter** les messages reçus, **appeler le QG** (appel réel) et progresser dans un **scénario** d'indices à déchiffrer.

---

## Sommaire

1. [Principes directeurs](#1-principes-directeurs)
2. [Les quatre couches](#2-les-quatre-couches)
3. [Arborescence cible de `lib/`](#3-arborescence-cible-de-lib)
4. [Couche Domain](#4-couche-domain)
5. [Couche Application](#5-couche-application)
6. [Couche Infrastructure](#6-couche-infrastructure)
7. [Couche UI](#7-couche-ui)
8. [Verrouillage & session](#8-verrouillage--session)
9. [Émission vocale (push‑to‑talk)](#9-émission-vocale-push-to-talk)
10. [Réception & lecture audio](#10-réception--lecture-audio)
11. [Scénario & progression](#11-scénario--progression)
12. [Appel QG](#12-appel-qg)
13. [Hors‑ligne & temps réel](#13-hors-ligne--temps-réel)
14. [Thème & design system](#14-thème--design-system)
15. [Bootstrap (`main.dart`)](#15-bootstrap-maindart)
16. [Conventions de code](#16-conventions-de-code)
17. [Dépendances (`pubspec.yaml`)](#17-dépendances-pubspecyaml)
18. [Tests](#18-tests)

---

## 1. Principes directeurs

- **Architecture hexagonale (ports & adapters)** : le domaine ne connaît ni Flutter, ni Dio, ni le micro, ni le système de fichiers. Les dépendances pointent **vers l'intérieur** (UI → Application → Domain ; l'Infrastructure implémente des **ports** définis par le Domain).
- **Règle de flux** : `Provider (UI) → Service (Application) → Repository/Port (Infrastructure)`. L'UI ne parle jamais directement à un repository ou à un client réseau.
- **Parité visuelle d'abord** : la spec impose un rendu skeuomorphique au pixel/au texte près. Le design system (tokens, matières, polices) est une brique de **première classe**, pas un détail.
- **Simulé → réel sans changer l'UI** : le prototype simule l'émission, la réception et la lecture. Les **ports** sont dessinés pour que le passage au vrai backend (audio, WebSocket, persistance) ne touche **que** l'Infrastructure, jamais l'UI ni l'Application.
- **Jumeaux `InMemory*`** : chaque port a une implémentation en mémoire (données de démo de la spec §8.2 / §10) **et** une implémentation réseau. On développe et on teste sur les jumeaux ; on bascule par injection.
- **Verrouillage portrait, edge‑to‑edge** : orientation portrait forcée, rendu bord‑à‑bord, contenu décalé via les safe‑area insets (cf. BRIEF §13).

---

## 2. Les quatre couches

| Couche | Rôle | Connaît | Ne connaît pas |
|---|---|---|---|
| **Domain** | entités, value objects, règles métier pures, **ports** (interfaces) | Dart pur | Flutter, Dio, Riverpod, plugins |
| **Application** | orchestration : services, machines à états, DTO ↔ entités | Domain | widgets, HTTP, plugins natifs |
| **Infrastructure** | adapters : repositories Dio, jumeaux InMemory, audio, persistance, connectivité, **DI Riverpod** | Domain + Application | widgets |
| **UI** | écrans, widgets, thème, providers de présentation | Application (via providers) | Infrastructure (jamais en direct) |

La frontière nette est la couche **Domain** : elle déclare des `abstract interface class` (ports) que l'Infrastructure implémente. C'est l'inversion de dépendances qui rend « simulé → réel » indolore.

---

## 3. Arborescence cible de `lib/`

```
lib/
├── main.dart                        # bootstrap : ProviderScope + MissionResistanceApp
├── app/
│   ├── mission_resistance_app.dart  # MaterialApp, thèmes, routeur
│   └── router.dart                  # go_router : redirection selon l'état de session
├── domain/
│   ├── entities/                    # Team, RadioMessage, Mission, Clue, Scenario
│   ├── value_objects/               # AccessCode, EmissionLevel, MessageId, Duration…
│   ├── ports/                       # AuthPort, EmissionPort, InboxPort, ScenarioPort, DialerPort, ProgressStore
│   └── exceptions/                  # InvalidCodeException, EmissionException…
├── application/
│   ├── dto/                         # MessageDto, ScenarioDto (forme transport)
│   ├── session/                     # SessionController (sealed state : locked/unlocked)
│   └── services/                    # AccessService, EmissionService, InboxService, ScenarioService, DialerService
├── infrastructure/
│   ├── di.dart                      # providers Riverpod : câblage des ports → adapters
│   ├── http/                        # Dio + intercepteurs (Authorization, X‑Team‑Id)
│   ├── audio/                       # RecorderAdapter (micro), PlayerAdapter (lecture)
│   ├── remote/                      # DioInboxRepository, DioScenarioRepository, WsSignalSource
│   ├── memory/                      # InMemoryInbox, InMemoryScenario (données de démo)
│   ├── persistence/                 # ProgressStore (shared_preferences / drift)
│   └── connectivity/               # ConnectivityWatcher + bannière hors‑ligne
└── ui/
    ├── theme/
    │   └── app_colors.dart          # tokens TSF (olive · laiton · LCD) — déjà en place
    ├── widgets/
    │   ├── resistance_logo.dart     # marque (flutter_svg) — déjà en place
    │   ├── radio_panel.dart         # panneau olive (vignette, vis, plaque)
    │   ├── lcd_ticker.dart          # bandeau LCD + curseur clignotant
    │   ├── brass_button.dart        # .kbtn (olive / laiton)
    │   └── toggle_switch.dart       # interrupteur à bascule (onglets)
    └── features/
        ├── lock/                    # écran de verrouillage (saisie du code)
        ├── radio/                   # onglet « Trafic radio » : VU‑mètre, PTT, Appel QG, inbox
        └── carnet/                  # onglet « Carnet de mission » : progression, stepper, cartes‑indices
```

> L'état actuel du repo contient déjà `ui/theme/app_colors.dart` et `ui/widgets/resistance_logo.dart` (commit de branding) ainsi qu'un écran d'accueil provisoire dans `main.dart`. Les modules ci‑dessus décrivent la cible.

---

## 4. Couche Domain

### 4.1 Entités

| Entité | Champs clés | Notes |
|---|---|---|
| `Team` | `id`, `name`, `channel` | résolue à partir du code d'accès (BRIEF §13.3) |
| `RadioMessage` | `id`, `sender`, `sentAt`, `duration`, `subtitle`, `audioUrl`, `status` | trié récent → ancien |
| `Mission` | `index`, `title`, `clues: List<Clue>` | ordre = ordre de déverrouillage |
| `Clue` | `index`, `text` | « indice » déchiffrable |
| `Scenario` | `missions: List<Mission>` | scénario complet de l'équipe |

`MessageStatus` est un `enum { unread, heard, playing }` (spec §8.2).

### 4.2 Value objects (immuables, auto‑validés)

- `AccessCode` : encapsule la comparaison **insensible à la casse + `.trim()`** (`value.trim().toLowerCase()`), cf. BRIEF §7. Rejette une saisie vide.
- `EmissionLevel` : niveau VU 0–10 ; expose `angleDegrees => value * 10 - 50` (géométrie du VU‑mètre, BRIEF §8.1.a).
- `MissionProgress` : `currentMission`, `unlocked: List<int>`, `flipped: Set<String>` — l'état de progression sérialisable (spec §5.2).

Les VO portent **les règles**, pas les services : une `AccessCode` *sait* se comparer ; un `EmissionLevel` *sait* se convertir en angle.

### 4.3 Ports (interfaces que l'Infrastructure implémente)

```dart
abstract interface class AuthPort {
  Future<Team> unlock(AccessCode code); // lève InvalidCodeException si mauvais code
}

abstract interface class EmissionPort {
  Future<void> start();                 // ouvre le micro
  Stream<EmissionLevel> levels();       // amplitude réelle → VU
  Future<RadioMessage> stop();          // clôt, upload, diffuse
}

abstract interface class InboxPort {
  Future<List<RadioMessage>> fetch();   // pull initial
  Stream<RadioMessage> incoming();      // push temps réel (WebSocket)
  Future<void> markHeard(MessageId id); // statut lu persistant
}

abstract interface class ScenarioPort {
  Future<Scenario> load(Team team);
}

abstract interface class DialerPort {
  Future<void> callHq();                // ouvre le composeur (ne compose pas en silence)
}

abstract interface class ProgressStore {
  Future<MissionProgress?> read();
  Future<void> write(MissionProgress progress);
}
```

Toutes les exceptions métier dérivent d'une base `DomainException` (`InvalidCodeException`, `EmissionException`, `PlaybackException`…).

---

## 5. Couche Application

### 5.1 DTO ↔ entités

Les `*Dto` reflètent la **forme transport** (JSON backend, scénario `design/tokens/design-tokens.json`/config). Le mapping `Dto → entité` vit dans l'Application : le Domain reste ignorant du format réseau. Exemple : `MessageDto.toEntity()` parse `sentAt` (ISO) et `duration` (secondes) en VO.

### 5.2 `SessionController` (machine à états)

État scellé qui pilote l'accès à l'app (BRIEF §5, §7) :

```dart
sealed class SessionState {}
class Locked  extends SessionState { final String? error; }   // erreur = "CODE INCORRECT"
class Unlocking extends SessionState {}                        // 750 ms de transition
class Unlocked extends SessionState { final Team team; }       // plaque → TEAM
```

- `submit(String raw)` → construit `AccessCode`, appelle `AuthPort.unlock` ; succès ⇒ `Unlocking` puis `Unlocked(team)` après 750 ms (spec §7) ; échec ⇒ `Locked(error: …)` (déclenche le **shake** + halo rouge côté UI).
- Le **routeur** (go_router) observe `SessionState` et **redirige** : tant que `locked`, on reste sur l'écran de verrouillage ; sinon, on accède au shell à deux onglets.

### 5.3 Services

| Service | Responsabilité | Port(s) |
|---|---|---|
| `AccessService` | valider le code, résoudre l'équipe | `AuthPort` |
| `EmissionService` | piloter le push‑to‑talk (start/level/stop), exposer le chrono | `EmissionPort` |
| `InboxService` | charger + écouter les messages, gérer `unread/heard/playing`, tri récent→ancien | `InboxPort` |
| `ScenarioService` | charger le scénario, déverrouiller séquentiellement, replier/revoir, « Mission accomplie », **persister** la progression | `ScenarioPort`, `ProgressStore` |
| `DialerService` | déclencher l'appel QG | `DialerPort` |

Les services exposent des `Notifier`/`AsyncNotifier` Riverpod (générés via `riverpod_annotation`). **Aucun** `setState` métier dans les widgets.

---

## 6. Couche Infrastructure

### 6.1 HTTP (Dio)

Un `Dio` unique configuré par `infrastructure/http/` : `baseUrl`, timeouts, et **intercepteurs** :
- `AuthInterceptor` : ajoute `Authorization` (jeton d'équipe) + `X-Team-Id` (après déverrouillage).
- `LoggingInterceptor` (debug only).

### 6.2 Adapters distants & jumeaux InMemory

- `DioInboxRepository` / `DioScenarioRepository` : implémentations réseau des ports.
- `InMemoryInbox` : sert les **3 messages de démo** (BRIEF §8.2, ordre et états exacts) ; `InMemoryScenario` : les **4 missions** de la spec §10 avec `currentMission=1`, `unlocked=[2,0,0,0]`.
- On développe/teste sur les jumeaux ; le choix se fait dans `di.dart` (flag d'environnement).

### 6.3 Audio

- `RecorderAdapter` (port `EmissionPort`) : permission micro, enregistrement à l'appui, fin au relâché, upload du clip, diffusion. `levels()` émet l'**amplitude réelle** → VU‑mètre.
- `PlayerAdapter` : lecture des clips reçus (l'égaliseur de la carte message reflète la lecture).

### 6.4 Persistance & connectivité

- `ProgressStore` : `shared_preferences` pour `MissionProgress` (sérialisé) + le flag optionnel « rester déverrouillé » (BRIEF §2). Un cache de messages (drift) est optionnel pour la lecture hors‑ligne.
- `ConnectivityWatcher` (`connectivity_plus`) : expose un `Stream<bool>` en ligne/hors‑ligne, consommé par la **bannière hors‑ligne**.

### 6.5 DI (`infrastructure/di.dart`)

Le câblage **ports → adapters** se fait via des providers Riverpod *override‑ables* :

```dart
@riverpod
InboxPort inboxPort(Ref ref) =>
    kUseFakes ? InMemoryInbox() : DioInboxRepository(ref.watch(dioProvider));
```

Les services dépendent des **ports** (jamais d'une implémentation concrète). Les tests surchargent les providers par des fakes via `ProviderScope(overrides: …)`.

---

## 7. Couche UI

### 7.1 Shell à deux onglets

Une **seule page** après déverrouillage (BRIEF §5.1) : en‑tête commun (`radio_panel` + `toggle_switch` + `lcd_ticker`) et corps qui bascule entre `radio/` et `carnet/` **sans rechargement**, piloté par l'**interrupteur à bascule** (libellé actif ambre, glissement 0,2 s).

### 7.2 Onglet « Trafic radio » (`features/radio/`)

- **VU‑mètre** (`CustomPainter`) : géométrie exacte de la spec §8.1.a (viewBox 300×96, pivot 150,86, `angle = v*10−50`, zone rouge ≥ 8, repos −46°). Pendant l'émission, niveau rafraîchi toutes les 110 ms.
- **TRANSMETTRE** (PTT) : `Listener`/`GestureDetector` sur `pointerDown`/`pointerUp` ; état *live* (rouge enfoncé, voyant pulsé, chrono) ; cf. §9.
- **APPEL QG** : bouton rouge → `DialerService.callHq()` ; cf. §12.
- **Réception** : `ListView` de cartes message (`unread/heard/playing`, égaliseur), triées récent→ancien ; cf. §10.

### 7.3 Onglet « Carnet de mission » (`features/carnet/`)

- **Barre de progression** (`m/total`, `pct = round(m/total×100)`).
- **Stepper** des missions (`done` / `current` / `upcoming`).
- **Cartes‑indices** : flip 3D Y (0,6 s `cubic-bezier(.4,.8,.3,1)`), états `revealed/repliée/available/locked`, déverrouillage **séquentiel** avec cadenas, **modal** de confirmation dès le 2ᵉ indice ; cf. §11.

### 7.4 Bandeau LCD (`lcd_ticker`)

Affiche un **statut par défaut** par onglet et des **messages transitoires** (retour au défaut après 1,8 s) — catalogue de textes en BRIEF §11. Curseur `▮` clignotant 1 s.

### 7.5 Providers de présentation

Chaque écran lit son état via `ref.watch(...)` sur les `Notifier` de l'Application. Les widgets restent **sans logique métier** : ils mappent état → matière (dégradés, ombres `inset`, reliefs — BRIEF §4.4) et intentions → appels de service.

---

## 8. Verrouillage & session

1. Écran de verrouillage (`features/lock/`) : plaque `VERROUILLÉ`, champ LCD (Special Elite 26 px, interlettrage 8 px, MAJ), bouton `Déverrouiller`.
2. Valider (bouton **ou** Entrée) → `SessionController.submit(value)`.
3. **Correct** : `lockhint` vert « Poste déverrouillé — bienvenue », plaque → `TEAM`, puis après **750 ms** bascule vers l'onglet Radio (le routeur retire le verrou).
4. **Incorrect** : **shake** 0,4 s + halo rouge, texte rouge, `lockhint` rouge « CODE INCORRECT — réessayez », champ vidé + refocus.

Le code → équipe : en v1, `AuthPort` distant mappe le code vers l'équipe et son scénario (BRIEF §13.3). Le jumeau InMemory accepte le code de démo `6450` → `LES RENARDS`.

`AuthPort.unlock` renvoie un `LoginResult {team, partie?}` : `partie` est la **partie active** du groupe de l'équipe au moment du login (cf. §8.1), ou `null` si aucune.

### 8.1 Partie (session de jeu)

La régie **démarre / arrête** une partie par groupe (au plus une active). Toutes les actions du poste sont **scopées à la partie courante** et la portent dans l'en‑tête **`X-Partie-Id`**.

- **`PartieController`** (`application/session/`) est la source de vérité : amorcé depuis la session mémorisée (`StoredSession.partieId`, pour que l'en‑tête parte dès les premiers appels), puis **sonde** `GET /sessions/:team/partie` (~10 s, `PartiePort`). États : `PartieUnknown` → `PartieWaiting` (aucune) / `PartiePlaying(partie)` / `PartieOver`.
- **`currentPartieIdProvider`** expose l'id en jeu ; les providers réseau scopés à la partie (`progressStoreProvider`, `inboxPortProvider`, `outboxPortProvider`, et le suivi GPS) le **watchent** → se reconstruisent à chaque changement de partie ⇒ **ardoise vierge** (la clé de cache locale de la progression inclut `partieId`).
- **Fin de partie** : le backend renvoie **`410 partie_finished`** aux écritures. L'isolate GPS interprète ce code → **arrête le service** (`TrackingStopReason.partieEnded`) et signale l'isolate UI ; le `PartieController` (poll ou signal) bascule en `PartieOver`. Le suivi GPS ne démarre **que** quand une partie est en cours, et **relance** avec le nouvel id si la régie en ouvre une autre.
- **UI** (`features/partie/partie_status_screen.dart`) : `PartieWaiting` → « en attente de partie » ; `PartieOver` → « partie terminée » ; le shell de jeu n'est rendu qu'en `PartiePlaying`.

Le jumeau InMemory (`InMemoryPartie`) renvoie toujours une partie active → la démo joue immédiatement.

---

## 9. Émission vocale (push‑to‑talk)

- **Appui maintenu** : `EmissionService.start()` ouvre le micro (permission au 1ᵉʳ usage) ; le bouton passe *live* (rouge, enfoncé, voyant pulsé 0,7 s) ; le VU‑mètre s'anime sur `EmissionPort.levels()` ; chrono `Enregistrement 0:0X` (+1 s/s) ; bandeau « ▶ ÉMISSION EN COURS ».
- **Relâché** : `EmissionService.stop()` clôt, **upload + diffusion** aux postes de la partie ; sous‑titre `Message envoyé (Xs) ✓` ; bandeau « ✓ MESSAGE ÉMIS (Xs) » ; reset du sous‑titre après 2,6 s.
- Le niveau VU suit l'**amplitude réelle** du micro (pas d'aléatoire en natif ; l'aléatoire n'existe que dans le jumeau de démo).

---

## 10. Réception & lecture audio

- `InboxService` charge la liste (`InboxPort.fetch()`, tri récent→ancien) et **écoute** les nouveaux (`incoming()`, WebSocket).
- Statuts : `unread` (badge `NOUVEAU`, voyant ambre) → `playing` (égaliseur, durée/▶ masqués) → `heard` (badge `↺ réécouter`, voyant éteint, **réécoutable** à volonté).
- Lecture : `PlayerAdapter` joue l'audio réel (le délai simulé `max(2200, s×180)` ms n'est que dans le jumeau). `markHeard` persiste le statut.

---

## 11. Scénario & progression

- `ScenarioService` charge le `Scenario` de l'équipe et tient `MissionProgress {currentMission, unlocked[], flipped}` (spec §5.2), **persisté** via `ProgressStore`.
- **Déverrouillage séquentiel** : seule la carte `available` (`k = unlocked[m]`) est déchiffrable ; les suivantes sont `locked` (cadenas, inertes).
  - 1ᵉʳ indice (`k=0`) : flip direct ; à partir du 2ᵉ : **modal** de confirmation (BRIEF §9.4) avant le flip.
  - Au déchiffrement : `unlocked[m]++`, bandeau « ▸ INDICE n DÉCHIFFRÉ », la carte suivante devient disponible.
- **Replier / revoir** : une carte déchiffrée se retourne face cachée (mémorisé dans `flipped`) ; re‑clic la ré‑révèle.
- **« Mission accomplie »** : passe à la mission suivante (0 indice déchiffré) ou « ✓ SCÉNARIO TERMINÉ » à la dernière.

---

## 12. Appel QG

`DialerService.callHq()` ouvre le **composeur** avec `TEL_QG` via `url_launcher` (`tel:`) — iOS `tel://`, Android `ACTION_DIAL`. **Ne jamais auto‑composer** : l'OS demande confirmation (BRIEF §13). État UI *armed* (pulsation rouge 0,8 s) puis reset après 2,5 s.

---

## 13. Hors‑ligne & temps réel

- **Lecture en cache, écriture en ligne** : la liste des messages et le scénario se lisent depuis un cache local quand hors‑ligne ; l'émission et le marquage « lu » se rejouent à la reconnexion (file d'attente). La **progression** est locale d'abord (source de vérité offline‑friendly).
- **Bannière hors‑ligne** : `ConnectivityWatcher` pilote un bandeau discret (cohérent avec l'esthétique LCD).
- **Temps réel** : `WsSignalSource` (`web_socket_channel`) pousse les nouveaux messages et, à terme, la présence des postes. Dégradation gracieuse en pull si le socket tombe.

---

## 14. Thème & design system

- **Tokens** : `design/tokens/design-tokens.json` est la source de vérité couleurs/typo/espacements/rayons/durées. Ils sont transcrits dans `ui/theme/app_colors.dart` (`TsfPalette` brut + `AppColors` `ThemeExtension`, accès via `context.appColors`). Thème volontairement **sombre** (olive), un variant clair existe pour complétude.
- **Polices** (à embarquer en assets, **pas** de CDN — BRIEF §13) : **Black Ops One** (display/pochoir), **Saira Condensed** 500/600/700 (corps), **Special Elite** (LCD, indices, saisie du code). Déclarées dans `pubspec.yaml > flutter > fonts` une fois les `.ttf` déposés (`design/fonts/`).
- **Matières & relief** (BRIEF §4.4) : dégradés (`LinearGradient`/`RadialGradient`), ombres externes + `inset` simulés (`BoxShadow`), reliefs des touches (`translateY` au pressé). **Ne pas aplatir** : le relief fait partie de l'identité.
- **Logo** : `ResistanceLogo` (flutter_svg) rend `assets/branding/mission-resistance-logo.svg` ; l'icône d'app et les icônes de lanceur sont générées depuis `design/logo/` par `flutter_launcher_icons` (fond olive `#2e3122`).

---

## 15. Bootstrap (`main.dart`)

```dart
void main() {
  // (cible) WidgetsFlutterBinding + orientation portrait + edge‑to‑edge,
  // puis montage de l'arbre Riverpod.
  runApp(const ProviderScope(child: MissionResistanceApp()));
}
```

`MissionResistanceApp` monte un `MaterialApp` (thèmes clair/sombre issus de `AppThemeData`, `themeMode: dark`) et — en cible — un `MaterialApp.router` piloté par go_router, dont la **redirection** dépend de `SessionState`. L'écran d'accueil provisoire actuel sera remplacé par l'écran de verrouillage comme route racine.

---

## 16. Conventions de code

- **Lints** : `flutter_lints` + `riverpod_lint` (déclaré dans `analysis_options.yaml`). `dart format` au save (réglages `.vscode/`).
- **Immutabilité** : entités et VO immuables ; `copyWith` explicites (cf. `AppColors`).
- **Nommage** : fichiers `snake_case`, types `UpperCamelCase` ; ports suffixés `Port`, jumeaux préfixés `InMemory`, adapters réseau préfixés `Dio`.
- **Pas de logique métier dans les widgets** ; pas d'accès Infrastructure depuis l'UI.
- **Textes** : le copy exact (BRIEF §11) est centralisé (constantes/localisation), pas dispersé dans les widgets.
- **Génération** : `dart run build_runner build` pour les providers `riverpod_generator`.

---

## 17. Dépendances (`pubspec.yaml`)

**Déjà présentes** : `flutter_riverpod`, `riverpod_annotation`, `flutter_svg` ; dev : `riverpod_generator`, `build_runner`, `flutter_launcher_icons`, `flutter_lints`.

**À ajouter au fil de l'implémentation** :

| Besoin | Paquet candidat |
|---|---|
| Routage gardé par session | `go_router` |
| HTTP | `dio` |
| Enregistrement micro | `record` |
| Lecture audio | `just_audio` (ou `audioplayers`) |
| Appel téléphonique | `url_launcher` |
| Temps réel | `web_socket_channel` |
| Connectivité | `connectivity_plus` |
| Persistance simple | `shared_preferences` |
| Cache structuré (option) | `drift` |
| Permissions | `permission_handler` |

---

## 18. Tests

- **Domain / VO** : tests unitaires purs (ex. `AccessCode` insensible à la casse, `EmissionLevel.angleDegrees`, déverrouillage séquentiel du scénario).
- **Application** : tests des `Notifier`/services sur les **jumeaux InMemory** (machine de session locked→unlocked, tri inbox, progression + persistance).
- **UI** : tests de widgets (smoke test actuel `test/widget_test.dart` ; à étendre : saisie du code → shake/déverrouillage, flip d'une carte‑indice, états du PTT).
- **Stratégie** : la dépendance aux **ports** + `ProviderScope(overrides:)` rend tout testable sans réseau, sans micro et sans backend.

---

*Réf. produit : [`../BRIEF.md`](../BRIEF.md) · prototype `design/prototype/final.html` · tokens `design/tokens/design-tokens.json`.*
