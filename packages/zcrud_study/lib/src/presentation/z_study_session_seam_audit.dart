/// **Filet d'audit** du montage d'un écran de session : ce que l'assemblage
/// attend, ce que l'application a posé, et ce que le socle fera à la place de
/// ce qui manque.
///
/// Le vocabulaire vit ici ; l'audit d'un montage réel est
/// `ZStudySessionHost.auditSeams`, à côté du porteur dont il lit les champs.
library;

import 'package:flutter/foundation.dart';

/// Identité de diagnostic d'un **seam** de session — une valeur par créneau
/// d'injection de l'écran, sous le nom exact du champ correspondant.
///
/// Un seam est un point d'injection qui apporte une **capacité** : un port, un
/// callback, un constructeur de rendu, un contrôleur, un descripteur de formes.
/// Les réglages de mise en page n'en sont pas : les oublier coûte une forme,
/// jamais une capacité.
///
/// Chaque valeur porte le [fallback] que l'assemblage applique en son absence :
/// un seam non posé ne fait jamais échouer l'écran, il le rend autrement — et
/// c'est précisément ce qui rend son oubli invisible sans audit.
enum ZStudySeam {
  /// Voie d'écriture SRS.
  reviewer('aucun runtime SRS : la session bascule en repli explicite'),

  /// Carte d'affichage.
  cardBuilder('carte de révision du socle'),

  /// Créneau de carte complet (carte, rang, face, révélation).
  cardSlotBuilder('créneau du socle : la révélation reste à l\'assemblage'),

  /// Rendu de contenu (markdown, LaTeX…).
  contentBuilder('contenu rendu tel quel, sans balisage interprété'),

  /// Pastille de type de question.
  questionTypeBadgeBuilder('aucune pastille de type dans l\'arbre'),

  /// Bandeau de consigne.
  instructionBanner('aucun bandeau de consigne dans l\'arbre'),

  /// Port d'évaluation de réponse.
  evaluationPort('aucune évaluation : la saisie retombe sur un cran neutre'),

  /// Port d'indices.
  hintPort('aucune action d\'indice dans l\'arbre'),

  /// Notation manuelle.
  onQualitySelected('aucune rangée de crans de notation dans l\'arbre'),

  /// Clé de couleur d'un cran de notation.
  qualityColorKeyFor('couleurs dérivées du seuil de réussite de la config'),

  /// Aperçu d'intervalle sous un cran.
  qualityPreviewLabelFor('aucun aperçu d\'intervalle sous les crans'),

  /// Aperçu d'intervalle recevant la carte affichée.
  qualityPreviewLabelForCard(
    'aucun aperçu par carte : l\'aperçu sans carte gouverne, à défaut aucun',
  ),

  /// Action « voir la source » de la carte de devant.
  onSource('aucune action « voir la source » dans l\'arbre'),

  /// En-tête de session.
  headerBuilder('aucun en-tête dans l\'arbre'),

  /// Compteurs de session.
  counterBuilder('aucun compteur dans l\'arbre'),

  /// Surface de saisie et de notation.
  gradingBuilder('surface de saisie du socle'),

  /// Résumé de fin de session.
  summaryBuilder('aucun résumé : la vue rend sa seule issue de sortie'),

  /// Repli « session vide ».
  emptyBuilder('repli « session vide » du socle'),

  /// Célébration de fin.
  celebrationBuilder('aucune célébration dans l\'arbre'),

  /// Libellés injectés.
  labels('libellés du socle, résolus par clé de traduction'),

  /// Notification de fin de session.
  onSessionEnd('la fin de session n\'est notifiée à personne'),

  /// Issue de sortie des replis.
  onExit('aucune issue de sortie dans les replis'),

  /// Pilote d'index de la pile.
  indexController('index de pile gouverné par l\'assemblage seul'),

  /// Formes de référence (en-tête, chrome de carte, progression).
  preset('aucune forme de référence : arbre du socle');

  const ZStudySeam(this.fallback);

  /// Ce que l'assemblage fait **à la place** du seam quand il n'est pas posé.
  ///
  /// Texte de diagnostic destiné à un développeur intégrateur — jamais un
  /// libellé affiché à un utilisateur, donc jamais traduit.
  final String fallback;
}

/// Verdict d'un audit de montage : qui est posé, qui est renoncé, qui manque.
///
/// Les trois ensembles sont **disjoints** et couvrent l'intégralité de
/// [ZStudySeam.values] : un seam est posé, ou renoncé, ou manquant.
/// [invalidWaivers] est transverse — il désigne des seams de [provided] dont
/// la renonciation déclarée ne décrit plus le montage.
@immutable
class ZStudySeamReport {
  /// Construit un verdict déjà partagé.
  const ZStudySeamReport({
    required this.provided,
    required this.waived,
    required this.missing,
    this.invalidWaivers = const <ZStudySeam>{},
  });

  /// Seams réellement posés par le montage.
  final Set<ZStudySeam> provided;

  /// Seams non posés, mais dont l'absence est une **décision déclarée**.
  final Set<ZStudySeam> waived;

  /// Seams non posés et non déclarés : le socle prendra son défaut, en
  /// silence.
  final Set<ZStudySeam> missing;

  /// Renonciations qui nomment un seam pourtant **posé**.
  ///
  /// Une exemption inutile n'est pas anodine : elle dit que le montage
  /// renonce à une capacité qu'il fournit. Le jour où le seam disparaîtra du
  /// montage, l'exemption absorbera la perte sans un mot — exactement le trou
  /// que l'audit ferme.
  final Set<ZStudySeam> invalidWaivers;

  /// `true` quand rien ne manque **et** qu'aucune renonciation ne ment.
  bool get isComplete => missing.isEmpty && invalidWaivers.isEmpty;

  List<ZStudySeam> _sorted(Set<ZStudySeam> set) =>
      ZStudySeam.values.where(set.contains).toList(growable: false);

  @override
  String toString() {
    final StringBuffer out = StringBuffer()
      ..write('ZStudySeamReport — montage de session ')
      ..write(isComplete ? 'COMPLET' : 'INCOMPLET')
      ..write(' : ${provided.length} posé(s), ${waived.length} renoncé(s), ')
      ..write('${missing.length} manquant(s).');
    if (missing.isNotEmpty) {
      out.write('\nSeams NON POSÉS et NON DÉCLARÉS — ce que le socle fait à '
          'leur place :');
      for (final ZStudySeam seam in _sorted(missing)) {
        out.write('\n  • ${seam.name} → ${seam.fallback}');
      }
    }
    if (invalidWaivers.isNotEmpty) {
      out.write('\nRenonciations INUTILES — le seam est pourtant posé :');
      for (final ZStudySeam seam in _sorted(invalidWaivers)) {
        out.write('\n  • ${seam.name}');
      }
    }
    if (waived.isNotEmpty) {
      out.write('\nRenonciations déclarées : '
          '${_sorted(waived).map((ZStudySeam s) => s.name).join(', ')}');
    }
    return out.toString();
  }
}

/// Politique d'audit du montage, posée à la construction de l'écran.
///
/// ## Trois régimes, tous DÉCLARÉS par l'application
///
/// | Montage | Ce qui vaut décision | Ce qui vaut oubli |
/// |---|---|---|
/// | énuméré (`ZStudySessionHost.wired`) | le `null` écrit dans le montage | rien : le compilateur exige déjà que chaque seam soit nommé |
/// | à plat **avec** une politique | les seams cités par [waived] | tous les autres seams non posés |
/// | à plat **sans** politique | — | — : aucun audit, aucun message, aucun coût |
///
/// Rien n'est deviné : une application qui ne veut pas d'indices n'en reçoit
/// jamais, parce que ne rien poser **est** la déclaration par défaut. Une
/// application qui pose une politique reçoit, en debug seulement, un rapport
/// unique nommant chaque seam qu'elle n'a ni posé ni cité.
///
/// La politique n'existe que sur le constructeur à plat : le constructeur
/// énuméré n'a rien à auditer, puisqu'il ne peut pas laisser un seam sans
/// réponse.
///
/// L'audit peut aussi se faire **hors rendu**, par
/// `ZStudySessionHost.auditSeams` : une fonction pure, appelable dans un test
/// unitaire sur le widget que l'application construit.
@immutable
class ZStudySeamAuditPolicy {
  /// Déclare l'audit, et les seams auxquels l'application renonce NOMMÉMENT.
  const ZStudySeamAuditPolicy({this.waived = const <ZStudySeam>{}});

  /// Seams dont l'absence est voulue : ils ne sont jamais signalés.
  ///
  /// Citer un seam **posé** est signalé à son tour
  /// ([ZStudySeamReport.invalidWaivers]) : la déclaration doit décrire le
  /// montage, dans les deux sens.
  final Set<ZStudySeam> waived;
}

/// Relaie un écart de montage **sans jamais faire tomber l'écran**.
///
/// L'écart part à `FlutterError.onError` — donc à la console et aux rapports
/// de plantage de l'application — et rien d'autre ne se produit : la session
/// s'affiche, avec les défauts du socle à la place des seams non posés
/// (invariant AD-10).
///
/// L'`exception` relayée **est** le [ZStudySeamReport] : un gestionnaire
/// d'erreurs d'application peut donc l'inspecter champ par champ, au lieu de
/// lire un texte.
void zStudyReportSeamGap({required ZStudySeamReport report}) {
  FlutterError.reportError(
    FlutterErrorDetails(
      exception: report,
      library: 'zcrud_study',
      context: ErrorDescription(
        'relevé par $kZStudySeamAuditSite à la construction de l\'écran de '
        'session. L\'écran reste affiché : chaque seam manquant a été remplacé '
        'par le défaut du socle (AD-10). Pour taire un seam dont l\'absence '
        'est voulue, le citer dans `ZStudySeamAuditPolicy.waived`.',
      ),
    ),
  );
}

/// Nom du site d'audit — identifiant de diagnostic, jamais un texte affiché.
const String kZStudySeamAuditSite = 'ZStudySessionHost.seamAudit';
