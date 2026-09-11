import 'booking_rules.dart';
import 'vertical_features.dart';
import 'vertical_terms.dart';

/// Vertikala — industrija kojoj salon pripada, sa svojom terminologijom, booking pravilima
/// i feature flagovima.
///
/// **Vertikala je red u bazi i config, nikad grana u kodu.** Ne postoji
/// `if (vertical.key == 'dental')` u ekranu — ako ekran treba drugačije da se ponaša, to je
/// flag u [features] ili string u [terms]. Obrazloženje: `docs/05-vertical-packs.md` §1.
class Vertical {
  const Vertical({
    required this.key,
    required this.displayName,
    required this.terms,
    required this.rules,
    required this.features,
    required this.defaultTheme,
  });

  /// Vertikala koja se koristi dok pravi podaci nisu stigli iz baze, i kad je red neispravan.
  ///
  /// Postoji da ekran nikad ne mora raditi sa `null`-om: `Vertical?` kroz cijelo stablo
  /// znači `?.` na svakom `Text`-u, a prvi zaboravljeni je prazan ekran u produkciji.
  static const Vertical fallback = Vertical(
    key: 'generic',
    displayName: 'Usluge',
    terms: VerticalTerms.fallback,
    rules: BookingRules.fallback,
    features: VerticalFeatures.fallback,
    defaultTheme: 'modern_barber',
  );

  /// `barber` · `beauty` · `dental` · `health` · `generic`, ili nepoznat ključ iz novije baze.
  ///
  /// Namjerno `String`, ne enum: `key` u bazi je pod check constraintom koji se širi
  /// migracijom, a app u storeu je uvijek starija od baze. Enum bi značio `CastError` na
  /// vertikali koja je dodana nakon zadnjeg store submissiona; ovako nepoznat ključ samo
  /// dobije generic ponašanje i ostane vidljiv u logu.
  final String key;

  /// "Barber" · "Beauty" · "Stomatologija" — za admin i onboarding, ne za klijentski ekran.
  final String displayName;

  final VerticalTerms terms;
  final BookingRules rules;
  final VerticalFeatures features;

  /// `modern_barber` · `elegant_beauty` · `clinical_calm`. Temu gradi `core_ui` (task 09);
  /// ovdje stoji samo ime, jer `core_domain` ne smije znati za Flutter.
  final String defaultTheme;

  /// Gradi vertikalu iz `vertical_packs` reda, uz opcioni `salons.terminology_override`.
  ///
  /// Override se sloji **preko** terminologije, ključ po ključ — v. [VerticalTerms.mergeOverride].
  factory Vertical.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? terminologyOverride,
  }) {
    Map<String, dynamic> readMap(String key) {
      final value = json[key];
      return value is Map<String, dynamic>
          ? value
          : value is Map
          ? value.cast<String, dynamic>()
          : const {};
    }

    final key = json['key'];
    final displayName = json['display_name'];
    final theme = json['default_theme'];

    return Vertical(
      key: key is String && key.isNotEmpty ? key : fallback.key,
      displayName: displayName is String && displayName.isNotEmpty
          ? displayName
          : fallback.displayName,
      terms: VerticalTerms.fromJson(readMap('terminology'))
          .mergeOverride(terminologyOverride),
      rules: BookingRules.fromJson(readMap('default_settings')),
      features: VerticalFeatures.fromJson(readMap('feature_flags')),
      defaultTheme: theme is String && theme.isNotEmpty
          ? theme
          : fallback.defaultTheme,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Vertical &&
          other.key == key &&
          other.displayName == displayName &&
          other.terms == terms &&
          other.rules == rules &&
          other.features == features &&
          other.defaultTheme == defaultTheme;

  @override
  int get hashCode =>
      Object.hash(key, displayName, terms, rules, features, defaultTheme);

  @override
  String toString() => 'Vertical($key)';
}
