import 'package:core_domain/core_domain.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../errors/errors.dart';

/// Prijava osoblja i njegovo članstvo — **admin app, ne klijentska**.
///
/// ## Zašto zaseban repozitorij, a ne metoda na `AuthRepository`
///
/// `AuthRepository` je pisan za klijenta: Apple, Google, OTP bez lozinke, gost, brisanje
/// naloga. Nijedno od toga nije admin tok, i obrnuto — admin se prijavljuje **email-om i
/// lozinkom**, nalog mu pravi neko drugi, i ne može ga obrisati iz app-a (`salon_admin` je
/// namjerno isključen iz `delete_my_account`, v. `.claude/docs/security.md`). Dodavanje
/// `signInWithPassword` u klijentski ugovor bi svakom klijentskom ekranu ponudilo metodu
/// koju ne smije zvati.
///
/// ## Dva uslova, ne jedan
///
/// `private.is_admin()` traži **i** `app_metadata` claim u JWT-u **i** red u `public.users`
/// sa istim `salon_id`. Prvi dolazi sam sa prijavom; drugi se ovdje čita kroz [membership].
/// Korisnik koji ima token a nema red je prijavljen i ne vidi nijedan red — na ekranu
/// izgleda kao prazna baza, a zapravo je pogrešno postavljen nalog. Zato [signIn] vraća
/// [StaffMember], ne samo sesiju: ekran odmah zna ima li s čim raditi.
class StaffRepository {
  const StaffRepository(this._client, {this.beforeSignOut});

  final Future<void> Function()? beforeSignOut;

  final SupabaseClient _client;

  /// `*`, ne lista kolona: `membership()` je ulaz u cijeli admin. Build sa kolonama profila
  /// (task 61) protiv baze bez te migracije bi inače dobio `column does not exist` i niko se
  /// ne bi mogao prijaviti. Nepoznata kolona se ignoriše, a kolona koje nema daje default.
  static const _columns = '*';

  /// Prijava email-om i lozinkom.
  ///
  /// **Bez OTP-a.** Admin sjedi za pultom i prijavljuje se više puta dnevno; čekanje na mail
  /// pri svakoj prijavi je tok za klijenta koji se prijavi jednom u tri mjeseca, ne za
  /// osoblje.
  ///
  /// Vraća `null` kad prijava uspije ali korisnik **nije osoblje** — token je ispravan, reda
  /// u `public.users` nema. Ekran to mora razlikovati od pogrešne lozinke: pogrešna lozinka
  /// je greška korisnika, a ovo je greška u postavljanju naloga i traži drugu poruku.
  Future<StaffMember?> signIn({
    required String email,
    required String password,
  }) => guard(() async {
    await _client.auth.signInWithPassword(email: email, password: password);
    return _membership();
  });

  /// Članstvo trenutno prijavljenog korisnika, ili `null` ako nije osoblje.
  ///
  /// Ne prima `userId`: RLS nad `public.users` već propušta samo vlastiti red, pa je
  /// `.eq('id', ...)` u najboljem slučaju suvišan, a u najgorem sugeriše da je filter ono
  /// što štiti podatak. Štiti ga politika.
  Future<StaffMember?> membership() => guard(_membership);

  /// Sesija bez čekanja — admin router mora sinhrono znati smije li pustiti `/dashboard`.
  Session? get currentSession => _client.auth.currentSession;

  /// Stanje prijave kroz vrijeme; token ističe i osvježava se sam.
  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  Future<void> signOut() => guard(() async {
    await beforeSignOut?.call();
    await _client.auth.signOut();
  });

  // -------------------------------------------------------------------------
  // Moj profil (task 61). Sve ide kroz RPC: `users` nema `update` politiku, jer bi direktan
  // update pustio i ulogu, salon i vezu sa radnikom.

  /// Ime i telefon prijavljenog. Validaciju (dužina, znakovi telefona) drži baza.
  Future<void> updateProfile({required String name, required String phone}) =>
      guard(() async {
        await _client.rpc(
          'update_my_profile',
          params: {'p_name': name, 'p_phone': phone},
        );
      });

  /// Profilna slika — javni URL iz `MediaRepository.upload(kind: profil)`, ili `null` za
  /// uklanjanje. Uklanjanje vraća salonu njegovu sliku radnika i gasi prekidač.
  Future<void> setPhoto(String? url) => guard(() async {
    await _client.rpc('set_my_photo', params: {'p_url': url});
  });

  /// Koristi li salon profilnu sliku kao sliku povezanog radnika.
  Future<void> setUseProfilePhoto(bool use) => guard(() async {
    await _client.rpc('set_use_profile_photo', params: {'p_use': use});
  });

  /// Vlasnik bira kojem radniku iz Osoblja odgovara njegov nalog; `null` skida vezu.
  Future<void> linkEmployee(String? employeeId) => guard(() async {
    await _client.rpc(
      'link_my_employee',
      params: {'p_employee_id': employeeId},
    );
  });

  /// Provjera trenutne lozinke **ponovnom prijavom**, prije [changePassword].
  ///
  /// Otvorena sesija nije dokaz da za ekranom sjedi vlasnik naloga — admin ostaje prijavljen
  /// danima na zajedničkom računaru u salonu. Pogrešna lozinka baca [AuthRejectedError],
  /// isto kao na prijavi. Zaseban korak, da ekran zna **koja** lozinka nije prošla.
  Future<void> verifyPassword({
    required String email,
    required String password,
  }) => guard(() async {
    await _client.auth.signInWithPassword(email: email, password: password);
  });

  /// Nova lozinka. Datum promjene je samo prikaz, pa njegov neuspjeh ne obara promjenu koja
  /// je u GoTrue-u već prošla — inače bi korisnik vidio grešku za lozinku koja jeste
  /// promijenjena.
  Future<void> changePassword(String next) async {
    await guard(() => _client.auth.updateUser(UserAttributes(password: next)));
    try {
      await _client.rpc('mark_password_changed');
    } catch (_) {}
  }

  /// Odjavi sve **druge** sesije; ova ostaje.
  Future<void> signOutOtherDevices() => guard(() async {
    await _client.auth.signOut(scope: SignOutScope.others);
  });

  Future<StaffMember?> _membership() async {
    if (_client.auth.currentSession == null) return null;
    // `maybeSingle`, ne `single`: korisnik bez reda u `public.users` je **predviđeno**
    // stanje (klijent koji je pokušao u admin app), a `single` bi ga digao kao grešku.
    final red = await _client.from('users').select(_columns).maybeSingle();
    if (red == null) return null;
    return StaffMember(
      id: red['id'] as String,
      name: red['name'] as String,
      email: red['email'] as String,
      role: red['role'] as String,
      salonId: red['salon_id'] as String?,
      employeeId: red['employee_id'] as String?,
      phone: red['phone'] as String? ?? '',
      photoUrl: red['photo_url'] as String?,
      useProfilePhoto: red['use_profile_photo'] as bool? ?? false,
      // `tryParse`: polje je samo prikaz i ne smije moći srušiti prijavu.
      passwordChangedAt: switch (red['password_changed_at']) {
        final String v => DateTime.tryParse(v),
        _ => null,
      },
    );
  }
}
