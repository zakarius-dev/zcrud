/// `ZStudyProgressRings` — anneau de progression `correct / total`
/// (présentation pure via `CustomPaint`).
///
/// Consomme un DTO d'affichage pré-calculé [ZProgressRingsData] (fonction
/// pure [ZProgressRingsData.fromResult] sur `ZStudySessionResult`), puis un
/// [CustomPainter] pur le peint sans aucune logique métier (aucun accès
/// repo, aucun calcul SRS). `total == 0` donne un anneau vide (jamais de
/// division par zéro), `ratio` clampé à `[0, 1]`.
///
/// Widget pur (invariants AD-2/AD-15) : `StatelessWidget` + `CustomPaint`.
/// Couleurs (piste + progression) injectées via `ZColorKeyResolver` (repli
/// `Theme.of`), jamais de `Colors.*`. `Semantics` « correct/total » — la
/// couleur n'est jamais le seul canal d'information (invariant AD-13).
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:zcrud_core/zcrud_core.dart';
import 'package:zcrud_study_kernel/zcrud_study_kernel.dart';

/// DTO d'affichage PRÉ-CALCULÉ de l'anneau de progression (value-object PUR).
///
/// `ratio = total == 0 ? 0 : (correct / total)` **clampé** dans `[0, 1]`. Aucune
/// logique métier n'est laissée au painter.
@immutable
class ZProgressRingsData {
  /// Construit un DTO d'anneau. Préférer [ZProgressRingsData.fromResult] pour
  /// dériver le [ratio] défensivement depuis un résultat de session.
  const ZProgressRingsData({
    required this.total,
    required this.correct,
    required this.ratio,
  });

  /// Dérive le DTO d'un `ZStudySessionResult` (fonction pure).
  ///
  /// `total == 0` donne [ratio] `0` (pas de division par zéro). Sinon
  /// `correct / total` clampé dans `[0, 1]` (défensif : un corpus incohérent
  /// où `correct > total` ne dépasse jamais l'anneau plein).
  factory ZProgressRingsData.fromResult(ZStudySessionResult result) {
    final total = result.total;
    final correct = result.correct;
    final ratio = total == 0 ? 0.0 : (correct / total).clamp(0.0, 1.0);
    return ZProgressRingsData(
      total: total,
      correct: correct,
      ratio: ratio.toDouble(),
    );
  }

  /// Nombre total de cartes vues.
  final int total;

  /// Nombre de réponses correctes.
  final int correct;

  /// Fraction de progression **clampée** `[0, 1]` (`0` si `total == 0`).
  final double ratio;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ZProgressRingsData &&
          total == other.total &&
          correct == other.correct &&
          ratio == other.ratio;

  @override
  int get hashCode => Object.hash(total, correct, ratio);

  @override
  String toString() =>
      'ZProgressRingsData(total: $total, correct: $correct, ratio: $ratio)';
}

/// Anneau de progression `correct / total` (présentation PURE).
class ZStudyProgressRings extends StatelessWidget {
  /// Construit l'anneau depuis un DTO PRÉ-CALCULÉ.
  ///
  /// - [data] : DTO d'affichage (`ZProgressRingsData.fromResult(result)`) ;
  /// - [diameter] : diamètre en dp (défaut `96`, ≥ cible AD-13) ;
  /// - [strokeWidth] : épaisseur de l'anneau en dp ;
  /// - [trackColorKey]/[progressColorKey] : clés de couleur INJECTÉES (jamais un
  ///   `Color` en dur).
  const ZStudyProgressRings({
    required this.data,
    this.diameter = 96,
    this.strokeWidth = 10,
    this.trackColorKey = 'neutral',
    this.progressColorKey = 'primary',
    super.key,
  });

  /// DTO d'affichage pré-calculé.
  final ZProgressRingsData data;

  /// Diamètre de l'anneau (dp).
  final double diameter;

  /// Épaisseur de l'anneau (dp).
  final double strokeWidth;

  /// Clé de couleur de la **piste** (fond de l'anneau).
  final String trackColorKey;

  /// Clé de couleur de la **progression** (arc rempli).
  final String progressColorKey;

  @override
  Widget build(BuildContext context) {
    final trackPair =
        zResolveColorKeyOrSlot(context, trackColorKey, slotIndex: 4);
    final progressPair =
        zResolveColorKeyOrSlot(context, progressColorKey, slotIndex: 0);
    // « correct/total » en texte central : couleur jamais seul canal (AD-13),
    // et exposé au lecteur d'écran via `Semantics.value`.
    return Semantics(
      label: label(context, 'zcrud.srs.progress', fallback: 'progression'),
      value: '${data.correct}/${data.total}',
      child: SizedBox(
        width: diameter,
        height: diameter,
        child: CustomPaint(
          painter: _ProgressRingPainter(
            ratio: data.ratio,
            trackColor: trackPair.color,
            progressColor: progressPair.color,
            strokeWidth: strokeWidth,
          ),
          child: Center(
            child: Text(
              '${data.correct}/${data.total}',
              textAlign: TextAlign.center,
              style: TextStyle(color: progressPair.onColor),
            ),
          ),
        ),
      ),
    );
  }
}

/// Painter PUR de l'anneau (aucune logique métier : consomme [ratio] tel quel).
class _ProgressRingPainter extends CustomPainter {
  const _ProgressRingPainter({
    required this.ratio,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double ratio;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    if (radius <= 0) return;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (ratio <= 0) return;
    final progress = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = strokeWidth
      ..color = progressColor;
    // Arc de `ratio` du cercle, démarrant en haut (−π/2).
    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * ratio;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progress,
    );
  }

  @override
  bool shouldRepaint(_ProgressRingPainter oldDelegate) =>
      ratio != oldDelegate.ratio ||
      trackColor != oldDelegate.trackColor ||
      progressColor != oldDelegate.progressColor ||
      strokeWidth != oldDelegate.strokeWidth;
}
