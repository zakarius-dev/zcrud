/// Configuration `ZSrsConfig` — constantes SRS **injectables** (Story E9-2, AC5).
///
/// origine: lex_core (module « Étude ») — variante IFFD canonique (canonique
/// §2.1, l.75) : les constantes de l'algorithme de répétition espacée sont
/// **paramétrées**, jamais codées en dur dans le calcul (`Sm2`). Permet à une
/// app d'ajuster la courbe, et à un scheduler alternatif (FSRS/Leitner —
/// FR-17) de réutiliser/redéfinir ces bornes sans forker les modèles.
///
/// **Pur-Dart, immuable, `const`** (AD-14) : aucun état, aucune I/O. **Pas de
/// codegen** — ce n'est pas une entité persistée mais un paramétrage
/// d'algorithme. Injectée dans [ZSm2Scheduler].
library;

/// Paramètres immuables de l'algorithme de répétition espacée (SuperMemo-2 par
/// défaut). Toutes les constantes de [ZSm2Scheduler] sont lues depuis une
/// instance de cette classe (AC5 : aucune constante SM-2 en dur dans l'algo).
class ZSrsConfig {
  /// Construit une configuration SRS avec les défauts canoniques (variante
  /// IFFD). Tout paramètre peut être surchargé pour ajuster la courbe.
  const ZSrsConfig({
    this.minEaseFactor = 1.3,
    this.maxEaseFactor = 2.5,
    this.defaultEaseFactor = kDefaultEaseFactor,
    this.defaultIntervalModifier = 1.0,
    this.overdueBonusFactor = 0.0,
    this.passThreshold = 3,
    this.minQuality = 0,
    this.maxQuality = 5,
  })  : assert(
          minQuality < maxQuality,
          'minQuality doit être STRICTEMENT inférieur à maxQuality : une échelle '
          'vide ou inversée ne peut porter aucun cran de notation. Reçu : '
          'minQuality=$minQuality, maxQuality=$maxQuality.',
        ),
        assert(
          minQuality < passThreshold && passThreshold <= maxQuality,
          'passThreshold doit vérifier minQuality < passThreshold <= maxQuality : '
          'un seuil hors de cet intervalle rendrait la réussite soit systématique '
          '(seuil <= min), soit inatteignable (seuil > max). Reçu : '
          'minQuality=$minQuality, passThreshold=$passThreshold, '
          'maxQuality=$maxQuality.',
        ),
        assert(
          maxQuality == 5,
          'maxQuality DOIT valoir 5 : SM-2 est intrinsèquement un algorithme '
          '0..5 (AD-46, « échelle canonique : 0..5 — SM-2 complet »). Sa '
          'formule de facteur de facilité est bâtie sur le sommet 5 — '
          '`EF + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02))` — et elle est GELÉE '
          'par le contrat `z_sm2_contract_test.dart`. Un sommet tronqué ne '
          'généralise donc PAS l\'algorithme : il fabrique une config que le '
          'moteur ne sait pas servir. Ex. maxQuality=4 ⇒ deltaEF(4) = 0.0000 au '
          'MEILLEUR score possible, et strictement négatif partout ailleurs : '
          'l\'easeFactor ne croîtrait JAMAIS, silencieusement (aucune '
          'exception, aucun test rouge) — les intervalles cesseraient de '
          's\'espacer pour un apprenant sans faute. Pour tronquer l\'échelle, '
          'n\'utilisez que minQuality (1 = « sans blackout »), qui est sûr. '
          'Reçu : maxQuality=$maxQuality.',
        ),
        assert(
          minQuality == 0 || minQuality == 1,
          'minQuality DOIT valoir 0 ou 1 : ce sont les deux seules bornes '
          'basses que SM-2 sait honorer (0 = échelle complète avec blackout '
          'total, 1 = échelle « sans blackout »). Toute autre borne basse '
          'décalerait l\'échelle sous la formule gelée `(5 - q)` et fausserait '
          'la courbe sans le signaler (AD-46). Reçu : minQuality=$minQuality.',
        );

  /// Valeur canonique du facteur de facilité par défaut (`2.5`), exposée en
  /// `static const` : sert de défaut d'instance ([defaultEaseFactor]) ET de
  /// **repli de désérialisation** (défaut de persistance) à `ZRepetitionInfo`
  /// — une constante utilisable dans un contexte `const` (annotation codegen).
  static const double kDefaultEaseFactor = 2.5;

  /// Plancher du facteur de facilité (`easeFactor`) — borne basse du clamp SM-2
  /// (défaut `1.3`, minimum historique SuperMemo-2).
  final double minEaseFactor;

  /// Plafond du facteur de facilité — borne haute du clamp (défaut `2.5`,
  /// variante IFFD canonique qui clampe les DEUX bornes, cf. AC4).
  final double maxEaseFactor;

  /// Facteur de facilité initial d'un état neuf (`initial`) — défaut `2.5`.
  final double defaultEaseFactor;

  /// Multiplicateur global appliqué au calcul d'intervalle
  /// (`interval * easeFactor * defaultIntervalModifier`) — défaut `1.0`.
  /// Une app le monte pour espacer davantage, le baisse pour resserrer.
  final double defaultIntervalModifier;

  /// Facteur de bonus pour une carte révisée **en retard** (échéance dépassée) —
  /// **défaut `0.0` = aucun bonus** (CR-LEX-37).
  ///
  /// Une carte révisée en retard a été mémorisée **plus longtemps** que son
  /// intervalle ne le prévoyait : le retard est une information de rétention,
  /// que `ZSm2Scheduler` crédite au prochain intervalle —
  /// `min(round(joursDeRetard * ce facteur), intervalleDeBase)`, le bornage
  /// étant anti-explosion (au pire, le retard **double** l'intervalle).
  ///
  /// ## ⚠️ Le défaut a changé de `0.5` à `0.0` — et c'est un NON-changement
  ///
  /// Ce champ était déclaré à `0.5` mais **jamais lu** : « inerte au MVP ».
  /// Le comportement RÉEL était donc `0.0`, et le `0.5` affiché décrivait une
  /// correction qui n'existait pas — un réglage inerte **oriente le travail à
  /// tort** (un hôte pouvait croire la correction active, ou tenter de la régler
  /// sans effet). Le câbler en gardant `0.5` aurait **modifié silencieusement**
  /// les intervalles de tous les consommateurs existants, sur des données de
  /// production. Le défaut décrit désormais ce qui se passe vraiment ; la
  /// correction s'**active explicitement**.
  ///
  /// `0.5` est la valeur de **parité** avec les moteurs SM-2 qui créditent le
  /// retard (variante IFFD/lex). Une app qui la veut la déclare.
  final double overdueBonusFactor;

  /// Seuil de **réussite** : `quality >= passThreshold` = révision réussie,
  /// sinon lapse (défaut `3`, échelle SuperMemo-2 `0..5`).
  final int passThreshold;

  /// Borne BASSE de l'échelle de qualité (défaut `0` — SuperMemo-2 complet,
  /// « blackout total »). Une app peut tronquer l'échelle par le bas :
  /// `1` = « sans blackout ». **Seules `0` et `1` sont admises** (assert) — les
  /// deux seules bornes basses que la formule SM-2 gelée sait honorer.
  ///
  /// **Source unique de vérité de l'échelle** (AD-46) : `ZQualityScale` la
  /// **dérive** via `ZQualityScale.fromConfig` — l'échelle n'est JAMAIS
  /// redéclarée ailleurs (une seconde source divergerait silencieusement).
  final int minQuality;

  /// Borne HAUTE de l'échelle de qualité — **épinglée à `5`** (assert).
  ///
  /// Champ **de lecture**, pas de réglage : SM-2 étant intrinsèquement un
  /// algorithme `0..5` (formule `(5 - q)`, gelée par `z_sm2_contract_test.dart`),
  /// un sommet tronqué produirait une config que le moteur ne sait pas servir
  /// (`maxQuality: 4` ⇒ `deltaEF(4) = 0.0` ⇒ ease jamais croissant, en silence).
  /// Il existe pour que [clampQuality] et `ZQualityScale.fromConfig` **lisent**
  /// le sommet au lieu de le recopier en dur (AD-46) — la garde est ici, une
  /// fois, plutôt que dispersée chez chaque consommateur.
  ///
  /// Cf. [minQuality] : bornes **possédées par le domaine** (AD-46). Pour
  /// tronquer l'échelle, n'utilisez que [minQuality].
  final int maxQuality;

  /// Seuil de **MAÎTRISE** — **dérivé** de la borne haute possédée par ce config
  /// (AD-46). `maxQuality - 1` ⇒ **q4-5** en échelle canonique. **JAMAIS** le
  /// littéral `4`.
  ///
  /// 🔴 **SOURCE UNIQUE — promue ICI par su-6 (D2), pas redéclarée.** su-5 avait
  /// dérivé ce seuil **une seule fois**, mais dans la **présentation**
  /// (`zcrud_session/lib/src/presentation/z_session_summary_view.dart`, `??
  /// scale.max - 1`) — soit en **AVAL** de `zcrud_flashcard`. Or les filtres
  /// FR-SU12 de su-6 vivent **ICI**, en **AMONT** : un package amont ne peut pas
  /// importer un aval (AD-1). Les trois issues étaient : (a) re-dériver `max - 1`
  /// chez les filtres — **REFUSÉ**, c'est exactement la seconde source que su-5
  /// interdit par écrit et que le HIGH de su-1 a déjà coûté ; (b) déplacer les
  /// filtres en présentation — **REFUSÉ**, FR-SU12 exige une fonction PURE de
  /// domaine ; (c) **promouvoir le seuil dans son propriétaire AD-46** — retenu.
  /// La dérivation **se déplace** vers le seul type qui possède l'échelle : le
  /// nombre de sources **reste 1**. su-5 le **CONSOMME** désormais.
  ///
  /// **Zéro impact sérialisation** : `ZSrsConfig` n'est **PAS** un `@ZcrudModel`
  /// et ceci est un **getter dérivé** : aucun champ, aucun paramètre de
  /// constructeur, aucun `toMap`, aucun round-trip touché.
  ///
  /// ⚠️ La preuve citée ici était `grep '@ZcrudModel' … → RC=1`. Elle est
  /// **auto-réfutante** : cette prose contient elle-même le motif, donc la
  /// commande rend **RC=0**. Le fond est vrai, la preuve ne se reproduisait pas
  /// — et un agent qui la rejoue conclut l'inverse. Les commandes
  /// **discriminantes** (vérifiées) sont ancrées hors prose :
  /// `grep -E "^\s*@ZcrudModel" …/z_srs_config.dart` → **RC=1** ;
  /// `grep -E "^part " …/z_srs_config.dart` → **RC=1** ; aucun
  /// `z_srs_config.g.dart` sur disque.
  ///
  /// 🔴 **La garde qui protège RÉELLEMENT ce seuil** — et rien d'autre : une
  /// garde citée mais aveugle est un **FANTÔME** (leçon su-5, mesurée). Deux
  /// gardes, chacune sur SON package (aucune ne peut lire l'autre : `_scannedSources`
  /// est relatif au package qui l'exécute) :
  /// - **ici, `zcrud_flashcard`** : `test/z_mastered_threshold_single_source_test.dart`
  ///   — rougit si `maxQuality - 1` ou un littéral de seuil réapparaît dans
  ///   `lib/**` **hors de CE fichier** (auto-énumérant : tout nouveau fichier est
  ///   né gardé) ;
  /// - **chez `zcrud_session`** : `test/z_quality_scale_single_source_test.dart`
  ///   — rougit sur un `masteredThreshold ?? <littéral>` **et** sur une
  ///   re-dérivation (`scale.max - 1` / `maxQuality - 1`) dans les 3 fichiers
  ///   qui dérivent l'échelle (dont `z_session_summary_view.dart`, **déjà
  ///   listé**). ⚠️ Le motif de re-dérivation n'y a été ajouté **qu'au
  ///   code-review su-6 (D1)** : cette garde **bénissait** jusque-là
  ///   `?? scale.max - 1` (elle le verrouillait VERT dans une contre-preuve),
  ///   c'est-à-dire qu'elle **exigeait** d'accepter la seconde source que le
  ///   point (a) ci-dessus déclare avoir REFUSÉE. Les deux gardes se
  ///   contredisaient en se déclarant « le même critère » — deux gardes qui se
  ///   neutralisent sont pires qu'aucune garde : elles rassurent.
  ///
  /// ⚠️ **Portées RÉELLES, sans complaisance** — elles diffèrent, et pas
  /// seulement par le package : ici le scan est **récursif et auto-énumérant**
  /// (tout nouveau fichier naît gardé) et recolle **par déclaration** (immunisé
  /// au wrap `dart format`) ; chez `zcrud_session` il porte sur une **liste
  /// FIGÉE** de 3 fichiers et scanne **ligne à ligne**. Les **motifs**, eux, sont
  /// désormais les mêmes des deux côtés (régex identiques).
  ///
  /// ⚠️ Pourquoi une garde **structurelle** est le SEUL filet : `maxQuality` étant
  /// épinglé à `5` par `assert`, écrire `4` au lieu de `maxQuality - 1` est
  /// **ISO-COMPORTEMENTAL** — toute la suite resterait **VERTE**, et le reviewer
  /// suivant lirait un dartdoc rassurant. Aucun test de comportement ne peut voir
  /// ça.
  int get masteredThreshold => maxQuality - 1;

  /// Ramène [quality] dans l'échelle `[minQuality, maxQuality]`.
  ///
  /// **Unique propriétaire du clamp** (AD-46) : aucun consommateur ne réécrit
  /// des bornes en dur — tous passent par ici. **Défensif** (AD-10) : une valeur
  /// hors bornes est **clampée**, JAMAIS rejetée par une exception (une note
  /// aberrante venue d'un port d'évaluation ne doit pas casser une session).
  int clampQuality(int quality) => quality.clamp(minQuality, maxQuality);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZSrsConfig &&
          minEaseFactor == other.minEaseFactor &&
          maxEaseFactor == other.maxEaseFactor &&
          defaultEaseFactor == other.defaultEaseFactor &&
          defaultIntervalModifier == other.defaultIntervalModifier &&
          overdueBonusFactor == other.overdueBonusFactor &&
          passThreshold == other.passThreshold &&
          minQuality == other.minQuality &&
          maxQuality == other.maxQuality;

  @override
  int get hashCode => Object.hash(
        minEaseFactor,
        maxEaseFactor,
        defaultEaseFactor,
        defaultIntervalModifier,
        overdueBonusFactor,
        passThreshold,
        minQuality,
        maxQuality,
      );
}
