/// Razmaci i radijusi — skala od 4, po `docs/02 §16`.
///
/// Postoji da ekran ne piše `EdgeInsets.all(24)` napamet. Kad se gustina rasporeda
/// mijenja, mijenja se ovdje i mijenja se svuda; literal u ekranu bi ostao.
library;

/// Skala razmaka. Svi razmaci u aplikaciji su jedan od ovih — međuvrijednost znači da
/// skala nije dobra, ne da je slučaj poseban.
abstract final class AppSpacing {
  /// 4 — razmak unutar jednog reda teksta (ikona uz labelu).
  static const double xs = 4;

  /// 8 — razmak između usko vezanih elemenata (naslov i podnaslov kartice).
  static const double sm = 8;

  /// 12 — unutrašnji padding kompaktnih elemenata (chip, badge).
  static const double md = 12;

  /// 16 — podrazumijevani padding kartice i razmak između stavki liste.
  static const double lg = 16;

  /// 24 — horizontalni padding ekrana i razmak između sekcija.
  static const double xl = 24;

  /// 32 — razmak oko praznog stanja i iznad primarnog CTA.
  static const double xxl = 32;
}

/// Radijusi. Tri vrijednosti namjerno: više njih se pretvori u nasumičan izbor po ekranu.
abstract final class AppRadius {
  /// 8 — chip, badge, polje za unos.
  static const double sm = 8;

  /// 12 — kartica, dugme.
  static const double md = 12;

  /// 20 — bottom sheet i hero površine.
  static const double lg = 20;

  /// Puno zaobljenje za pill oblike (`StatusBadge`).
  static const double pill = 999;
}

/// Trajanja animacija. `docs/02 §14`: **max 300 ms**.
///
/// Duža animacija na booking flowu se ne doživljava kao uglađenost nego kao spor app —
/// korisnik čeka slobodan termin, ne prelaz.
abstract final class AppDuration {
  /// 120 ms — pritisak dugmeta, promjena stanja chipa.
  static const Duration fast = Duration(milliseconds: 120);

  /// 200 ms — prelaz unutar ekrana, otvaranje sheeta.
  static const Duration normal = Duration(milliseconds: 200);

  /// 300 ms — gornja granica; skeleton puls i prelaz između koraka.
  static const Duration slow = Duration(milliseconds: 300);
}

/// Dodirne mete. `docs/02 §14`: minimum 44 px, 48 dp na Androidu; primarni CTA 52.
abstract final class AppSize {
  /// 44 — apsolutni minimum visine bilo čega što se tapa (slot chip).
  static const double touchTarget = 44;

  /// 48 — Android preporuka; visina standardnog dugmeta.
  static const double buttonHeight = 48;

  /// 52 — primarni CTA, full-width.
  static const double ctaHeight = 52;
}
