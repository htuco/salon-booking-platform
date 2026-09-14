/// Član osoblja — vlasnik ili zaposlenik koji se prijavljuje u **admin** aplikaciju.
///
/// Ovo je red iz `public.users`, i on je **drugi od dva uslova** koje `private.is_admin()`
/// traži. Prvi je `app_metadata.role` u JWT-u. Oba moraju važiti i oba moraju pokazivati na
/// isti salon; token sam po sebi ne znači ništa (`.claude/docs/security.md`).
///
/// ## Zašto admin ne bira salon
///
/// Klijentska app zna svoj salon iz `SALON_ID` flavora. Admin app je **jedna, generička za
/// sve salone** — nema flavor, pa salon mora doći odnekud drugdje. Dolazi odavde, iz
/// članstva, a **nikad iz UI-ja ili iz headera**: `x-salon-id` bira kontekst čitanja i ne
/// daje prava ([ADR-0003](../../../../docs/adr/0003-x-salon-id-bira-kontekst-ne-daje-prava.md)).
///
/// Praktična posljedica koju treba znati: [salonId] je ono što admin ekran smije pokazati.
/// Ako ga nema, korisnik je prijavljen ali **nije osoblje nijednog salona** — v.
/// [StaffMember.isSalonAdmin].
class StaffMember {
  const StaffMember({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.salonId,
  });

  /// Isti `uuid` kao `auth.users.id` i kao `sub` u JWT-u — `public.users.id` je FK na
  /// `auth.users`, ne zaseban ključ.
  final String id;

  final String name;
  final String email;

  /// `public.staff_role`: `super_admin`, `salon_admin` ili `employee`.
  ///
  /// Namjerno `String`, ne enum: nepoznata uloga koju doda buduća migracija ne smije srušiti
  /// parsiranje reda. Ekran pita [isSalonAdmin], ne poredi string.
  final String role;

  /// `null` **samo** za `super_admin` — baza to drži `check` ograničenjem
  /// (`role = 'super_admin' and salon_id is null`, ili `role <> 'super_admin'` i salon
  /// obavezan). Za sve ostale je popunjen.
  final String? salonId;

  /// Upravlja tačno jednim salonom, pa admin app zna šta da pokaže.
  ///
  /// `super_admin` ovdje namjerno vraća `false`: on je iznad tenant izolacije i njegov ekran
  /// je super admin konzola iz Sprinta 3, ne ova lista termina. Bez ovog razdvajanja bi
  /// super admin ušao u admin app sa `salonId == null` i vidio prazan ekran koji izgleda
  /// kao greška.
  bool get isSalonAdmin => role == 'salon_admin' && salonId != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffMember &&
          other.id == id &&
          other.name == name &&
          other.email == email &&
          other.role == role &&
          other.salonId == salonId;

  @override
  int get hashCode => Object.hash(id, name, email, role, salonId);

  @override
  String toString() =>
      'StaffMember(id: $id, email: $email, role: $role, salonId: $salonId)';
}
