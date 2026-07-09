# Runbook — Injection sécurisée des clés API & rotation (AD-12)

> **Source of truth sécurité** pour l'injection des secrets (clé Google Maps et tout
> autre secret) dans les applications consommatrices de zcrud (DODLP, lex_douane, IFFD,
> DLCFTI). Matérialise **AD-12 — « Zéro secret dans les packages »**.
>
> **Story d'ancrage :** E1-5 (Révocation de la clé Google Maps fuitée).
> **Consommé par :** E11a-1 (`zcrud_geo`, champ géo — aucune clé dans le package),
> E7 (intégration DODLP), E11a-3 (retrait de tout `badCertificateCallback => true`).

---

## 0. Règle d'or (non négociable)

> **La clé n'est JAMAIS committée.** Aucune clé API ni secret n'entre dans un package
> zcrud, ni dans un fichier suivi par git d'une app consommatrice. Les clés (Maps,
> endpoints, tokens) sont fournies **exclusivement** par la **config plateforme** de
> l'app, à l'exécution ou au build.

Ce document n'utilise que des **placeholders** — jamais une vraie clé :

| Placeholder | Usage |
|---|---|
| `YOUR_MAPS_API_KEY` | Valeur à substituer par la vraie clé, hors dépôt |
| `$GOOGLE_MAPS_API_KEY` | Variable d'environnement / secret de pipeline |
| `AIza<REDACTED>` | Forme d'une clé Google, volontairement tronquée |

> ⚠️ **Ne jamais** écrire dans ce dépôt (doc, test, fixture) une séquence `AIza`
> suivie de 35 caractères réels. En cas d'exemple ressemblant à une clé, utiliser une
> concaténation factice (cf. `scripts/ci/prove_gates.dart`) ou un placeholder explicite.

---

## 1. Injection par plateforme

Pour chaque plateforme : **où** l'app dépose le secret (fichier gitignoré ou secret de
pipeline) et **comment** il est lu à l'exécution/au build — la clé restant **hors du
contrôle de version**.

### 1.1 Dart (build-time, toutes plateformes Flutter)

Mécanisme recommandé : `--dart-define-from-file` sur un fichier **gitignoré**.

```bash
# config/secrets.json  ← GITIGNORÉ (jamais committé)
# {
#   "GOOGLE_MAPS_API_KEY": "YOUR_MAPS_API_KEY"
# }

flutter run   --dart-define-from-file=config/secrets.json
flutter build apk --dart-define-from-file=config/secrets.json
```

Alternative ponctuelle (une clé) :

```bash
flutter build web --dart-define=GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY
```

Accès in-app (jamais de littéral dans le code) :

```dart
const mapsKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');
// mapsKey est injecté au build ; absent du code source et de git.
```

> **Interdit :** `const mapsKey = 'AIza<REDACTED>';` — un littéral committé.

### 1.2 Android

La clé vit dans `local.properties` (**gitignoré** — déjà couvert par `.gitignore`
racine `**/local.properties`) **ou** dans un secret de pipeline CI ; elle est propagée
au manifeste via Gradle `manifestPlaceholders`, jamais écrite en dur.

```properties
# android/local.properties  ← GITIGNORÉ
GOOGLE_MAPS_API_KEY=YOUR_MAPS_API_KEY
```

```gradle
// android/app/build.gradle
def localProps = new Properties()
def f = rootProject.file('local.properties')
if (f.exists()) { f.withInputStream { localProps.load(it) } }

android {
    defaultConfig {
        // Repli sur la variable d'env CI si local.properties absent (build pipeline).
        manifestPlaceholders["GOOGLE_MAPS_API_KEY"] =
            localProps.getProperty("GOOGLE_MAPS_API_KEY")
                ?: (System.getenv("GOOGLE_MAPS_API_KEY") ?: "")
    }
}
```

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<meta-data
    android:name="com.google.android.geo.API_KEY"
    android:value="${GOOGLE_MAPS_API_KEY}" />
```

> La valeur `${GOOGLE_MAPS_API_KEY}` est un **placeholder Gradle** résolu au build ;
> le manifeste committé ne contient aucune clé.

### 1.3 iOS

La clé est injectée via un `.xcconfig` **gitignoré** (ou un secret CI), puis exposée à
`Info.plist` par **référence de build setting** — jamais de littéral committé.

```xcconfig
// ios/Flutter/Secrets.xcconfig  ← GITIGNORÉ
//   #include "Secrets.xcconfig" depuis Debug.xcconfig / Release.xcconfig
GOOGLE_MAPS_API_KEY = YOUR_MAPS_API_KEY
```

```xml
<!-- ios/Runner/Info.plist -->
<key>GMSApiKey</key>
<string>$(GOOGLE_MAPS_API_KEY)</string>
```

```swift
// ios/Runner/AppDelegate.swift — lecture depuis Info.plist, pas de littéral
if let key = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String {
    GMSServices.provideAPIKey(key)
}
```

### 1.4 Web

La clé est injectée **au build** (substitution d'un template `index.html` par la CI) ou
servie **au runtime** par le backend ; jamais committée dans le repo statique.

```html
<!-- web/index.html (template versionné avec placeholder) -->
<script src="https://maps.googleapis.com/maps/api/js?key=__GOOGLE_MAPS_API_KEY__"></script>
```

```bash
# Étape de build CI : substitution du placeholder par le secret du pipeline
sed -i "s/__GOOGLE_MAPS_API_KEY__/$GOOGLE_MAPS_API_KEY/" build/web/index.html
```

> Le fichier committé ne porte que `__GOOGLE_MAPS_API_KEY__`. En cas d'exigence plus
> stricte, préférer une **config runtime** servie par le backend (endpoint authentifié),
> évitant toute clé dans les assets statiques.

### 1.5 CI/CD

La clé vit **exclusivement** dans les **secrets du pipeline** (GitHub Actions
`secrets.*` / variables protégées), injectée au build via `--dart-define(-from-file)`
ou variable d'environnement. **Jamais** dans un fichier suivi.

```yaml
# .github/workflows/*.yml (app consommatrice)
- name: Build
  env:
    GOOGLE_MAPS_API_KEY: ${{ secrets.GOOGLE_MAPS_API_KEY }}
  run: flutter build apk --dart-define=GOOGLE_MAPS_API_KEY=$GOOGLE_MAPS_API_KEY
```

---

## 2. Restriction de la clé (défense en profondeur)

Une clé **restreinte** limite l'impact d'une fuite résiduelle. À configurer côté
**Google Cloud Console** (renvoi au §4 — action Owner) :

- **Restriction d'application :**
  - Android : empreinte **SHA-1** du certificat de signature + nom de package.
  - iOS : **bundle id** de l'app.
  - Web : liste de **referers HTTP** autorisés.
- **Restriction d'API :** limiter la clé au **Maps SDK** strictement nécessaire
  (Maps SDK for Android/iOS, Maps JavaScript API), rien de plus.

> Restriction ≠ substitut de la non-committance : on applique **les deux** (clé hors
> git **et** clé restreinte).

---

## 3. `.gitignore` — porteurs de secrets

Ce dépôt (zcrud) n'héberge aucun de ces fichiers, mais **prescrit** aux apps
consommatrices de les ignorer. L'existant zcrud couvre déjà :

```
**/local.properties     # Android
.env                     # env génériques
.env.*                   # variantes
!.env.example            # gabarit non secret autorisé
```

Ajouts recommandés **côté app** (à confirmer dans le `.gitignore` de chaque app) :

```
config/secrets.json      # --dart-define-from-file (Dart)
*.env                    # tout fichier d'environnement
ios/Flutter/Secrets.xcconfig
**/*.keystore            # keystores Android
**/google-services.json  # si contient des identifiants sensibles
```

---

## 4. Check-list de révocation / rotation

> ## 🔴 HUMAN ACTION REQUIRED — Owner: Zakarius
>
> Les étapes ci-dessous **ne sont pas exécutables par un agent** : elles s'opèrent dans
> la **Google Cloud Console** et sur les dépôts externes **DODLP / DLCFTI**. Aucun outil
> zcrud ne peut les réaliser ni les vérifier. Le passage global de la story E1-5 à
> `done` reste **bloqué** tant que l'Owner n'a pas **attesté** leur complétion (§5).

Contexte : une clé Google Maps est aujourd'hui **commitée en clair** dans les dépôts
applicatifs **DODLP** et **DLCFTI** (moteurs `data_crud` dupliqués dont zcrud est
l'extraction). Cette fuite est **exogène à ce dépôt** (zcrud est propre — cf. §6).

1. **Identifier** la clé fuitée dans **Google Cloud Console → APIs & Services →
   Credentials** du projet Maps de DODLP/DLCFTI.
2. **Neutraliser** l'ancienne clé : la **révoquer (supprimer)** ; ou, si une rotation
   transparente est préférée, la **restreindre drastiquement** (application + API).
3. **Créer une nouvelle clé restreinte** (par app + par API, cf. §2) et l'injecter via
   la config plateforme (§1) — **jamais committée**.
4. **Purger** la clé des dépôts DODLP/DLCFTI : retrait du fichier suivi ; idéalement
   réécriture d'historique / invalidation (l'ancienne clé étant révoquée).
5. **Vérifier l'invalidité** : un appel Maps avec l'**ancienne** clé retourne une erreur
   d'autorisation (`REQUEST_DENIED` / clé invalide). **Ne jamais** recopier la vraie clé
   (ancienne ou nouvelle) dans ce dépôt, même pour la preuve.
6. **Attester** la complétion (§5).

---

## 5. Condition de clôture (attestation Owner)

Le passage de la story E1-5 à `done` requiert l'attestation explicite de l'Owner
(Zakarius) pour le **groupe B** (AC 7–9). À consigner ici (ou dans la story) sans jamais
recopier la vraie clé :

| AC | Attestation attendue | Statut |
|---|---|---|
| **AC7** — Révocation/restriction effective | Date + projet Cloud + moyen (révoquée / restreinte) | ⏳ En attente Owner |
| **AC8** — Preuve d'invalidité | Statut `REQUEST_DENIED` / clé invalide sur l'ancienne clé | ⏳ En attente Owner |
| **AC9** — Purge des dépôts externes | DODLP/DLCFTI ne portent plus la clé active | ⏳ En attente Owner |

> Tant que ces trois lignes ne sont pas attestées, E1-5 **ne peut pas** passer
> globalement à `done`, même si tout le groupe A (doc + découplage + gate vert) est
> vert sur disque.

---

## 6. Garanties by-design côté zcrud (groupe A — vérifiable sur disque)

zcrud garantit, **par conception et par gate automatisé**, qu'aucune clé ne réintroduit
le risque dans ses 14 packages :

- **Découplage `zcrud_geo`.** Le package est un **squelette** (`ZGeoApi` placeholder) ;
  son `pubspec.yaml` ne dépend que de `zcrud_core` — **aucun SDK Maps**, **aucune clé**.
  L'implémentation réelle du champ géo est **déférée en E11a-1** (« aucune clé API dans
  le package ; config plateforme ; dépend de E1-5 »).
- **Gate anti-secrets (`gate:secrets`).** `scripts/ci/gate_secret_scan.dart` scanne tout
  fichier texte pour les motifs `AIza…` (clé Google), `AKIA…` (AWS), PEM, token Slack et
  l'affectation `badCertificateCallback = (...) => true`. La prose Markdown est hors
  périmètre du **repli local** (elle cite légitimement ces motifs comme contre-exemples)
  mais reste **couverte par gitleaks en CI**. Preuve par fixture : `prove_gates.dart`.
  Invocation : `dart run melos run gate:secrets` (ou `melos run verify`).
- **Interdit TLS (AD-12).** `badCertificateCallback => true` est **banni** et **bloqué
  par le gate** (fixture `secrets/fixture-badCert-block`). Aucune occurrence réelle dans
  zcrud. Le retrait côté export applicatif est traité en **E11a-3**.

Preuve reproductible du découplage (zéro clé / zéro SDK Maps hors doc & fixtures) :

```bash
grep -rn "AIza" packages/                                   # → aucune occurrence
grep -rniE "google_maps|maps_flutter|mapbox" packages/      # → aucune occurrence
grep -n "zcrud_core" packages/zcrud_geo/pubspec.yaml        # → seule dépendance
dart run scripts/ci/gate_secret_scan.dart                   # → exit 0
```

---

## 7. Références

- `_bmad-output/planning-artifacts/architecture/architecture-zcrud-2026-07-09/architecture.md` — **AD-12**.
- `CLAUDE.md` → *Key Don'ts* : « Never de secret dans un package … ; never `badCertificateCallback => true` ».
- `scripts/ci/gate_secret_scan.dart` — motifs, périmètre M-2, auto-exclusions.
- `scripts/ci/prove_gates.dart` — preuve par fixture (clé factice par concaténation).
- `melos.yaml` → `gate:secrets`, `verify`.
- `packages/zcrud_geo/` — squelette `ZGeoApi` ; impl déférée E11a-1.
