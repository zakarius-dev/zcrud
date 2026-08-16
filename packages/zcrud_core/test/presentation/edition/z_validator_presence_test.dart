// Frontière **forme / présence** des validateurs déclaratifs.
//
// Un validateur de `ZValidatorSpec` décrit la FORME que doit avoir une valeur.
// La PRÉSENCE d'une valeur est portée par un seul validateur : `required`.
// Ces gardes fixent ce contrat famille par famille : sur une saisie vide, seul
// `required` refuse ; tous les autres laissent passer, et refusent toujours une
// saisie non conforme.
//
// Elles mordent : reposer `checkNullOrEmpty` à son défaut `true` sur n'importe
// laquelle des familles listées fait rougir l'assertion « le vide est accepté »
// de cette famille, et elle seule.
import 'package:flutter_test/flutter_test.dart';
import 'package:zcrud_core/zcrud_core.dart';

void main() {
  // Compile une seule spec et rend le validateur exécutable.
  String? Function(String?) v(ZValidatorSpec spec) {
    final compiled = ZValidatorCompiler.compile(<ZValidatorSpec>[spec]);
    expect(compiled, isNotNull, reason: 'famille ${spec.kind.name} compilée');
    return compiled!;
  }

  // Toutes les familles champ-locales qui décrivent une FORME, avec une saisie
  // que chacune refuse. Le vide doit passer partout ici.
  const shaped = <String, (ZValidatorSpec, String)>{
    'pattern': (ZValidatorSpec.pattern(r'^\+228[0-9]{8}$', errorText: 'ko'), 'abc'),
    'email': (ZValidatorSpec.email(errorText: 'ko'), 'pas-un-email'),
    'url': (ZValidatorSpec.url(errorText: 'ko'), 'pas une url'),
    'ip': (ZValidatorSpec.ip(errorText: 'ko'), '999.999.999.999'),
    'creditCard': (ZValidatorSpec.creditCard(errorText: 'ko'), '1234'),
    'phone': (ZValidatorSpec.phone(errorText: 'ko'), 'abc'),
    'numeric': (ZValidatorSpec.numeric(errorText: 'ko'), 'douze'),
    'integer': (ZValidatorSpec.integer(errorText: 'ko'), '12,5'),
    'dateString': (ZValidatorSpec.dateString(errorText: 'ko'), 'pas une date'),
    'minLength': (ZValidatorSpec.minLength(3, errorText: 'ko'), 'ab'),
    'maxLength': (ZValidatorSpec.maxLength(3, errorText: 'ko'), 'abcd'),
    'min': (ZValidatorSpec.min(5, errorText: 'ko'), '4'),
    'max': (ZValidatorSpec.max(5, errorText: 'ko'), '6'),
    'equal': (ZValidatorSpec.equal('oui', errorText: 'ko'), 'non'),
    'notEqual': (ZValidatorSpec.notEqual('non', errorText: 'ko'), 'non'),
    'address': (
      ZValidatorSpec.address(enforceFormat: true, errorText: 'ko'),
      '@@@',
    ),
    'percentage': (
      ZValidatorSpec.percentage(enforceRange: true, errorText: 'ko'),
      '150',
    ),
    'password': (ZValidatorSpec.password(errorText: 'ko'), 'a'),
  };

  group('Une forme ne porte jamais la présence', () {
    shaped.forEach((name, entry) {
      final (spec, invalide) = entry;
      test('$name : le vide est accepté, la saisie non conforme est refusée', () {
        final validate = v(spec);
        expect(
          validate(''),
          isNull,
          reason: '$name : une saisie vide ne doit pas être refusée par la forme',
        );
        expect(
          validate(null),
          isNull,
          reason: '$name : une saisie absente ne doit pas être refusée par la forme',
        );
        expect(
          validate(invalide),
          'ko',
          reason: '$name : la saisie « $invalide » ne respecte pas la forme',
        );
      });
    });
  });

  group('La présence est portée par `required`, et par lui seul', () {
    test('`required` refuse le vide et l\'absence', () {
      final validate = v(const ZValidatorSpec.required(errorText: 'manquant'));
      expect(validate(''), 'manquant');
      expect(validate(null), 'manquant');
      expect(validate('quelque chose'), isNull);
    });

    test('motif seul : facultatif, mais valide s\'il est rempli', () {
      final validate = v(
        const ZValidatorSpec.pattern(r'^\+228[0-9]{8}$', errorText: 'format'),
      );
      expect(validate(''), isNull);
      expect(validate('+22890123456'), isNull);
      expect(validate('90123456'), 'format');
    });

    test('motif + `required` : le vide redevient refusé', () {
      final validate = ZValidatorCompiler.compile(<ZValidatorSpec>[
        const ZValidatorSpec.required(errorText: 'manquant'),
        const ZValidatorSpec.pattern(r'^\+228[0-9]{8}$', errorText: 'format'),
      ]);
      expect(validate, isNotNull);
      expect(validate!(''), 'manquant');
      expect(validate(null), 'manquant');
      expect(validate('90123456'), 'format');
      expect(validate('+22890123456'), isNull);
    });

    test('e-mail seul : un contact facultatif reste soumissible à vide', () {
      final validate = v(const ZValidatorSpec.email(errorText: 'format'));
      expect(validate(''), isNull);
      expect(validate('awa@example.tg'), isNull);
      expect(validate('awa@'), 'format');
    });

    test('e-mail + `required` : le vide redevient refusé', () {
      final validate = ZValidatorCompiler.compile(<ZValidatorSpec>[
        const ZValidatorSpec.required(errorText: 'manquant'),
        const ZValidatorSpec.email(errorText: 'format'),
      ]);
      expect(validate, isNotNull);
      expect(validate!(''), 'manquant');
      expect(validate('awa@'), 'format');
      expect(validate('awa@example.tg'), isNull);
    });
  });

  group('Sur un formulaire réel, la même frontière', () {
    test(
      'un téléphone facultatif à motif ne bloque pas la soumission',
      () {
        const fields = <ZFieldSpec>[
          ZFieldSpec(
            name: 'email',
            type: EditionFieldType.text,
            validators: <ZValidatorSpec>[
              ZValidatorSpec.required(errorText: 'manquant'),
              ZValidatorSpec.email(errorText: 'format e-mail'),
            ],
          ),
          ZFieldSpec(
            name: 'telephone',
            type: EditionFieldType.text,
            validators: <ZValidatorSpec>[
              ZValidatorSpec.pattern(r'^\+228[0-9]{8}$', errorText: 'format tél.'),
            ],
          ),
        ];
        final controller = ZFormController(
          initialValues: <String, Object?>{
            'email': 'awa@example.tg',
            'telephone': '',
          },
        );
        addTearDown(controller.dispose);

        expect(
          zValidateFormFields(fields: fields, controller: controller),
          isEmpty,
          reason: 'téléphone vide : le motif ne rend pas le champ obligatoire',
        );

        controller.setValue('telephone', '90123456');
        expect(
          zValidateFormFields(fields: fields, controller: controller),
          <String, String>{'telephone': 'format tél.'},
          reason: 'téléphone rempli : le motif garde son verrou',
        );

        controller.setValue('telephone', '+22890123456');
        expect(
          zValidateFormFields(fields: fields, controller: controller),
          isEmpty,
        );
      },
    );
  });
}
