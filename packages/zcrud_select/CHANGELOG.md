# Changelog

All notable changes to `zcrud_select` are documented in this file.

## 0.2.1

Initial skeleton (fp-1-2, epic E-FORM-PARITY).

- Selection satellite substrate (AD-48): pubspec, barrel, `lib/src/{domain,data,presentation}` tree with documented placeholder, confinement guard.
- Depends only on `zcrud_core` among zcrud packages (AD-1, CORE OUT=0).
- Declares the private vendored `awesome_select` fork as a leaf dependency (ET-1, AD-49) — guarded as declared by exactly `zcrud_select`.
- No presenter/adapter yet: `ZSelectPresenter` lands in fp-4-1.
- Published under the MIT license.
