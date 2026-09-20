/// Brojevi i množina na bosanskom — jedno mjesto za cijelu admin app.
///
/// Stoji uz `datum.dart`, iz istog razloga zbog kojeg taj fajl postoji: prije taska 30 su
/// imena mjeseci bila privatne statike u jednom ekranu, pa bi ih drugi ekran prepisao kod
/// sebe i od tog trenutka bi „juni" na jednom bio „jun" na drugom.
///
/// `terminaTekst` je istu putanju prošao u tasku 31: bio je privatan u
/// `dashboard_screen.dart`, pa je zatrebao i zaglavlju kolone u kalendaru. Uvoz
/// `features/dashboard` iz `features/calendar` bi značio da feature zavisi od susjednog
/// featurea — zajedničko ide u `core/`, ne bočno.
library;

/// `1 termin`, `2 termina`, `14 termina` — množina po zadnjoj cifri.
///
/// Izuzetak za 11–14 nije kozmetika: po samoj zadnjoj cifri bi „21 termin" bilo tačno, a
/// „11 termin" ne bi.
String terminaTekst(int broj) {
  final zadnjeDvije = broj % 100;
  if (zadnjeDvije >= 11 && zadnjeDvije <= 14) return '$broj termina';
  return broj % 10 == 1 ? '$broj termin' : '$broj termina';
}
