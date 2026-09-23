/// Razmaci, uglovi i mjere admin ljuske — izmjereni iz `prototype/admin/canvas/`.
///
/// Postoji da ekran ne piše `EdgeInsets.all(17)` napamet. Kad se gustina mijenja, mijenja
/// se ovdje; literal u ekranu bi ostao i razišao se od ostalih.
///
/// **Ovo nisu klijentski tokeni.** `core_ui` `AppSpacing`/`AppRadius` opisuju drugi
/// proizvod i drugi handoff — tamo je radius 0 i gutter 22, ovdje 6 i 20.
library;

/// Skala razmaka. Canvas koristi i međuvrijednosti (9, 11, 13, 15, 17) unutar jedne
/// komponente; one su mjere te komponente, ne koraci skale, i ne ulaze ovdje.
abstract final class AdminSpacing {
  /// 4 — razmak unutar jednog reda (ikona uz labelu).
  static const double xs = 4;

  /// 8 — razmak između dugmadi u grupi, mreža kartica.
  static const double sm = 8;

  /// 12 — razmak između stavki liste.
  static const double md = 12;

  /// 16 — unutrašnji padding kartice.
  static const double lg = 16;

  /// 20 — **horizontalni gutter telefona.** `SPEC.md`, „Raspored i komponente".
  static const double xl = 20;

  /// 24 — horizontalni padding desktop radne površine i razmak između sekcija.
  static const double xxl = 24;

  /// 32 — razmak oko praznog stanja.
  static const double xxxl = 32;

  /// Gutter na telefonu (20). Isto što i [xl]; stoji i pod ovim imenom jer se u ekranu
  /// čita kao namjera, ne kao broj sa skale.
  static const double gutterMobile = 20;

  /// Gutter desktop radne površine (28).
  ///
  /// **Nije sa skale i nije 24**, kako je ovdje prvo stajalo. Canvas radnu površinu crta
  /// sa `padding:28px` u svih sedam desktop prikaza u opsegu, a top bar sa `padding:0 28px`
  /// (9 pojava); `padding:24px` i `padding:0 24px` se ne javljaju **nijednom**. 24 u
  /// handoffu postoji, ali kao razmak *između sekcija* ([xxl]), ne kao gutter.
  static const double gutterDesktop = 28;
}

/// Uglovi.
///
/// **Osnovni radius je 6, ne 0.** `SPEC.md` ga daje u tabeli, a canvas ga potvrđuje
/// mjerenjem: `border-radius:6px` se javlja 344 puta. Klijentska app ima radius 0 iz
/// `prototype/ui/`; to je drugi proizvod i prepisivanje navike iz `core_ui` je ovdje
/// greška koja se vidi na svakom uglu.
abstract final class AdminRadius {
  /// 6 — kartica, polje, dugme. Osnovna vrijednost sistema.
  static const double base = 6;

  /// 20 — statusna oznaka i brojač, koje canvas crta kao pilulu (`border-radius:20px`,
  /// 58 pojava). Nije proizvoljna varijanta: pilula razlikuje **oznaku stanja** od
  /// **dugmeta**, koje je uvijek [base].
  static const double pill = 20;

  /// 4 — sitni element: traka zauzetosti, ćelija datuma u mini kalendaru, progres
  /// traka. Izmjeren iz canvasa, ne izveden iz [base].
  ///
  /// Postoji zato što ćelija od 20 px sa radijusom 6 izgleda kao pilula — [base] je
  /// mjera kartice i dugmeta, a ne svega što ima ugao. Ispod 4 ide [dot].
  static const double small = 4;

  /// 3 — kvadratić uzorka boje u legendi (10×10 px). Jedina vrijednost ispod [small];
  /// na tom formatu i 4 već zaobli ugao u krug.
  static const double dot = 3;
}

/// Mjere ljuske i kontrola. Desktop vrijednosti troši shell iz taska 29; stoje ovdje da
/// ih ne bi prepisao kod sebe.
abstract final class AdminSize {
  /// 236 — širina desktop sidebara. `SPEC.md` kaže „približno 236 px", canvas ga crta
  /// tačno tako (`width:236px`, 9 pojava).
  static const double sidebarWidth = 236;

  /// 66 — visina desktop top bara. `SPEC.md` daje raspon 60–66; canvas bira gornju
  /// granicu (9 pojava naspram 4 za 64).
  static const double topBarHeight = 66;

  /// 44 — minimum svega što se tapa. Mobilni prikazi traže „velike touch mete".
  static const double touchTarget = 44;

  /// Visina dugmeta u kartici zahtjeva („Potvrdi" / „Odbij"). Handoff crta 36; FE-502
  /// ga diže na [touchTarget] — donja granica dodirne mete jača je od piksela iz izvoza.
  static const double buttonHeight = touchTarget;

  /// Visina dugmeta u top baru. Handoff crta 34; FE-502, isto kao [buttonHeight].
  static const double topBarButtonHeight = touchTarget;

  /// 1 — debljina hairline granice. Postoji kao token jer se pojavljuje u svakom obrubu,
  /// a `BorderSide` bez debljine tiho uzme Material default.
  static const double hairline = 1;
}

/// Trajanja. Admin je alatka za rad — prelaz koji se primijeti je predug.
abstract final class AdminDuration {
  /// 120 ms — pritisak, promjena stanja.
  static const Duration fast = Duration(milliseconds: 120);

  /// 200 ms — prelaz unutar ekrana.
  static const Duration normal = Duration(milliseconds: 200);
}
