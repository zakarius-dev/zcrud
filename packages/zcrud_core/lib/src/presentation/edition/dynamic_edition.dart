/// `DynamicEdition` — formulaire d'édition de **référence** assemblant N champs à
/// partir d'un `ZFormController` (invariant AD-2).
///
/// Le montage garantit par conception qu'une frappe ne reconstruit QUE le
/// champ courant :
/// - le `build` du formulaire n'observe QUE des canaux **structurels**
///   (`controller.visibleFields` + l'état de repli local `_collapsed`) via un
///   `ListenableBuilder` — il n'écoute JAMAIS une tranche de valeur ; une frappe
///   (qui ne touche aucun de ces canaux) ne le ré-exécute donc pas ;
/// - les champs sont montés via **`ListView.builder`** (jamais
///   `ListView(children: [...])`) — chaque champ porte `key: ValueKey(name)`
///   (place stable → réutilisation d'`Element`/`State` au rebuild) ;
/// - **aucun** `setState` de niveau formulaire dans la voie de frappe.
///
/// Autour de ce cœur, sans jamais élargir la frontière de rebuild :
/// - **Champs conditionnels** (`ZFieldSpec.condition`) : un sélecteur de
///   visibilité **dérivé**, fondu dans le `State`, abonné UNIQUEMENT aux
///   **champs de garde** (union des `field` référencés par les conditions —
///   [zGuardFieldsOf]) recalcule l'ensemble visible en **ordre canonique** et
///   pilote `setVisibleFields` (no-op si inchangé). Une frappe sur un champ
///   **non-garde** ne déclenche AUCUN recalcul.
/// - **Sections repliables** ([ZEditionSection.collapsible]) : en-tête accessible
///   (`Semantics(button, expanded, label)`, cible ≥ 48 dp, `EdgeInsetsDirectional`)
///   ; l'état d'expansion vit dans le `State` (canal `_collapsed`), survit à un
///   rebuild structurel, et n'affecte PAS `visibleFields` (orthogonal) ; le
///   repli masque VISUELLEMENT les membres sans détruire leurs tranches.
/// - **Mode lecture** (`readOnly` global) : chaque champ est rendu via une spec
///   effective `spec.copyWith(readOnly: true)` (réutilise le respect de
///   `field.readOnly` déjà présent dans toutes les familles). `showIfNull:false`
///   masque en lecture les champs vides (sans effet hors mode lecture).
/// - **Grille responsive 12 colonnes** ([layout]) : chaque champ reçoit un
///   [ZResponsiveSpan] ; disposition via [ZResponsiveGrid] (reflow par
///   breakpoint, gouttières directionnelles).
///
/// **Contrat de reflet de valeur EXTERNE** : l'état DÉRIVÉ (visibilité/lecture/
/// showIfNull) relit `valueOf`/la tranche à CHAQUE calcul — il reflète donc
/// nativement toute écriture externe d'un champ de garde, sans buffer interne.
/// Le write-back des widgets à buffer d'édition (texte/signature/sous-liste)
/// passe par un re-amorçage clé-de-révision (`ValueKey(name + reseedRevision)`)
/// appliqué **hors focus**.
library;

import 'package:flutter/material.dart';

import '../../domain/edition/edition_field_type.dart';
import '../../domain/edition/z_condition_evaluator.dart';
import '../../domain/edition/z_field_spec.dart';
import '../../domain/edition/z_read_field_layout.dart';
import '../../domain/ports/z_acl.dart';
import '../l10n/z_localizations.dart';
import '../theme/z_theme.dart';
import '../z_form_controller.dart';
import '../zcrud_scope.dart';
import 'z_derivation_engine.dart';
import 'z_field_widget.dart';
import 'z_read_mode_scope.dart';
import 'z_responsive_grid.dart';
import 'z_section_collapse_store.dart';
import 'z_value_emptiness.dart';

/// **Référence d'aération inter-champ** (défaut : ~12 dp pour tous les hôtes).
///
/// C'est une **MÉTRIQUE**, pas une couleur : l'invariant FR-26 ne l'interdit
/// pas, mais la discipline « valeur de référence centralisée » s'applique —
/// elle vit ici, nommée, et **jamais** en littéral éparpillé dans les widgets.
///
/// Elle n'est **pas** dérivable de l'échelle d'espacement de `ZcrudTheme`
/// (`gapS = 4`, `gapM = 8`, `gapL = 16`) : `12` est un pas distinct, celui que
/// portent déjà `ZcrudTheme.formPadding` (`all(12)`) et `ZcrudTheme.inputRadius`
/// (`12`).
///
/// Priorité de résolution dans [DynamicEdition] :
/// `interFieldGap` (paramètre) **>** `ZcrudTheme.fieldGap` (jeton) **>** cette
/// référence.
///
/// Cette référence est appliquée **UNIFORMÉMENT entre deux champs
/// consécutifs**, sur les DEUX voies de rendu (plate ET groupée) — et non
/// seulement après certains types « blocs ». `12` uniforme couvre les cas
/// d'aération usuels, et **une seule** métrique suffit : la chaîne de
/// résolution reste à un nombre.
const double zFieldGapReference = 12;

/// **Espacement inter-champ type-dépendant** (fonction historique, non
/// appelée par [DynamicEdition]).
///
/// Certains types de champ « blocs » (multi-ligne, sous-liste, fichier,
/// signature…) bénéficient d'un espace après eux (≈ 12 dp) pour aérer la
/// densité, et rien après les champs compacts. Cette fonction **pure**
/// projette cette règle : elle retourne [base] pour les types « blocs », et
/// `0` sinon.
///
/// **[DynamicEdition] NE L'APPELLE PLUS.** Le contrat de cette fonction est
/// **inchangé** (mêmes entrées, mêmes sorties) ; elle demeure publique et
/// utilisable par un hôte qui veut reproduire cette table type-dépendante.
/// La politique d'aération du formulaire est passée à un **écart uniforme**
/// entre deux champs consécutifs (cf. [zFieldGapReference]) : superposer un
/// supplément type-dépendant à l'écart uniforme produirait un doublement de
/// l'espace après les types « blocs », ce qui n'est pas souhaité.
///
/// **Table effective avec `base: 12`** — l'espace n'est PAS uniforme :
/// | Types | Espace après |
/// |---|---|
/// | `multiline`, `subItems`, `dynamicItem`, `signature`, `file`, `image`, `document`, `markdown` | `base` (12) |
/// | tous les autres (`text`, `number`, `boolean`, `select`, `date`…) | `0` |
double zFieldGapAfter(EditionFieldType type, {double base = 0}) {
  if (base <= 0) return 0;
  switch (type) {
    case EditionFieldType.multiline:
    case EditionFieldType.subItems:
    case EditionFieldType.dynamicItem:
    case EditionFieldType.signature:
    case EditionFieldType.file:
    case EditionFieldType.image:
    case EditionFieldType.document:
    case EditionFieldType.markdown:
      return base;
    // ignore: no_default_cases
    default:
      return 0;
  }
}

/// Descripteur **présentation** d'une action de **niveau formulaire** (barre
/// d'actions en-tête de `DynamicEdition`).
///
/// Porte les métadonnées d'UI (`label`/`icon`/`tooltip`) + la permission requise
/// (`requiredPermission`, un [ZCrudAction] du port domaine — sens de dépendance
/// présentation → domaine) + le handler `onInvoke`. **Aucune règle métier** : le
/// gate se contente d'appeler `acl.can(requiredPermission, …)` (invariant
/// AD-16). Le filtrage est cohérent avec les actions de LIGNE (`ZRowAction`)
/// et la sous-liste compacte (mode `hide`).
@immutable
class ZFormAction {
  /// Construit une action de formulaire.
  ///
  /// [label]/[tooltip] sont des **clés l10n ou des littéraux** (résolus via
  /// `label(context, …)` — repli défensif sur la clé brute). À défaut, [tooltip]
  /// reprend [label].
  const ZFormAction({
    required this.id,
    required this.label,
    required this.requiredPermission,
    required this.onInvoke,
    this.icon,
    this.tooltip,
  });

  /// Identifiant stable (déterministe, pour les clés/tests).
  final String id;

  /// Libellé affiché (clé l10n ou littéral).
  final String label;

  /// Info-bulle (clé l10n ou littéral) ; à défaut, reprend [label].
  final String? tooltip;

  /// Icône optionnelle du bouton d'action.
  final IconData? icon;

  /// Permission requise, filtrée par `ZAcl` (invariant AD-16). L'action est
  /// **masquée** (mode `hide`) si `acl.can(requiredPermission, …)` est `false`.
  final ZCrudAction requiredPermission;

  /// Handler invoqué au tap (déjà lié par l'app ; le cœur ne l'interprète pas).
  final VoidCallback onInvoke;
}

/// Constructeur d'un widget de champ à partir de sa [ZFieldSpec] et du
/// [ZFormController]. Seam d'extension : à défaut, [DynamicEdition] rend le
/// dispatcher par type [ZFieldWidget]. La place stable
/// (`ValueKey(field.name)`) est garantie par [DynamicEdition] via `KeyedSubtree`
/// — un builder custom n'a donc PAS à la poser.
typedef ZEditionFieldBuilder = Widget Function(
  BuildContext context,
  ZFormController controller,
  ZFieldSpec field,
);

/// Style **déclaré** d'une [ZEditionSection] — un objet de style nommé, pour
/// l'en-tête (fond, filet supérieur, rayon, typographie, chevron) et pour le
/// corps (filet vertical côté début le long des champs).
///
/// Chaque propriété est **nullable** et `null` par défaut : une propriété non
/// déclarée conserve le rendu natif, à l'identique. Aucune couleur, aucun
/// glyphe n'est imposé par le socle — tout vient de cette déclaration ou du
/// thème ambiant.
///
/// Déclarer un style (même vide) rend la section en **bloc** (voie groupée du
/// formulaire) : les décorations et le filet n'existent que là. Les sections
/// sans style ni icône conservent leur voie de rendu d'origine.
@immutable
class ZEditionSectionStyle {
  /// Construit un style de section `const` — toutes propriétés optionnelles.
  const ZEditionSectionStyle({
    this.background,
    this.topAccent,
    this.radius,
    this.titleStyle,
    this.headerPadding,
    this.iconColor,
    this.collapsedIcon,
    this.expandedIcon,
    this.startRailColor,
    this.startRailWidth,
  });

  /// Fond de l'en-tête. `null` ⇒ aucun fond (rendu natif, posé à plat).
  final Color? background;

  /// **Filet supérieur** (couleur + épaisseur) posé au-dessus de l'en-tête.
  /// `null` ⇒ aucun filet.
  final BorderSide? topAccent;

  /// Rayon des coins de l'en-tête décoré. `null` ⇒ coins droits. Un
  /// `BorderRadiusDirectional` y est admis et suit le sens de lecture.
  final BorderRadiusGeometry? radius;

  /// Typographie du titre. `null` ⇒ `TextTheme.titleSmall` (rendu natif).
  final TextStyle? titleStyle;

  /// Marges **directionnelles** de l'en-tête. `null` ⇒ les marges natives.
  final EdgeInsetsDirectional? headerPadding;

  /// Couleur de l'icône de préfixe ([ZEditionSection.icon]). `null` ⇒ la
  /// couleur d'icône ambiante.
  final Color? iconColor;

  /// Glyphe du chevron d'une section repliable **repliée**. `null` ⇒ le
  /// chevron conventionnel (`Icons.expand_more`). Un `IconData` est un glyphe,
  /// jamais un libellé : il ne se traduit pas.
  final IconData? collapsedIcon;

  /// Glyphe du chevron d'une section repliable **dépliée**. `null` ⇒
  /// `Icons.expand_less`.
  final IconData? expandedIcon;

  /// Couleur du **filet vertical côté début** courant sur toute la hauteur des
  /// champs de la section (`BorderDirectional(start:)` — il bascule de côté en
  /// RTL, invariant AD-13). `null` ⇒ aucun filet.
  final Color? startRailColor;

  /// Épaisseur du filet côté début. `null` ⇒ `2` quand [startRailColor] est
  /// déclarée ; sans effet sinon.
  final double? startRailWidth;
}

/// Section **visuelle** d'un formulaire : un titre et l'ensemble des noms de
/// champs qu'elle regroupe. Peut être **repliable** ([collapsible]).
@immutable
class ZEditionSection {
  /// Construit une section de titre [title] regroupant les champs [fields].
  ///
  /// [collapsible] (défaut `false`) rend l'en-tête actionnable (accordéon) ;
  /// [initiallyExpanded] (défaut `true`) fixe l'état de repli initial. Une
  /// section non repliable ignore [initiallyExpanded].
  ///
  /// [icon] et [style] habillent l'en-tête et le corps — `null` (défaut) ⇒
  /// rendu natif strictement inchangé.
  const ZEditionSection({
    required this.title,
    required this.fields,
    this.collapsible = false,
    this.initiallyExpanded = true,
    this.icon,
    this.style,
  });

  /// Titre affiché de la section (clé l10n ou littéral — résolu côté hôte).
  final String title;

  /// Noms de champs appartenant à la section (ordre indicatif ; l'ordre effectif
  /// suit `visibleFields`).
  final List<String> fields;

  /// La section est-elle repliable (en-tête accordéon accessible) ?
  final bool collapsible;

  /// État de repli initial d'une section repliable (`true` = dépliée).
  final bool initiallyExpanded;

  /// **Icône de préfixe** de l'en-tête (glyphe rendu avant le titre). `null`
  /// (défaut) ⇒ aucune icône, en-tête natif inchangé. Sa couleur se déclare
  /// via [ZEditionSectionStyle.iconColor].
  final IconData? icon;

  /// **Style déclaré** de la section (voir [ZEditionSectionStyle]). `null`
  /// (défaut) ⇒ rendu natif inchangé. Déclaré — ou dès qu'une [icon] est
  /// déclarée — la section est rendue en bloc (voie groupée), où décorations
  /// et filet côté début sont applicables.
  final ZEditionSectionStyle? style;
}

/// Assemble un formulaire d'édition réactif **par tranche** depuis un
/// [controller] et la liste des [fields] connus, regroupés en [sections]
/// visuelles.
class DynamicEdition extends StatefulWidget {
  /// Construit le formulaire de référence.
  const DynamicEdition({
    required this.controller,
    required this.fields,
    this.sections = const <ZEditionSection>[],
    this.padding,
    this.shrinkWrap = false,
    this.physics,
    this.fieldBuilder,
    this.readOnly = false,
    this.readLayout,
    this.layout = const <String, ZResponsiveSpan>{},
    this.gridGutter = 8,
    this.gridRunGutter,
    this.conditionContext = const <String, Object?>{},
    this.manageVisibility = true,
    this.acl,
    this.formActions = const <ZFormAction>[],
    this.collectionId,
    this.collapseStore,
    this.formId,
    this.interFieldGap,
    this.onStructuralBuild,
    super.key,
  });

  /// Contrôleur détenant l'état (créé/possédé par l'hôte ; jamais recréé ici).
  final ZFormController controller;

  /// Catalogue des champs connus (source des [ZFieldSpec] par nom).
  final List<ZFieldSpec> fields;

  /// Sections visuelles (en-têtes ; repliables si `collapsible`). Vide = liste
  /// plate.
  final List<ZEditionSection> sections;

  /// Marge du `ListView` (héritée par l'hôte ; défaut : aucune).
  final EdgeInsetsGeometry? padding;

  /// `ListView.shrinkWrap` — pour imbrication dans un scroll parent.
  final bool shrinkWrap;

  /// `ListView.physics` — pour imbrication dans un scroll parent.
  final ScrollPhysics? physics;

  /// Seam de rendu de champ. À défaut : le dispatcher par type [ZFieldWidget].
  /// La place stable est garantie par [DynamicEdition] (KeyedSubtree).
  ///
  /// Le builder fourni **ne perd pas** le mode de consultation : celui-ci
  /// descend par le contexte ([ZReadModeScope]), pas par le paramètre du champ.
  final ZEditionFieldBuilder? fieldBuilder;

  /// **Mode lecture global** : quand `true`, le formulaire est une
  /// **consultation**.
  ///
  /// Trois effets, tous portés par ce seul drapeau :
  /// * chaque champ est rendu non éditable via une spec effective
  ///   `readOnly: true` (le per-champ reste respecté hors mode global) ;
  /// * le mode de **présentation** est posé pour tous les champs du sous-arbre
  ///   ([ZReadModeScope]) : les familles qui savent se présenter en **fiche**
  ///   (libellé au-dessus de la valeur, sans bordure ni libellé flottant ni
  ///   ornement) le font — y compris les champs montés par un `fieldBuilder`
  ///   fourni, par une fenêtre à étapes ou au fond d'une sous-liste ;
  /// * le filtre `showIfNull` est actif (un champ vide n'occupe pas la fiche).
  final bool readOnly;

  /// **Forme** des champs présentés en consultation, pour ce formulaire.
  ///
  /// `null` (défaut) ⇒ le jeton `ZcrudTheme.readLayout`, à défaut
  /// [ZReadFieldLayout.card]. Elle descend par le **même canal** que le mode de
  /// consultation ([ZReadModeScope]) : un `fieldBuilder` fourni, une fenêtre à
  /// étapes ou une sous-liste n'ont rien à recopier. Un champ garde le dernier
  /// mot (`ZFieldSpec.readLayout`).
  ///
  /// **Inerte hors consultation** : déclarée sur un formulaire de saisie, elle
  /// ne change rien tant que [readOnly] est `false`.
  final ZReadFieldLayout? readLayout;

  /// **Grille 12 colonnes** : span responsif par nom de champ. Vide = pas
  /// de grille (disposition en colonne pleine largeur — compat ascendante).
  final Map<String, ZResponsiveSpan> layout;

  /// Gouttière (dp) de la grille responsive (quand [layout] est non vide) —
  /// horizontale, et verticale par défaut si [gridRunGutter] est `null`.
  final double gridGutter;

  /// **Gouttière inter-rangées** (dp) de la grille responsive : relayée à
  /// `ZResponsiveGrid.runGutter`. **Additif non-cassant** : `null` (défaut)
  /// ⇒ repli sur [gridGutter] (comportement symétrique inchangé). Non `null`
  /// ⇒ aération verticale distincte (ex. `gridGutter: 16, gridRunGutter: 8`).
  /// Sans effet hors grille ([layout] vide).
  final double? gridRunGutter;

  /// **Contexte d'édition** : clés externes au formulaire lues par les
  /// feuilles `ZCondition` de source `ZValueSource.context` (`crud`/`mode`/
  /// drapeaux applicatifs). Défaut vide ⇒ **rétro-compat totale** (une condition
  /// `context` sur une clé absente résout `null`, défensif — invariant AD-10).
  ///
  /// Convention : `crud` en `String` camelCase (`'read'`/`'create'`/`'update'`/
  /// `'delete'`), `mode` en `String`, drapeaux en `bool`. Un changement de
  /// contenu déclenche **un** recalcul structurel de visibilité (via
  /// `didUpdateWidget`), **jamais** un abonnement par frappe : seules les clés
  /// de `zContextGuardKeysOf` sont surveillées.
  final Map<String, Object?> conditionContext;

  /// **Pilotage de `visibleFields`** (imbrication de steppers) : quand `true`
  /// (défaut, comportement **inchangé**), ce formulaire GÈRE
  /// `controller.visibleFields` (amorçage + souscription aux champs de garde +
  /// `setVisibleFields`). Quand `false`, il n'écrit JAMAIS `visibleFields` et ne
  /// s'abonne PAS aux gardes : il rend **passivement** l'intersection de
  /// `controller.visibleFields` avec ses `fields`. Sert le nesting de steppers où
  /// un **unique** propriétaire (le stepper RACINE) écrit la fenêtre = union du
  /// chemin actif (invariant AD-2, single-writer) ; les zones d'étape
  /// imbriquées ne se battent alors jamais sur `visibleFields`.
  final bool manageVisibility;

  /// **Port d'autorisation** filtrant les [formActions] de niveau formulaire.
  ///
  /// `null` (défaut) ⇒ l'ACL du `ZcrudScope` ambiant est consultée ; en
  /// l'absence de scope, le repli est **refusant** (`ZDenyAllAcl`) : aucune
  /// action de formulaire portant une permission n'est offerte. Déclarez votre
  /// ACL — au scope (`ZcrudScope(acl: MonAcl())`, valable pour tout le
  /// sous-arbre) ou ici pour ce seul formulaire. En développement, l'ouverture
  /// totale se déclare : `acl: const ZAllowAllAcl()`.
  ///
  /// Sans [formActions], ce port n'a aucun effet visible (aucune zone d'actions
  /// n'est rendue). **Aucune règle métier** dans le cœur : le gate se contente
  /// d'appeler `acl.can(…)` (invariant AD-16).
  final ZAcl? acl;

  /// **Actions de niveau formulaire** (barre d'actions en-tête). Chaque
  /// action est **masquée** (mode `hide`) si son `requiredPermission` n'est
  /// pas autorisé par [acl]. Défaut `const []` ⇒ **aucune zone d'actions
  /// rendue** (rétro-compat pixel). Le gate est évalué **uniquement** dans la
  /// voie de build **structurel** (jamais par frappe — invariant AD-2) : voir
  /// [build].
  final List<ZFormAction> formActions;

  /// Identifiant de collection éventuel, propagé **tel quel** à
  /// `acl.can(…, collectionId:)` (seam neutre, aucune règle métier —
  /// invariant AD-16).
  final String? collectionId;

  /// **Seam de persistance NEUTRE du repli des sections**. `null` (défaut) ⇒
  /// état de repli **en mémoire** uniquement (comportement historique
  /// inchangé). Non `null` ⇒ l'état de repli est (dé)chargé via ce port (impl
  /// stockage local déférée au binding/app — invariant AD-1). Voir
  /// [ZSectionCollapseStore].
  final ZSectionCollapseStore? collapseStore;

  /// Clé de portée passée telle quelle à [collapseStore] (`null` ⇒ portée
  /// globale). Sert à distinguer l'état de repli de plusieurs formulaires.
  final String? formId;

  /// **Espacement inter-champ.**
  ///
  /// L'aération est **UNIFORME et RÉELLE PARTOUT** :
  /// - elle s'applique entre **deux champs consécutifs**, quel que soit leur
  ///   type (plus de table type-dépendante — cf. [zFieldGapAfter]) ;
  /// - sur les **DEUX** voies de rendu : plate (`ListView.builder` sans section
  ///   repliable ni grille — le cas le plus courant) **et** groupée ;
  /// - le défaut n'est plus `0` mais [zFieldGapReference] (**12 dp**).
  ///
  /// Elle ne s'applique **PAS** :
  /// - en **grille** ([layout] non vide) — l'espacement y reste porté par
  ///   [gridGutter]/[gridRunGutter] ; rien ne s'y **additionne** ;
  /// - **avant/après un en-tête de section** — l'en-tête porte déjà ses propres
  ///   16 dp de tête et 8 dp de pied ; y ajouter l'écart doublerait l'air ;
  /// - **après le dernier champ** (aucun espace terminal parasite).
  ///
  /// C'est un comportement **visible pour tout hôte passif**. Un hôte qui
  /// compensait cette absence d'aération par ses propres `SizedBox`/`Padding`
  /// entre les champs doit **RETIRER** sa compensation, sinon les espaces
  /// s'additionnent.
  ///
  /// Chaîne de résolution : ce paramètre **>** `ZcrudTheme.fieldGap` (jeton de
  /// thème) **>** [zFieldGapReference].
  ///
  /// `null` (défaut) = « non fourni » ⇒ le jeton, puis la référence.
  /// **`0` explicite reste l'échappatoire** : il désactive toute aération, y
  /// compris face à un jeton de thème.
  final double? interFieldGap;

  /// Hook d'instrumentation : appelé à chaque (re)build **structurel** — compteur
  /// de build de niveau formulaire (reste inchangé pendant la saisie, invariant
  /// AD-2).
  @visibleForTesting
  final VoidCallback? onStructuralBuild;

  @override
  State<DynamicEdition> createState() => _DynamicEditionState();
}

class _DynamicEditionState extends State<DynamicEdition> {
  /// Index `name → spec` (identité de valeur, recalculé si [widget.fields] change).
  late Map<String, ZFieldSpec> _specByName;

  /// Index `name → titre de section` (pour l'interleave des en-têtes).
  late Map<String, String> _sectionByField;

  /// Champs de **garde** : union des `field` de source `state` référencés par
  /// les conditions. Le sélecteur de visibilité s'abonne UNIQUEMENT à ceux-ci
  /// (invariant AD-2) — les feuilles `persisted`/`context` en sont exclues
  /// (elles suivent leur propre voie de recalcul, ci-dessous).
  late Set<String> _guardFields;

  /// Clés de **contexte** référencées par les conditions (source `context`). Un
  /// changement de leur valeur dans `widget.conditionContext` déclenche **un**
  /// recalcul structurel (jamais un abonnement par frappe).
  late Set<String> _contextGuardKeys;

  /// `true` s'il existe AU MOINS une condition (toutes sources confondues). Gate
  /// du recalcul d'amorçage : sans condition on respecte l'ensemble visible fourni
  /// par l'hôte (compat ascendante), même si `_guardFields` est vide (cas d'une
  /// condition uniquement `context`/`persisted`).
  late bool _hasConditions;

  /// `true` s'il existe AU MOINS une feuille de source `persisted`. La
  /// baseline n'est pas immuable : `reseed`/`markPristine` la mutent (le
  /// `reset` la restaure). Quand c'est vrai, la visibilité doit être
  /// recalculée sur chaque `reseedRevision` (canal STRUCTUREL, jamais par
  /// frappe).
  late bool _hasPersistedGuard;

  /// Tranches réactives des champs de garde auxquelles [_onGuardChanged] est
  /// abonné (référence stable pour le retrait en `dispose`/`didUpdateWidget`).
  final List<Listenable> _guardListenables = <Listenable>[];

  /// `reseedRevision` du controller courant auquel [_onReseed] est abonné
  /// UNIQUEMENT si [_hasPersistedGuard] (référence stable pour le retrait).
  Listenable? _reseedListenable;

  /// Canal STRUCTUREL local : titres des sections **repliées**. Piloté par les
  /// en-têtes ; orthogonal à `controller.visibleFields`. Vit dans le
  /// `State` ⇒ survit aux rebuilds structurels ET au recyclage `ListView.builder`.
  late final ValueNotifier<Set<String>> _collapsed;

  /// Listenable fusionné observé par le `build` structurel : `visibleFields`
  /// (conditionnel) + `_collapsed` (repli). Aucune tranche de valeur.
  late Listenable _structural;

  /// **Moteur de dérivation** : exécute les `ZFieldSpec.derivedFrom`
  /// des [DynamicEdition.fields]. `null` si aucun champ n'en déclare (coût nul,
  /// comportement strictement inchangé). Possédé par cet État : (ré)attaché sur
  /// changement de controller/fields, **disposé** en `dispose` (aucun listener
  /// fuité).
  ZDerivationEngine? _derivations;

  /// `true` si le moteur courant porte au moins une cible `visible` (gate du
  /// recalcul structurel : sans elle, rien ne change au comportement de base).
  bool _hasDerivedVisibility = false;

  /// `true` si ce formulaire doit AMORCER `visibleFields` sur
  /// l'**ordre canonique du schéma** ([DynamicEdition.fields]).
  ///
  /// Le piège corrigé : `ZFormController` amorce `visibleFields` sur
  /// `initialValues.keys` quand l'hôte ne le fournit pas. Migrer en passant le
  /// `toMap()` d'un modèle faisait donc dépendre l'ENSEMBLE **et l'ORDRE** des
  /// champs affichés de l'ordre de la Map de persistance — sans aucune erreur :
  /// un champ du schéma absent de la Map n'était jamais rendu, et les champs
  /// rendus l'étaient dans un ordre arbitraire.
  ///
  /// Deux gardes, toutes deux nécessaires :
  /// - `!controller.hasExplicitVisibleFields` : un hôte qui a fourni
  ///   `visibleFields` reste **autoritaire** (ensemble ET ordre intacts) — c'est
  ///   aussi l'échappatoire documentée pour piloter la composition à la main ;
  /// - `fields.isNotEmpty` : un formulaire sans catalogue n'a **rien** de
  ///   canonique à dire ; il ne doit pas EFFACER l'ensemble visible d'un autre
  ///   écrivain (AD-10, repli plutôt qu'écrasement).
  ///
  /// Coût nul pendant la saisie : ce gate n'intervient QUE dans la voie
  /// structurelle (`initState` / changement de controller ou de schéma),
  /// jamais par frappe.
  bool get _shouldSeedCanonicalOrder =>
      widget.fields.isNotEmpty && !widget.controller.hasExplicitVisibleFields;

  @override
  void initState() {
    super.initState();
    _collapsed = ValueNotifier<Set<String>>(_initialCollapsed());
    _rebuildIndexes();
    _bindGuards();
    _bindReseed();
    _bindDerivations();
    _structural = Listenable.merge(<Listenable?>[
      widget.controller.visibleFields,
      _collapsed,
    ]);
    // Amorçage : calcule la visibilité initiale depuis les valeurs du controller,
    // la baseline (persisted) et le contexte. Trois déclencheurs — conditions,
    // visibilité dérivée, et absence de `visibleFields` explicite, auquel cas
    // le SCHÉMA fait foi. Un hôte qui a fourni `visibleFields` reste
    // autoritaire (compat ascendante stricte).
    if (widget.manageVisibility &&
        (_hasConditions || _hasDerivedVisibility || _shouldSeedCanonicalOrder)) {
      _recomputeVisibility();
    }
  }

  @override
  void didUpdateWidget(DynamicEdition oldWidget) {
    super.didUpdateWidget(oldWidget);
    final controllerChanged = oldWidget.controller != widget.controller;
    final fieldsChanged = !identical(oldWidget.fields, widget.fields);
    if (controllerChanged || fieldsChanged) {
      _rebuildIndexes();
      _bindGuards();
      _bindReseed();
      _bindDerivations();
      if (controllerChanged) {
        _structural = Listenable.merge(<Listenable?>[
          widget.controller.visibleFields,
          _collapsed,
        ]);
      }
      if (widget.manageVisibility &&
          (_hasConditions ||
              _hasDerivedVisibility ||
              _shouldSeedCanonicalOrder)) {
        _recomputeVisibility();
      }
      return;
    }
    // ── Bascule de rôle `manageVisibility` ───────────────────────────────
    // `manageVisibility` doit être COMPARÉ, pas seulement lu. Sur un
    // catalogue `const` (identité de `fields` stable) et un controller
    // inchangé, une bascule de rôle doit tout de même réabonner les canaux
    // concernés.
    //
    // Ce drapeau est **STRUCTUREL** au sens de la table de `ZStepperEdition` :
    // il décide si CETTE zone est un **écrivain** de `visibleFields` et quel jeu
    // de `Listenable` est abonné — ce n'est pas un canal visuel. Les deux
    // moitiés à couvrir :
    // - `true → false` : si les listeners de garde restaient abonnés,
    //   `_onGuardChanged`/`_onReseed` republieraient la fenêtre ⇒ **deux
    //   écrivains**, ce que l'invariant AD-2 (single-writer) interdit ;
    // - `false → true` : sans rebind, rien ne serait abonné ni recalculé ⇒
    //   zone qui se déclare pilote sans jamais piloter.
    //
    // Le rebind est **DISCRIMINANT**, pas un recalcul à l'aveugle : seuls les
    // deux canaux qui dépendent du rôle sont refaits.
    // - PAS `_rebuildIndexes()` : les index ne dépendent que de `fields` ;
    // - PAS `_bindDerivations()` : le `ZDerivationEngine` ne dépend que de
    //   `fields` ; il publie une révision et `_onDerivedVisibility` consulte
    //   `manageVisibility` **à l'appel** — le recréer détruirait/reconstruirait
    //   un moteur pour rien.
    if (oldWidget.manageVisibility != widget.manageVisibility) {
      _bindGuards();
      _bindReseed();
      if (widget.manageVisibility &&
          (_hasConditions ||
              _hasDerivedVisibility ||
              _shouldSeedCanonicalOrder)) {
        _recomputeVisibility();
      }
      // Le canal contexte ci-dessous est couvert : on vient soit de recalculer
      // sous le contexte COURANT, soit de devenir passif (rien à publier).
      return;
    }
    // Changement de CONTEXTE d'édition (crud/mode/drapeaux) hors changement
    // structurel de controller/fields : recalcul UNIQUE de la visibilité si
    // une clé de contexte réellement surveillée a changé de valeur. Jamais un
    // abonnement par frappe — le canal structurel `setVisibleFields` est no-op
    // si l'ensemble visible est inchangé.
    if (widget.manageVisibility &&
        _contextGuardKeys.isNotEmpty &&
        _contextChanged(oldWidget.conditionContext, widget.conditionContext)) {
      _recomputeVisibility();
    }
  }

  /// `true` si au moins une clé de [_contextGuardKeys] a changé de valeur entre
  /// [before] et [after] (comparaison de contenu, `null`-safe).
  bool _contextChanged(
    Map<String, Object?> before,
    Map<String, Object?> after,
  ) {
    if (identical(before, after)) return false;
    for (final k in _contextGuardKeys) {
      if (before[k] != after[k]) return true;
    }
    return false;
  }

  /// État de repli initial. Défauts = sections `collapsible` déclarées
  /// `initiallyExpanded: false`. Si un [DynamicEdition.collapseStore] est
  /// fourni, l'état **persisté** est autoritaire (restreint aux titres repliables
  /// courants) ; à défaut de persistance, les défauts sont **amorcés** dans le
  /// store. Défensif (invariant AD-10) : toute erreur du store ⇒ repli sur les
  /// défauts mémoire, jamais un crash.
  Set<String> _initialCollapsed() {
    final defaults = <String>{
      for (final s in widget.sections)
        if (s.collapsible && !s.initiallyExpanded) s.title,
    };
    final store = widget.collapseStore;
    if (store == null) return defaults;
    final collapsibleTitles = <String>{
      for (final s in widget.sections)
        if (s.collapsible) s.title,
    };
    try {
      final persisted = store.loadCollapsed(widget.formId);
      if (persisted.isEmpty) {
        // Aucune persistance encore : amorce le store avec les défauts.
        if (defaults.isNotEmpty) store.saveCollapsed(widget.formId, defaults);
        return defaults;
      }
      return persisted.intersection(collapsibleTitles);
    } catch (_) {
      return defaults;
    }
  }

  /// Persiste l'état de repli courant via le store (défensif — AD-10).
  void _persistCollapsed(Set<String> collapsed) {
    final store = widget.collapseStore;
    if (store == null) return;
    try {
      store.saveCollapsed(widget.formId, collapsed);
    } catch (_) {
      // Une impl de store fautive ne casse jamais le formulaire.
    }
  }

  void _rebuildIndexes() {
    _specByName = <String, ZFieldSpec>{
      for (final f in widget.fields) f.name: f,
    };
    _sectionByField = <String, String>{
      for (final s in widget.sections)
        for (final n in s.fields) n: s.title,
    };
    final conditions =
        widget.fields.map((f) => f.condition).toList(growable: false);
    _guardFields = zGuardFieldsOf(conditions);
    _contextGuardKeys = zContextGuardKeysOf(conditions);
    _hasPersistedGuard = zHasPersistedGuard(conditions);
    _hasConditions = widget.fields.any((f) => f.condition != null);
  }

  /// (Ré)abonne [_onGuardChanged] aux tranches des champs de garde UNIQUEMENT.
  ///
  /// En mode passif (`manageVisibility == false`, nesting de stepper) : aucun
  /// abonnement — la fenêtre est pilotée par le stepper RACINE (single-writer),
  /// ce formulaire ne recalcule ni n'écrit `visibleFields`.
  void _bindGuards() {
    for (final l in _guardListenables) {
      l.removeListener(_onGuardChanged);
    }
    _guardListenables.clear();
    if (!widget.manageVisibility) return;
    for (final g in _guardFields) {
      final l = widget.controller.fieldListenable(g);
      l.addListener(_onGuardChanged);
      _guardListenables.add(l);
    }
  }

  void _onGuardChanged() => _recomputeVisibility();

  /// (Ré)abonne [_onReseed] à `controller.reseedRevision` UNIQUEMENT si une
  /// feuille `persisted` existe. `reseed`/`markPristine` mutent la baseline
  /// lue par les conditions `persisted` sans changer les tranches d'état ni le
  /// contexte : sans cet abonnement, la visibilité resterait obsolète après un
  /// chargement asynchrone. Canal STRUCTUREL (par revision, jamais par frappe).
  void _bindReseed() {
    _reseedListenable?.removeListener(_onReseed);
    _reseedListenable = null;
    if (widget.manageVisibility && _hasPersistedGuard) {
      final l = widget.controller.reseedRevision;
      l.addListener(_onReseed);
      _reseedListenable = l;
    }
  }

  void _onReseed() => _recomputeVisibility();

  /// (Ré)attache le [ZDerivationEngine]. Détruit d'abord le moteur
  /// précédent (retrait EXHAUSTIF de ses listeners), n'en recrée un que si au
  /// moins un champ déclare `derivedFrom` — sinon `null` (coût nul).
  ///
  /// La cible `visible` se branche sur le canal STRUCTUREL **existant** : le
  /// moteur n'écrit jamais `visibleFields` lui-même, il publie une **révision**
  /// que ce formulaire observe pour rejouer [_recomputeVisibility] (single-writer
  /// de `visibleFields` préservé — invariant AD-2).
  void _bindDerivations() {
    _derivations?.visibilityRevision.removeListener(_onDerivedVisibility);
    _derivations?.dispose();
    _derivations = null;
    _hasDerivedVisibility = false;
    if (!widget.fields.any((f) => f.derivedFrom != null)) return;
    final engine = ZDerivationEngine(
      controller: widget.controller,
      fields: widget.fields,
    );
    _derivations = engine;
    _hasDerivedVisibility = engine.hasDerivedVisibility;
    if (_hasDerivedVisibility) {
      engine.visibilityRevision.addListener(_onDerivedVisibility);
    }
  }

  void _onDerivedVisibility() {
    if (widget.manageVisibility) _recomputeVisibility();
  }

  /// Recalcule l'ensemble visible = **ordre canonique** de [widget.fields] filtré
  /// par [evaluateZCondition], puis pilote `setVisibleFields` (no-op si
  /// inchangé). Préserve la PLACE ordinale (réinsertion à l'index canonique)
  /// et ne détruit JAMAIS de tranche (le controller conserve ses slices).
  void _recomputeVisibility() {
    final ctx = widget.conditionContext;
    // Composition en **ET** : `ZCondition` (déclaratif pur-données, voie par
    // défaut) ET `ZDerivation.visible` (échappatoire impérative). Un champ
    // sans dérivation `visible` n'est jamais masqué par le moteur.
    final derivations = _derivations;
    final next = <String>[
      for (final f in widget.fields)
        if ((f.condition == null ||
                evaluateZCondition(
                  f.condition!,
                  widget.controller.valueOf,
                  persistedValueOf: widget.controller.baselineValueOf,
                  contextValueOf: (k) => ctx[k],
                )) &&
            (derivations == null || derivations.isVisible(f.name)))
          f.name,
    ];
    widget.controller.setVisibleFields(next);
  }

  @override
  void dispose() {
    for (final l in _guardListenables) {
      l.removeListener(_onGuardChanged);
    }
    _guardListenables.clear();
    _reseedListenable?.removeListener(_onReseed);
    _reseedListenable = null;
    _derivations?.visibilityRevision.removeListener(_onDerivedVisibility);
    _derivations?.dispose();
    _derivations = null;
    _collapsed.dispose();
    super.dispose();
  }

  // ── Filtres de présentation (mode lecture) ────────────────────────────────

  /// `true` si une valeur compte comme **vide** pour `showIfNull` : `null` ou
  /// collection/chaîne vide. `false`/`0` NE sont PAS vides (valeurs affichables).
  ///
  /// Délégué à [zIsEmptyValue] — **règle UNIQUE** du dépôt, partagée avec la
  /// projection de validation (`zValidationText`). Deux copies divergentes de
  /// cette règle laisseraient `required` accepter une collection vide.
  static bool _isEmptyValue(Object? v) => zIsEmptyValue(v);

  /// En mode lecture, masque les champs vides dont `showIfNull == false`. Hors
  /// mode lecture : toujours affiché.
  bool _renderInReadMode(ZFieldSpec spec) {
    if (!widget.readOnly) return true;
    if (spec.showIfNull) return true;
    return !_isEmptyValue(widget.controller.valueOf(spec.name));
  }

  /// Spec **effective** : force `readOnly` en mode lecture global (réutilise le
  /// respect de `field.readOnly` par les familles — aucune réécriture).
  ZFieldSpec _effective(ZFieldSpec spec) =>
      widget.readOnly && !spec.readOnly ? spec.copyWith(readOnly: true) : spec;

  /// Padding **effectif** du `ListView` : le [DynamicEdition.padding] explicite
  /// prime ; sinon repli sur le token d'aération `ZcrudTheme.formPadding`
  /// (invariant FR-26 — jamais une constante littérale). Lu via
  /// `ZcrudTheme.of(context)` (scope → extension → repli dérivé du `Theme`).
  EdgeInsetsGeometry _resolvedPadding(BuildContext context) =>
      widget.padding ?? ZcrudTheme.of(context).formPadding;

  /// Base d'aération inter-champ effective :
  /// `interFieldGap` (paramètre, `0` compris) > `ZcrudTheme.fieldGap` (jeton) >
  /// [zFieldGapReference]. Même patron `paramètre ?? jeton ?? référence` que
  /// [_resolvedPadding] — d'où la nullabilité du paramètre.
  double _resolvedInterFieldGap(BuildContext context) =>
      widget.interFieldGap ??
      ZcrudTheme.of(context).fieldGap ??
      zFieldGapReference;

  // Une section STYLÉE (ou à icône) est rendue en bloc : ses décorations —
  // fond, filet supérieur, filet vertical côté début — n'ont de sens que sur
  // un bloc solidaire, pas sur des lignes interfoliées dans la voie plate.
  // Sans style ni icône déclarés, la voie de rendu est celle d'avant.
  bool get _grouped =>
      widget.layout.isNotEmpty ||
      widget.sections
          .any((s) => s.collapsible || s.style != null || s.icon != null);

  /// Actions de formulaire **autorisées**, dans l'ordre déclaré. Évalué
  /// UNIQUEMENT dans la voie structurelle (jamais par frappe). Défensif
  /// (invariant AD-10) : une ACL app-supplied qui **lève** ⇒ action masquée
  /// (fail-closed), jamais de crash du formulaire ; liste vide ⇒ `const []`.
  ///
  /// **La lecture seule VERROUILLE vraiment** : en mode
  /// [DynamicEdition.readOnly], les actions d'**écriture**
  /// (`ZCrudAction.mutatesData`) ne sont plus offertes du tout. Le filtre ACL
  /// seul ne suffirait pas : il laisserait passer « Supprimer », « Valider »,
  /// « Archiver »… sur un formulaire en lecture. Les actions de **lecture**
  /// (`view`, `history`) restent disponibles — la consultation n'est pas une
  /// écriture.
  List<ZFormAction> _permittedFormActions(BuildContext context) {
    final actions = widget.formActions;
    if (actions.isEmpty) return const <ZFormAction>[];
    // Priorité : paramètre du formulaire > ACL du scope ambiant > refus.
    final acl = widget.acl ??
        ZcrudScope.maybeOf(context)?.acl ??
        const ZDenyAllAcl();
    final readOnly = widget.readOnly;
    final result = <ZFormAction>[];
    for (final a in actions) {
      if (readOnly && a.requiredPermission.mutatesData) continue;
      if (_can(acl, a.requiredPermission)) result.add(a);
    }
    return result;
  }

  bool _can(ZAcl acl, ZCrudAction action) {
    try {
      return acl.can(action, collectionId: widget.collectionId);
    } catch (_) {
      // Défensif (AD-10) : une ACL app-supplied défaillante ne plante jamais le
      // formulaire — l'action est simplement non rendue.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Mode de présentation POSÉ pour tous les champs de ce formulaire, à
    // quelque profondeur qu'ils soient et quel que soit le builder qui les
    // monte (`fieldBuilder` fourni, étape d'une fenêtre à étapes, champ interne
    // d'une sous-liste). Posé dans les DEUX modes : un formulaire d'édition
    // imbriqué dans une fiche remplace bien le mode hérité.
    return ZReadModeScope(
      readMode: widget.readOnly,
      // Forme : celle qu'on déclare, à défaut celle de la surface qui nous
      // entoure. Sans ce repli, un formulaire imbriqué (une étape d'assistant,
      // un mini-CRUD) EFFACERAIT la forme de son hôte en reposant le scope avec
      // un `null` — alors qu'il n'a rien voulu dire de la forme.
      layout: widget.readLayout ?? ZReadModeScope.layoutOf(context),
      child: _buildSurface(context),
    );
  }

  Widget _buildSurface(BuildContext context) {
    // Canaux STRUCTURELS uniquement : ce builder ne se ré-exécute que lorsque
    // l'ensemble visible OU l'état de repli change (jamais sur une frappe). Le
    // gate ACL + la barre d'actions vivent DANS cette voie structurelle : une
    // frappe ne les recalcule pas (invariant AD-2).
    return ListenableBuilder(
      listenable: _structural,
      builder: (context, _) {
        widget.onStructuralBuild?.call();
        final visible = widget.controller.visibleFields.value;
        final list = _grouped ? _buildGrouped(visible) : _buildFlat(visible);

        // Rétro-compat pixel : sans action AUTORISÉE (défaut `formActions` vide,
        // ou toutes refusées par l'ACL), aucune zone d'actions n'est rendue.
        final actions = _permittedFormActions(context);
        if (actions.isEmpty) return list;

        // Barre d'actions en TÊTE + liste. En `shrinkWrap`, la liste garde sa
        // hauteur intrinsèque (pas d'`Expanded`) ; sinon elle occupe l'espace
        // restant (`Expanded`) — parent borné requis, cohérent avec l'usage
        // habituel de `DynamicEdition`.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: widget.shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
          children: <Widget>[
            _FormActionBar(actions: actions),
            if (widget.shrinkWrap) list else Expanded(child: list),
          ],
        );
      },
    );
  }

  // ── Rendu PLAT (pas de grille, pas de section repliable) ───────────────────

  Widget _buildFlat(List<String> visible) {
    final rows = <_EditionRow>[];
    String? currentSection;
    for (final name in visible) {
      final spec = _specByName[name];
      if (spec == null) continue;
      if (!_renderInReadMode(spec)) continue;
      final section = _sectionByField[name];
      if (section != null && section != currentSection) {
        rows.add(_EditionRow.header(section));
      }
      currentSection = section;
      rows.add(_EditionRow.field(_effective(spec)));
    }

    // Index inverse `Key → position` : permet au `ListView.builder` (sliver
    // paresseux) de RETROUVER l'`Element` d'un champ keyé qui a CHANGÉ d'index
    // (insertion/retrait d'un champ conditionnel voisin) et de PRÉSERVER son
    // `State`/focus. Sans lui, un champ décalé serait remonté à neuf
    // (focus perdu) — le simple `ValueKey` ne suffit pas dans un sliver lazy.
    final keyIndex = <Key, int>{};
    for (var i = 0; i < rows.length; i++) {
      final k = rows[i].key;
      if (k != null) keyIndex[k] = i;
    }

    // L'écart inter-champ est un **habillage du champ keyé**, jamais une
    // LIGNE d'espacement à part.
    //
    // Motif (non négociable) : `_buildFlat` monte un sliver PARESSEUX dont la
    // réconciliation d'`Element` repose sur `findChildIndexCallback` + le
    // `keyIndex` ci-dessus. Une ligne d'espacement séparée serait (a) NON KEYÉE —
    // donc réconciliée par POSITION, ce qui est précisément le mécanisme qui
    // détruit le `State`/focus d'un voisin quand un champ conditionnel
    // apparaît/disparaît — et (b) elle DOUBLERAIT `itemCount`, décalant tous les
    // index. En l'attachant DANS le `KeyedSubtree` du champ, `itemCount`,
    // l'indexation et la clé restent **exactement** ceux d'avant : le focus est
    // préservé par construction (invariant AD-2).
    //
    // L'écart suit un champ UNIQUEMENT si la ligne suivante est elle aussi un
    // champ : pas d'espace avant un en-tête de section (qui porte déjà 16 dp de
    // tête), ni après le dernier champ.
    final base = _resolvedInterFieldGap(context);

    return ListView.builder(
      padding: _resolvedPadding(context),
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: rows.length,
      findChildIndexCallback: (key) => keyIndex[key],
      itemBuilder: (context, i) {
        final hasGap = base > 0 &&
            rows[i].spec != null &&
            i + 1 < rows.length &&
            rows[i + 1].spec != null;
        return rows[i].build(context, this, gapAfter: hasGap ? base : 0);
      },
    );
  }

  // ── Rendu GROUPÉ (sections repliables et/ou grille responsive) ────────────

  Widget _buildGrouped(List<String> visible) {
    final visibleSet = visible.toSet();
    final blocks = <Widget>[];

    // Index inverse `Key → position` des BLOCS : comme le chemin plat, il permet
    // au `ListView.builder` (sliver paresseux) de RETROUVER l'`Element` d'un bloc
    // keyé qui a CHANGÉ d'index — bloc « loose » de tête qui apparaît/disparaît
    // ou section qui se vide et est sautée (`if (members.isEmpty) continue`) —
    // et de PRÉSERVER le `State`/focus des champs des blocs aval (invariant
    // AD-2). Chaque bloc est keyé sur une identité STABLE (`__loose__` / titre
    // de section).
    final blockKeyIndex = <Key, int>{};
    void addBlock(Key key, Widget child) {
      blockKeyIndex[key] = blocks.length;
      blocks.add(KeyedSubtree(key: key, child: child));
    }

    // (1) Champs sans section, dans l'ordre visible (bloc de tête sans en-tête).
    final loose = <ZFieldSpec>[
      for (final name in visible)
        if (_specByName[name] != null &&
            !_sectionByField.containsKey(name) &&
            _renderInReadMode(_specByName[name]!))
          _effective(_specByName[name]!),
    ];
    if (loose.isNotEmpty) {
      addBlock(const ValueKey<String>('block:__loose__'), _membersLayout(loose));
    }

    // (2) Sections dans leur ordre déclaré ; membres filtrés par visibilité +
    //     mode lecture. Une section repliée cache ses membres (slices intacts).
    for (final section in widget.sections) {
      final members = <ZFieldSpec>[
        for (final name in section.fields)
          if (visibleSet.contains(name) &&
              _specByName[name] != null &&
              _renderInReadMode(_specByName[name]!))
            _effective(_specByName[name]!),
      ];
      if (members.isEmpty) continue;

      final expanded =
          !(section.collapsible && _collapsed.value.contains(section.title));

      final header = section.collapsible
          ? _CollapsibleSectionHeader(
              key: ValueKey<String>('section:${section.title}'),
              title: section.title,
              expanded: expanded,
              icon: section.icon,
              style: section.style,
              onToggle: () => _toggleSection(section.title),
            )
          : _SectionHeader(
              key: ValueKey<String>('section:${section.title}'),
              title: section.title,
              icon: section.icon,
              style: section.style,
            );

      addBlock(
        ValueKey<String>('block:section:${section.title}'),
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            header,
            // Repli = masquage VISUEL sans destruction de slice (les membres ne
            // sont simplement pas montés ; le controller conserve leurs tranches).
            if (expanded) _sectionMembers(section, members),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: _resolvedPadding(context),
      shrinkWrap: widget.shrinkWrap,
      physics: widget.physics,
      itemCount: blocks.length,
      findChildIndexCallback: (key) => blockKeyIndex[key],
      itemBuilder: (context, i) => blocks[i],
    );
  }

  /// Dispose une liste de champs : en **grille 12 colonnes** si [widget.layout]
  /// est fourni, sinon en colonne pleine largeur. Chaque cellule est keyée
  /// `ValueKey(name)` (place stable NON contournable).
  Widget _membersLayout(List<ZFieldSpec> members) {
    if (widget.layout.isEmpty) {
      // Écart UNIFORME entre deux membres consécutifs (plus de table
      // type-dépendante — cf. `zFieldGapAfter`), jamais après le dernier ;
      // aucun espace si l'écart résolu est `0` (échappatoire ⇒ rétro-compat
      // pixel stricte). L'écart habille le champ KEYÉ (même motif qu'en voie
      // plate) : aucun `SizedBox` frère non keyé ne vient s'insérer dans la
      // `Column`, dont la réconciliation reste positionnelle.
      final base = _resolvedInterFieldGap(context);
      final children = <Widget>[
        for (var i = 0; i < members.length; i++)
          _buildField(
            context,
            members[i],
            gapAfter: i < members.length - 1 ? base : 0,
          ),
      ];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: children,
      );
    }
    // Grille : la place stable est portée par les CELLULES (enfants directs du
    // `Wrap`) via `keys`, PAS par un `KeyedSubtree` descendant — sinon `Wrap`
    // réconcilierait par position et un conditionnel inséré avant un champ
    // focalisé détruirait son `State` (focus/curseur perdus — invariant AD-2).
    // On fournit donc les enfants NON keyés à la racine (`_fieldChild`) + les
    // clés à part (place stable non contournable, tenue par `keys`).
    return ZResponsiveGrid(
      gutter: widget.gridGutter,
      // Gouttière inter-rangées distincte si fournie (repli sur `gutter` côté
      // `ZResponsiveGrid` quand `null` — additif non-cassant).
      runGutter: widget.gridRunGutter,
      spans: <ZResponsiveSpan>[
        for (final spec in members)
          widget.layout[spec.name] ?? const ZResponsiveSpan(),
      ],
      keys: <Key?>[
        for (final spec in members) ValueKey<String>(spec.name),
      ],
      children: <Widget>[
        for (final spec in members) _fieldChild(context, spec),
      ],
    );
  }

  /// Corps d'une section : ses membres, longés du **filet vertical côté
  /// début** quand la section le déclare ([ZEditionSectionStyle.startRailColor]
  /// — `BorderDirectional(start:)`, il bascule de côté en RTL, invariant
  /// AD-13). Aucun filet déclaré ⇒ le `_membersLayout` nu, à l'identique :
  /// aucun widget n'est ajouté à l'arbre d'un hôte passif.
  Widget _sectionMembers(ZEditionSection section, List<ZFieldSpec> members) {
    final body = _membersLayout(members);
    final rail = section.style?.startRailColor;
    if (rail == null) return body;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color: rail,
            width: section.style?.startRailWidth ?? 2,
          ),
        ),
      ),
      child: body,
    );
  }

  void _toggleSection(String title) {
    final next = Set<String>.of(_collapsed.value);
    if (!next.remove(title)) next.add(title);
    _collapsed.value = next; // notifie → rebuild STRUCTUREL (jamais une frappe).
    // Persiste l'état de repli (no-op si aucun store injecté).
    _persistCollapsed(next);
  }

  /// Sous-arbre RENDU d'un champ (dispatcher par type ou `fieldBuilder` custom),
  /// **sans** la place stable — celle-ci est posée par l'appelant (`KeyedSubtree`
  /// en colonne/plat, ou la clé de cellule `keys` en grille).
  Widget _fieldChild(BuildContext context, ZFieldSpec spec) {
    final builder = widget.fieldBuilder;
    return builder != null
        // Un builder fourni n'a RIEN à recopier : le mode de présentation est
        // posé dans le contexte (`ZReadModeScope`) et lu par le champ qu'il
        // monte. C'est ce qui empêche la consultation de se perdre au premier
        // builder de remplacement.
        ? builder(context, widget.controller, spec)
        // Le dispatcher par défaut reçoit le mode en clair — même valeur que
        // celle du contexte, mais explicite là où elle est décidée.
        // `_effective` conserve `readOnly:true` (repli sûr des familles non
        // fiche-ables).
        : ZFieldWidget(
            controller: widget.controller,
            field: spec,
            readMode: widget.readOnly,
          );
  }

  Widget _buildField(
    BuildContext context,
    ZFieldSpec spec, {
    double gapAfter = 0,
  }) {
    // L'écart inter-champ est porté par un `Padding` ENVELOPPANT (inset
    // **directionnel** — invariant AD-13), jamais par une LIGNE de liste ni un
    // frère `SizedBox` non keyé.
    //
    // Trois propriétés que cette forme garantit, et qu'aucune variante plus
    // simple ne tient toutes les trois :
    // 1. **Le `Padding` est TOUJOURS émis**, même à `0`. Un `Padding`
    //    conditionnel ferait changer la FORME du sous-arbre quand l'écart passe
    //    de 12 à 0 (dernier champ après le retrait d'un conditionnel voisin) →
    //    `Element` recréé → **focus perdu**. Ici seule la VALEUR de l'inset
    //    change : l'`Element` est réutilisé. À `0` le rendu est pixel-identique.
    // 2. **La clé de l'item de liste (`field:<name>`) est STABLE** et
    //    indépendante de l'écart : `findChildIndexCallback` retrouve donc
    //    l'`Element` d'un champ qui change d'index, exactement comme avant.
    // 3. **`ValueKey(<name>)` reste COLLÉE au champ** (sous le `Padding`) : la
    //    boîte trouvée par `find.byKey(ValueKey(name))` n'inclut PAS l'écart —
    //    la géométrie observable d'un champ est inchangée, et l'écart reste
    //    mesurable comme un vrai vide entre deux champs.
    //
    // Place stable NON contournable — même si un `fieldBuilder` custom omet
    // la clé, le champ reste keyé sur `spec.name` (préserve l'invariant AD-2 :
    // rebuild externe ⇒ Element/State réutilisés).
    return Padding(
      key: ValueKey<String>('field:${spec.name}'),
      padding: EdgeInsetsDirectional.only(bottom: gapAfter),
      child: KeyedSubtree(
        key: ValueKey<String>(spec.name),
        child: _fieldChild(context, spec),
      ),
    );
  }
}

/// Ligne du `ListView` PLAT : soit un **en-tête** de section, soit un **champ**.
@immutable
class _EditionRow {
  const _EditionRow.header(this.title) : spec = null;
  const _EditionRow.field(this.spec) : title = null;

  final String? title;
  final ZFieldSpec? spec;

  /// Clé du widget d'ITEM (celle posée à la RACINE par `_buildField` :
  /// `ValueKey('field:<name>')`) — `null` pour un en-tête (non keyé). Alimente
  /// `findChildIndexCallback`.
  ///
  /// Ce doit être la clé de la **racine** de l'item, pas celle du champ : la
  /// racine est le `Padding` d'aération et le champ est keyé un cran plus bas
  /// (`ValueKey(name)`). Renvoyer `ValueKey(name)` ici rendrait
  /// `findChildIndexCallback` **inerte** (aucune correspondance), et un champ
  /// décalé par un conditionnel voisin perdrait son `State`/focus.
  Key? get key {
    final s = spec;
    return s == null ? null : ValueKey<String>('field:${s.name}');
  }

  Widget build(
    BuildContext context,
    _DynamicEditionState parent, {
    double gapAfter = 0,
  }) {
    final header = title;
    if (header != null) return _SectionHeader(title: header);
    return parent._buildField(context, spec!, gapAfter: gapAfter);
  }
}

/// Chrome d'en-tête de section **déclaré** ([ZEditionSectionStyle]/icône) :
/// icône de préfixe, titre stylé, chevron éventuel [trailing], fond, filet
/// supérieur, rayon. N'est monté QUE quand une déclaration existe — les
/// en-têtes natifs ne passent jamais ici (garantie hôte passif). Aucune
/// couleur codée en dur (tout vient de la déclaration ou du thème — invariant
/// FR-26) ; insets et rayon **directionnels** (invariant AD-13).
Widget _sectionHeaderChrome(
  BuildContext context, {
  required String title,
  required IconData? icon,
  required ZEditionSectionStyle? style,
  Widget? trailing,
  bool tight = false,
}) {
  final padding = style?.headerPadding ??
      (tight
          ? const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8)
          : const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8));
  Widget out = Padding(
    padding: padding,
    child: Row(
      children: <Widget>[
        if (icon != null)
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: Icon(icon, color: style?.iconColor),
          ),
        Expanded(
          child: Text(
            title,
            style: style?.titleStyle ?? Theme.of(context).textTheme.titleSmall,
            textAlign: TextAlign.start,
          ),
        ),
        ?trailing,
      ],
    ),
  );
  final accent = style?.topAccent;
  if (accent != null) {
    out = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(height: accent.width, child: ColoredBox(color: accent.color)),
        out,
      ],
    );
  }
  final background = style?.background;
  final radius = style?.radius;
  if (background != null || radius != null) {
    out = DecoratedBox(
      decoration: BoxDecoration(color: background, borderRadius: radius),
      child: out,
    );
    // Le filet supérieur est un enfant rectangulaire : sans clip, il
    // déborderait des coins arrondis.
    if (radius != null && accent != null) {
      out = ClipRRect(borderRadius: radius, child: out);
    }
  }
  return out;
}

/// En-tête de section **visuel** (non repliable). Style dérivé du thème (aucune
/// couleur codée en dur — invariant FR-26) ; insets **directionnels** (invariant
/// AD-13). Une icône ou un style déclarés ([ZEditionSection.icon]/
/// [ZEditionSection.style]) passent par le chrome déclaré ; sans déclaration,
/// l'arbre rendu est strictement celui d'avant.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.icon, this.style, super.key});

  final String title;
  final IconData? icon;
  final ZEditionSectionStyle? style;

  @override
  Widget build(BuildContext context) {
    if (icon == null && style == null) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
        child: Text(
          title,
          style: Theme.of(context).textTheme.titleSmall,
        ),
      );
    }
    return _sectionHeaderChrome(context, title: title, icon: icon, style: style);
  }
}

/// En-tête de section **repliable** (accordéon accessible — invariant AD-13).
///
/// - `Semantics(button, expanded, label)` explicite ;
/// - **cible tactile ≥ 48 dp** (`minHeight`) ;
/// - insets **directionnels** (`EdgeInsetsDirectional`) et icône reflétant l'état
///   (aucune couleur codée en dur — thème).
///
/// L'état d'expansion est **détenu par le parent** ([_DynamicEditionState._collapsed])
/// : ce widget est sans état (rend [expanded], remonte [onToggle]). Un état
/// d'expansion porté par le `State` du parent **survit** non seulement au
/// rebuild structurel mais AUSSI au recyclage `ListView.builder` (un `State`
/// local d'en-tête serait perdu au défilement), tout en restant orthogonal à
/// `visibleFields`.
class _CollapsibleSectionHeader extends StatelessWidget {
  const _CollapsibleSectionHeader({
    required this.title,
    required this.expanded,
    required this.onToggle,
    this.icon,
    this.style,
    super.key,
  });

  final String title;
  final bool expanded;
  final VoidCallback onToggle;
  final IconData? icon;
  final ZEditionSectionStyle? style;

  @override
  Widget build(BuildContext context) {
    // Chevron : glyphes remplaçables par déclaration
    // ([ZEditionSectionStyle.collapsedIcon]/[ZEditionSectionStyle.expandedIcon]) ;
    // sans déclaration, les glyphes conventionnels — le widget rendu est
    // identique à celui d'avant.
    final chevron = Icon(
      expanded
          ? (style?.expandedIcon ?? Icons.expand_less)
          : (style?.collapsedIcon ?? Icons.expand_more),
    );
    final Widget inner;
    if (icon == null && style == null) {
      inner = Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            chevron,
          ],
        ),
      );
    } else {
      inner = _sectionHeaderChrome(
        context,
        title: title,
        icon: icon,
        style: style,
        trailing: chevron,
        tight: true,
      );
    }
    return Semantics(
      button: true,
      expanded: expanded,
      label: title,
      child: InkWell(
        onTap: onToggle,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: inner,
        ),
      ),
    );
  }
}

/// Barre d'actions de **niveau formulaire**. Rend les actions
/// **déjà filtrées** par l'ACL (mode `hide`). Insets **directionnels** ; couleurs
/// dérivées du thème (aucune couleur codée en dur — invariants FR-26/AD-13).
class _FormActionBar extends StatelessWidget {
  const _FormActionBar({required this.actions});

  final List<ZFormAction> actions;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(8, 8, 8, 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          for (final a in actions)
            _FormActionButton(
              key: ValueKey<String>('formAction:${a.id}'),
              action: a,
            ),
        ],
      ),
    );
  }
}

/// Bouton d'une action de formulaire : accessible (`Semantics(button)` + tooltip),
/// cible tactile **≥ 48 dp**, style dérivé du thème (AD-13, FR-26).
class _FormActionButton extends StatelessWidget {
  const _FormActionButton({required this.action, super.key});

  final ZFormAction action;

  @override
  Widget build(BuildContext context) {
    final labelText = label(context, action.label);
    final tip =
        action.tooltip == null ? labelText : label(context, action.tooltip!);
    final icon = action.icon;
    return Semantics(
      button: true,
      label: labelText,
      child: Tooltip(
        message: tip,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          child: icon == null
              ? TextButton(
                  onPressed: action.onInvoke,
                  child: Text(labelText),
                )
              : TextButton.icon(
                  onPressed: action.onInvoke,
                  icon: Icon(icon),
                  label: Text(labelText),
                ),
        ),
      ),
    );
  }
}
