/// Paleta admin aplikacije — **jedino mjesto sa heks vrijednostima u `apps/admin`**.
///
/// ## Zašto ovdje, a ne u `core_ui`
///
/// `core_ui` gradi temu iz **tenant** boja: `salons.primary_color` stiže iz baze i mijenja
/// se po salonu bez builda. Admin je obrnut slučaj — jedan build za sve salone, i njegova
/// plava je identitet Salon OS-a, ne boja klijenta. Da admin uvozi `buildAppTheme()`,
/// sidebar bi promijenio boju kad se prijavi drugi vlasnik. To prolazi analizu, prolazi
/// test, i vidi se tek kad dva salona otvore istu aplikaciju.
///
/// ## Odakle vrijednosti
///
/// Prvih deset je tabela „Osnovni tokeni" iz [`prototype/admin/SPEC.md`], prepisana znak
/// po znak. Ostale su **izmjerene iz** `prototype/admin/canvas/Salon OS Admin.dc.html` —
/// SPEC tabela ne nabraja svaku boju koju handoff crta, a ekran koji ih traži bi ih
/// inače prepisao kod sebe.
///
/// Kontrast svakog para koji se stvarno iscrtava mjeri `theme_contrast_test.dart`. Ovdje
/// se ništa ne računa u runtime-u, za razliku od `core_ui`: tamo je brand boja **ulaz**
/// koji vlasnik bira, ovdje je konstanta koju bira dizajn.
library;

import 'package:flutter/material.dart';

/// Boje admin aplikacije.
abstract final class AdminColors {
  // --- Tabela „Osnovni tokeni" iz `SPEC.md` ---

  /// `#14181B` — glavni tekst i podloga sidebara. Isti token nosi obje uloge jer je
  /// sidebar u handoffu doslovno „tekst boja kao ploha".
  static const Color ink = Color(0xFF14181B);

  /// `#F4F6F7` — radna pozadina iza kartica. Nije bijela: kartica se vidi kao kartica.
  static const Color ground = Color(0xFFF4F6F7);

  /// `#FFFFFF` — površina kartice.
  static const Color surface = Color(0xFFFFFFFF);

  /// `#3D6D9E` — primarni akcent. **Platformski, nije tenant boja.**
  static const Color accent = Color(0xFF3D6D9E);

  /// `#5980A6` — sekundarni akcent iz SPEC tabele.
  ///
  /// **Finalni canvas ga ne koristi nijednom** (`grep -oi '#5980a6'` → 0); ostao je iz
  /// ranije skice `Smjer C - Space Grotesk.dc.html`. Stoji ovdje jer ga SPEC nabraja, ali
  /// **samo kao obrub ili ispunu trake** — bijeli tekst na njemu mjeri 4,15:1 i pada AA,
  /// pa nije podloga za tekst. Ko ga uzme kao pozadinu dugmeta, oborit će
  /// `theme_contrast_test.dart`.
  static const Color accentSoft = Color(0xFF5980A6);

  /// `#D5DBDF` — obrub kartice i polja.
  static const Color border = Color(0xFFD5DBDF);

  /// `#E6EAEC` — separator između redova unutar iste kartice. Tanji potez od [border];
  /// ista boja za oboje pretvorila bi listu u mrežu.
  static const Color separator = Color(0xFFE6EAEC);

  /// `#5B656B` — sekundarni tekst **tijela** (13,5–15 px u canvasu).
  ///
  /// SPEC tabela daje dvije vrijednosti za „sekundarni tekst" i ne kaže koja je koja.
  /// Podjela je izmjerena, ne izabrana: canvas koristi `#5B656B` na većem tekstu
  /// (59 pojava na 14 px), a [textMuted] na sitnom. Uz to je `#5B656B` jedina od dvije
  /// koja prolazi AA i na [ground] i na [surface].
  static const Color textSecondary = Color(0xFF5B656B);

  /// `#6B757B` — sitna labela, mono eyebrow i caption (10,5–13 px).
  ///
  /// **Samo na [surface].** Na [ground] mjeri 4,35:1 i pada AA — zato `onSurfaceVariant`
  /// u temi nosi [textSecondary], a ne ovu boju.
  static const Color textMuted = Color(0xFF6B757B);

  /// `#9C432F` — destruktivna radnja i tekst greške.
  static const Color destructive = Color(0xFF9C432F);

  // --- Izmjereno iz canvasa; nema ih u SPEC tabeli ---

  /// `#27496B` — akcent kao **tekst** na [accentTint]. Sam [accent] na tom tintu je
  /// presvijetao; handoff za tekst uzima tamniju varijantu iste boje.
  static const Color accentInk = Color(0xFF27496B);

  /// `#EAF1F8` — tinta akcenta: istaknuta kartica, oznaka „na čekanju" u zaglavlju.
  static const Color accentTint = Color(0xFFEAF1F8);

  /// `#FAE9E5` — tinta destruktivnog: podloga upozorenja i oznake otkazanog termina.
  static const Color destructiveTint = Color(0xFFFAE9E5);

  /// `#1E2429` — izdignuti red u sidebaru (kartica salona iznad navigacije).
  static const Color sidebarRaised = Color(0xFF1E2429);

  /// `#232A2F` — podloga **aktivne stavke** navigacije u sidebaru.
  ///
  /// Nije isto što i [sidebarRaised], iako su susjedne nijanse: canvas `3b` crta karticu
  /// salona na `#1e2429`, a izabranu stavku na `#232a2f`, jedan korak svjetlije. Ko ih
  /// spoji u jedan token, dobije sidebar u kojem izabrana stavka izgleda kao još jedna
  /// kartica.
  static const Color sidebarSelected = Color(0xFF232A2F);

  /// `#242B30` — linija iznad podnožja sidebara (ime prijavljenog).
  static const Color sidebarDivider = Color(0xFF242B30);

  /// `#C7CED2` — kosa crta u breadcrumbu top bara (`Vitez / Danas`).
  static const Color breadcrumbSeparator = Color(0xFFC7CED2);

  /// `#98A2A9` — neaktivna stavka sidebara. 6,86:1 na [ink].
  static const Color sidebarText = Color(0xFF98A2A9);

  /// `#7D888F` — mono labela u sidebaru („VLASNIK", „6 LOKACIJA"). 4,92:1 na [ink].
  static const Color sidebarMuted = Color(0xFF7D888F);

  /// `#FFFFFF` — tekst na [accent] i na [ink]. Računa se u `core_ui`, ovdje je konstanta
  /// jer je podloga konstanta.
  static const Color onAccent = Color(0xFFFFFFFF);

  // --- Statusni parovi; tinta + tekst na njoj ---
  //
  // Stoje ovdje, a ne u `AdminStatusColors`, da bi **svi** heksovi admina bili u jednom
  // fajlu. `AdminStatusColors` ih samo slaže u parove i daje im ime po ulozi.

  /// `#E8F3EC` — podloga oznake „Potvrđeno". Canvas.
  static const Color positiveTint = Color(0xFFE8F3EC);

  /// `#2F6B47` — tekst na [positiveTint]. Canvas. 5,57:1.
  static const Color positiveInk = Color(0xFF2F6B47);

  /// `#FDF1DD` — podloga oznake „Na čekanju" i kartice zahtjeva. Canvas.
  static const Color waitingTint = Color(0xFFFDF1DD);

  /// `#8A5A12` — tekst na [waitingTint]. Canvas. 5,29:1.
  static const Color waitingInk = Color(0xFF8A5A12);

  /// `#EEF1F3` — neutralna tinta: završen termin, isključeno stanje, tabela u mirovanju.
  static const Color neutralTint = Color(0xFFEEF1F3);
}
