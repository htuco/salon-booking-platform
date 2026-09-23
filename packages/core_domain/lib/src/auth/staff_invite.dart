/// Poziv za nalog osoblja koji još čeka (task 45) — red iz `public.staff_invites`.
///
/// Kod **nije** dio modela: baza čuva samo njegov hash, a sam kod vlasnik vidi jednom, pri
/// kreiranju ([StaffInviteCode]). Lista poziva zato ne može ponovo pokazati kod — može ga
/// samo povući i napraviti novi.
class StaffInvite {
  const StaffInvite({
    required this.id,
    required this.name,
    required this.role,
    required this.expiresAt,
  });

  factory StaffInvite.fromJson(Map<String, dynamic> json) => StaffInvite(
    id: json['id'] as String,
    name: json['name'] as String,
    role: json['role'] as String,
    expiresAt: DateTime.parse(json['expires_at'] as String),
  );

  final String id;
  final String name;

  /// `salon_admin` ili `employee` — `super_admin` baza ne dozvoljava u pozivu.
  final String role;
  final DateTime expiresAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffInvite &&
          other.id == id &&
          other.name == name &&
          other.role == role &&
          other.expiresAt == expiresAt;

  @override
  int get hashCode => Object.hash(id, name, role, expiresAt);
}

/// Upravo napravljen poziv — jedini trenutak kad je kod poznat.
class StaffInviteCode {
  const StaffInviteCode({
    required this.inviteId,
    required this.code,
    required this.expiresAt,
  });

  final String inviteId;

  /// 10 znakova, velika slova i cifre bez 0/O/1/I/L — prepisuje se sa telefona.
  final String code;
  final DateTime expiresAt;
}
