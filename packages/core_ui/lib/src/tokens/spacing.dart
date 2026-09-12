/// Razmaci, radijusi i visine — iz `prototype/ui/SPEC.md` §Design Tokens.
///
/// Postoji da ekran ne piše `EdgeInsets.all(24)` napamet. Kad se gustina rasporeda
/// mijenja, mijenja se ovdje i mijenja se svuda; literal u ekranu bi ostao.
///
/// **Vrijednosti su oblik, ne boja.** Handoff je nacrtan nad jednim brendom, ali razmaci,
/// visine i uglovi su platformski i vrijede za svaki tenant — v. `prototype/ui/README.md`.
library;

/// Skala razmaka — ritam iz handoffa (14 / 18 / 20 / 22 / 26 / 34), plus dvije manje
/// vrijednosti za razmake unutar jednog reda.
///
/// Međuvrijednost znači da skala nije dobra, ne da je slučaj poseban.
abstract final class AppSpacing {
  /// 4 — razmak unutar jednog reda teksta (ikona uz labelu).
  static const double xs = 4;

  /// 8 — mreža fotografija (`SPEC.md`: grid gap 8px).
  static const double sm = 8;

  /// 12 — razmak između stavki liste i slotova (`SPEC.md`: 10–12px).
  static const double md = 12;

  /// 14 — unutrašnji padding reda sa slikom (service row, staff row).
  static const double rowPadding = 14;

  /// 18 — blok ritam, manji korak.
  static const double lg = 18;

  /// 22 — **gutter ekrana**. Isto što i [gutter]; stoji i pod ovim imenom jer je to
  /// najčešći horizontalni padding u sistemu.
  static const double xl = 22;

  /// 26 — razmak između sekcija.
  static const double xxl = 26;

  /// 34 — razmak oko praznog stanja i iznad primarnog CTA.
  static const double xxxl = 34;

  /// Horizontalni padding svakog ekrana. `SPEC.md`: "screen gutter 22px".
  static const double gutter = 22;
}

/// Uglovi.
///
/// **Sistem je uglat — radius je 0 svuda.** `SPEC.md` to kaže doslovno ("radius 0
/// everywhere; square corners are the system"), i to nije stilska sitnica nego nosivi dio
/// izgleda: dubina dolazi iz hairline granica, ne iz zaobljenja i sjenki.
///
/// Klasa postoji sa jednom vrijednošću namjerno. Da su ostale `sm`/`md`/`lg` sa nulom,
/// prva sljedeća komponenta bi "privremeno" vratila 8 i niko to ne bi primijetio dok se ne
/// pogleda uz handoff.
abstract final class AppRadius {
  /// 0 — jedina vrijednost u sistemu.
  static const double none = 0;
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

/// Visine i dodirne mete. `SPEC.md` §Recurring components.
abstract final class AppSize {
  /// 44 — apsolutni minimum visine bilo čega što se tapa, i strana ćelije kalendara.
  static const double touchTarget = 44;

  /// 48 — visina standardnog (sekundarnog) dugmeta.
  static const double buttonHeight = 48;

  /// 60 — primarni CTA, full-width (`SPEC.md`: 60–66px).
  static const double ctaHeight = 60;

  /// 58 — chip slobodnog termina (`SPEC.md`: 58–64px). Znatno viši od minimalne dodirne
  /// mete, jer se po mreži termina bira brzo i prstom u pokretu.
  static const double timeSlot = 58;

  /// 76 — strana kvadratne fotografije u redu usluge ili radnika.
  static const double rowPhoto = 76;

  /// 5 — visina jednog segmenta trake koraka (`SPEC.md`: 4 kolone, 5px, gap 5px).
  static const double stepBar = 5;
}
