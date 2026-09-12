/// Prijavljeni korisnik, onako kako ga app vidi — **bez ijednog Supabase tipa**.
///
/// Supabaseov `User` nosi `appMetadata`, `userMetadata`, `identities` i još desetak polja
/// koja ekran nikad ne gleda, a svako od njih je vez za konkretan backend. `AuthRepository`
/// zato vraća ovaj tip: kad se ispod zamijeni implementacija (vlastiti .NET backend sa
/// svojim JWT-om, `docs/06 §6.3`), mijenja se repozitorij, ne aplikacija.
///
/// Ovo **nije** `AuthIdentity` red iz baze niti `Customer` — oni nastaju tek kad se
/// korisnik prvi put prijavi u konkretan salon ([task 14](../../../../tasks/sprint-2/14-identitet-i-klijent-upsert.md)).
/// Ovdje stoji samo ono što Supabase Auth zna o korisniku, prije nego što ga iko veže za
/// tenant.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.providers,
    this.email,
    this.isAnonymous = false,
  });

  /// `auth.users.id` — ono što JWT nosi kao `sub`. Ne prelazi granicu salona sam po sebi:
  /// isti korisnik u dva salona ima dva `Customer` reda, a jedan `userId`
  /// (v. `.claude/docs/security.md`).
  final String userId;

  /// Provideri kojima je ovaj nalog povezan. Supabase dozvoljava više identiteta nad istim
  /// emailom, pa ovo nije jedna vrijednost nego skup.
  final Set<String> providers;

  /// `null` za goste i za Apple private relay dok korisnik ne podijeli adresu.
  final String? email;

  /// Gost — rezervisao je bez naloga. Tok gosta je
  /// [task 26](../../../../tasks/sprint-2/26-gost-i-facebook.md); polje postoji ovdje da
  /// ekran ne mora pitati backend šta je korisnik.
  final bool isAnonymous;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthSession &&
          other.userId == userId &&
          other.email == email &&
          other.isAnonymous == isAnonymous &&
          other.providers.length == providers.length &&
          other.providers.containsAll(providers);

  @override
  int get hashCode => Object.hash(
    userId,
    email,
    isAnonymous,
    Object.hashAll(providers.toList()..sort()),
  );

  @override
  String toString() =>
      'AuthSession($userId, providers: ${providers.toList()..sort()}, '
      'anonymous: $isAnonymous)';
}
