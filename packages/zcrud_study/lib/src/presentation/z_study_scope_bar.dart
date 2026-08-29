/// `ZStudyScopeBar` — la portée courante, en puces retirables.
///
/// ## Ce que la barre montre
///
/// Un `ZStudyScopeFilter` axe par axe : d'abord les portées
/// (`ZStudyScopeFilter.scopes`, dans leur ordre), puis les périodes, les
/// offres, les matières, les cours et les thèmes. Une puce par valeur, jamais
/// une agrégation : ce qui est affiché est exactement ce qui filtre.
///
/// Un filtre **vide ne monte rien** (`SizedBox.shrink`) — pas de rangée vide,
/// pas de hauteur réservée.
///
/// ## Ce que retirer une puce produit
///
/// [ZStudyScopeBar.onScopeChanged] reçoit le **filtre réduit exact** : le
/// filtre courant moins la seule valeur retirée, tous les autres axes
/// inchangés, `includeDescendants` inchangé. La barre ne détient aucun état :
/// elle rend un filtre, elle en propose un autre, et l'hôte décide.
///
/// ## Libellés
///
/// Une portée s'affiche par son instantané (`label`, puis `code`, puis
/// l'identifiant). Les axes par identifiant (période, offre, matière, cours,
/// thème) sont résolus contre [ZStudyScopeBar.snapshot] quand il les connaît —
/// une **lecture de valeur**, jamais un accès réseau. Sans instantané,
/// l'identifiant s'affiche : le socle n'invente pas de libellé.
///
/// Aucune couleur ni aucun libellé codés en dur (FR-26) ; cibles ≥ 48 dp et
/// placements directionnels (AD-13).
library;

import 'package:flutter/material.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart'
    show
        ZStudyRef,
        ZStudyScopeFilter,
        ZStudyStructureSnapshot,
        kZStudyRefTypeCourse,
        kZStudyRefTypeOffering,
        kZStudyRefTypePeriod,
        kZStudyRefTypeSubject,
        kZStudyRefTypeTopic;

/// Hauteur minimale d'une puce — cible tactile (AD-13).
const double zStudyScopeChipMinHeight = 48;

/// Barre de portée courante, en puces retirables.
class ZStudyScopeBar extends StatelessWidget {
  /// Construit une barre de portée.
  const ZStudyScopeBar({
    required this.filter,
    required this.onScopeChanged,
    this.snapshot = ZStudyStructureSnapshot.empty,
    this.labelBuilder,
    this.removeSemanticLabelBuilder,
    super.key,
  });

  /// Portée courante affichée. Vide ⇒ rien n'est monté.
  final ZStudyScopeFilter filter;

  /// Appelée avec le filtre **réduit exact** quand une puce est retirée.
  final ValueChanged<ZStudyScopeFilter> onScopeChanged;

  /// Instantané consulté pour les libellés des axes par identifiant.
  final ZStudyStructureSnapshot snapshot;

  /// Libellé d'une puce. `null` ⇒ `ZStudyRef.label`, puis `ZStudyRef.code`,
  /// puis l'identifiant.
  final String Function(ZStudyRef ref)? labelBuilder;

  /// Libellé d'accessibilité de l'action « retirer », par puce. `null` ⇒
  /// aucun libellé additionnel.
  final String Function(ZStudyRef ref)? removeSemanticLabelBuilder;

  String _label(ZStudyRef ref) =>
      labelBuilder?.call(ref) ?? ref.label ?? ref.code ?? ref.id;

  @override
  Widget build(BuildContext context) {
    if (filter.isEmpty) return const SizedBox.shrink();

    final List<Widget> chips = <Widget>[
      for (final ZStudyRef scope in filter.scopes)
        _chip(context, scope, () => _withoutScope(scope)),
      ..._idChips(
        context,
        kZStudyRefTypePeriod,
        filter.periodIds,
        (List<String> ids) => filter.copyWith(periodIds: ids),
      ),
      ..._idChips(
        context,
        kZStudyRefTypeOffering,
        filter.offeringIds,
        (List<String> ids) => filter.copyWith(offeringIds: ids),
      ),
      ..._idChips(
        context,
        kZStudyRefTypeSubject,
        filter.subjectIds,
        (List<String> ids) => filter.copyWith(subjectIds: ids),
      ),
      ..._idChips(
        context,
        kZStudyRefTypeCourse,
        filter.courseIds,
        (List<String> ids) => filter.copyWith(courseIds: ids),
      ),
      ..._idChips(
        context,
        kZStudyRefTypeTopic,
        filter.topicIds,
        (List<String> ids) => filter.copyWith(topicIds: ids),
      ),
    ];

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(12, 4, 12, 4),
      child: Wrap(spacing: 8, runSpacing: 4, children: chips),
    );
  }

  /// Retire [scope] des portées, par identité seule — l'instantané
  /// d'affichage n'entre pas dans la décision.
  ZStudyScopeFilter _withoutScope(ZStudyRef scope) => filter.copyWith(
    scopes: <ZStudyRef>[
      for (final ZStudyRef other in filter.scopes)
        if (!other.sameTarget(scope)) other,
    ],
  );

  List<Widget> _idChips(
    BuildContext context,
    String type,
    List<String> ids,
    ZStudyScopeFilter Function(List<String> remaining) rebuild,
  ) => <Widget>[
    for (final String id in ids)
      _chip(context, snapshot.refFor(type, id), () {
        // `remove` sur une copie : le filtre d'origine reste intact, et
        // seule la PREMIÈRE occurrence part — un axe ne porte pas de
        // doublon, et s'il en portait un, en retirer un seul est la
        // réduction exacte demandée.
        final List<String> remaining = List<String>.of(ids)..remove(id);
        return rebuild(remaining);
      }),
  ];

  Widget _chip(
    BuildContext context,
    ZStudyRef ref,
    ZStudyScopeFilter Function() reduced,
  ) {
    final String label = _label(ref);
    final String? removeLabel = removeSemanticLabelBuilder?.call(ref);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: zStudyScopeChipMinHeight),
      child: Center(
        widthFactor: 1,
        child: InputChip(
          key: ValueKey<String>('zStudyScopeBar.chip:${ref.type}:${ref.id}'),
          label: Text(label, textAlign: TextAlign.start),
          deleteIcon: const Icon(Icons.close),
          deleteButtonTooltipMessage: removeLabel,
          onDeleted: () => onScopeChanged(reduced()),
        ),
      ),
    );
  }
}
