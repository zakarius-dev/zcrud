/// `ZSubjectChip` — puce de **matière** d'un dossier d'étude.
///
/// La matière n'est pas une entité du socle : le noyau n'en garde qu'une
/// référence d'affichage (`ZStudySubjectRef` : identifiant opaque, libellé
/// et clé de couleur optionnels). Cette puce rend ce **snapshot** tel quel,
/// sans rien résoudre — c'est ce qui permet d'afficher la matière hors
/// ligne, ou avant qu'une résolution n'aboutisse.
///
/// La résolution est une capacité **optionnelle** (`resolver`) : quand elle
/// est fournie, la puce affiche d'abord le snapshot, puis se met à jour si la
/// résolution rend une référence enrichie. Un échec (`Left`) ne lève jamais
/// et ne vide jamais l'affichage : la puce reste au snapshot, ou reste
/// absente si le snapshot n'a pas de libellé.
library;

import 'package:flutter/material.dart';
import 'package:zcrud_core/domain.dart' show ZResult;
import 'package:zcrud_core/zcrud_core.dart'
    show ZColorPair, ZcrudTheme, zResolveColorKeyOrSlot;
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show ZColorPalette, ZStudySubjectRef, remapColorKey;

/// Résolveur de matière **INJECTÉ** : rend une référence enrichie pour un
/// identifiant opaque.
///
/// Le contrat est celui du dépôt : `Future<ZResult<…>>` — jamais une
/// exception attendue par l'appelant. Une implémentation qui lève quand même
/// est neutralisée par la puce (invariant AD-10).
typedef ZSubjectRefResolver =
    Future<ZResult<ZStudySubjectRef>> Function(String subjectId);

/// Diamètre de la pastille d'accent de la puce (dimension de LAYOUT).
const double kZSubjectChipPastilleSize = 10;

/// Puce de matière — snapshot d'abord, résolution ensuite (optionnelle).
///
/// ```dart
/// ZSubjectChip(ref: folder.subjectRef)                       // snapshot seul
/// ZSubjectChip(ref: ZStudySubjectRef(id: folder.subjectId),  // + résolution
///     resolver: (id) => subjectRepository.byId(id))
/// ```
///
/// - **AD-2** : aucun recalcul de contenu au rendu ; l'unique état détenu est
///   la référence résolue, mise à jour une seule fois par identifiant.
/// - **AD-4** : sans libellé disponible (ni snapshot, ni résolution), la puce
///   n'occupe **aucune** place visible ; `resolver` `null` ⇒ capacité absente,
///   aucun appel réseau.
/// - **AD-10** : un `Left`, une résolution qui lève, ou une réponse tardive
///   après démontage sont sans effet — jamais d'exception, jamais d'effacement
///   du snapshot.
/// - **AD-13/FR-26** : le libellé textuel est toujours le canal principal (la
///   pastille de couleur n'est qu'un rappel) ; chrome directionnel ; aucune
///   couleur ni libellé en dur.
class ZSubjectChip extends StatefulWidget {
  /// Construit la puce depuis une référence de matière.
  const ZSubjectChip({
    required this.ref,
    this.resolver,
    this.palette = const ZColorPalette.defaultStudy(),
    this.semanticLabel,
    super.key,
  });

  /// Référence de matière affichée — son [ZStudySubjectRef.label] est le
  /// snapshot rendu immédiatement, sans aucune résolution.
  final ZStudySubjectRef ref;

  /// Résolveur optionnel de l'identifiant. `null` ⇒ capacité **absente** :
  /// seul le snapshot est rendu, et rien n'est appelé.
  final ZSubjectRefResolver? resolver;

  /// Palette **INJECTÉE** bornant la clé de couleur de la puce.
  final ZColorPalette palette;

  /// Annonce sémantique. `null` ⇒ le libellé effectif est annoncé tel quel.
  final String? semanticLabel;

  /// Clé du fond de la puce (testabilité).
  static const ValueKey<String> chipKey = ValueKey<String>('zSubjectChip_bg');

  /// Clé du libellé de la puce (testabilité — AD-13).
  static const ValueKey<String> labelKey = ValueKey<String>(
    'zSubjectChip_label',
  );

  @override
  State<ZSubjectChip> createState() => _ZSubjectChipState();
}

class _ZSubjectChipState extends State<ZSubjectChip> {
  /// Référence effectivement affichée : le snapshot, remplacé seulement par
  /// une résolution RÉUSSIE.
  late ZStudySubjectRef _effective = widget.ref;

  @override
  void initState() {
    super.initState();
    _maybeResolve();
  }

  @override
  void didUpdateWidget(covariant ZSubjectChip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Le snapshot fait autorité dès qu'il change : la référence résolue d'un
    // AUTRE identifiant ne doit jamais survivre à un changement de dossier.
    if (oldWidget.ref != widget.ref) {
      _effective = widget.ref;
    }
    if (oldWidget.ref.id != widget.ref.id ||
        oldWidget.resolver != widget.resolver) {
      _maybeResolve();
    }
  }

  Future<void> _maybeResolve() async {
    final ZSubjectRefResolver? resolver = widget.resolver;
    final String id = widget.ref.id;
    // Capacité absente, ou identifiant vide : rien à résoudre.
    if (resolver == null || id.isEmpty) return;

    // Identifiant capturé AVANT l'attente : une réponse tardive concernant un
    // autre dossier ne doit jamais s'appliquer.
    ZResult<ZStudySubjectRef> result;
    try {
      result = await resolver(id);
    } catch (_) {
      // Un résolveur qui lève est un défaut de l'hôte ; il ne casse pas le
      // rendu (AD-10). Le snapshot reste affiché.
      return;
    }
    if (!mounted || widget.ref.id != id) return;

    result.fold(
      // `Left` : aucune mise à jour — le snapshot fait foi.
      (_) {},
      (resolved) {
        if (resolved == _effective) return;
        setState(() => _effective = resolved);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? text = _effective.label;
    // Aucun libellé disponible ⇒ rien de visible (AD-4). La puce n'invente
    // jamais un libellé à partir de l'identifiant opaque : ce serait afficher
    // une clé technique à l'utilisateur.
    if (text == null || text.isEmpty) return const SizedBox.shrink();

    final ZcrudTheme theme = ZcrudTheme.of(context);
    final String key = remapColorKey(
      palette: widget.palette,
      rawColorKey: _effective.colorKey,
      seedTitle: text,
    );
    final ZColorPair pair = zResolveColorKeyOrSlot(
      context,
      key,
      slotIndex: widget.palette.indexOf(key),
    );

    return Semantics(
      label: widget.semanticLabel ?? text,
      child: ExcludeSemantics(
        child: DecoratedBox(
          key: ZSubjectChip.chipKey,
          decoration: BoxDecoration(
            color: pair.color,
            borderRadius: BorderRadius.all(theme.radiusM),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: theme.gapM,
              vertical: theme.gapS,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                SizedBox(
                  width: kZSubjectChipPastilleSize,
                  height: kZSubjectChipPastilleSize,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: pair.onColor,
                    ),
                  ),
                ),
                SizedBox(width: theme.gapS),
                // Le TEXTE porte l'information ; la pastille n'en est qu'un
                // rappel (couleur jamais seul canal).
                Flexible(
                  child: Text(
                    text,
                    key: ZSubjectChip.labelKey,
                    textAlign: TextAlign.start,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        (Theme.of(context).textTheme.labelSmall ??
                                const TextStyle())
                            .copyWith(color: pair.onColor),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
