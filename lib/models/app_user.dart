class AppUser {
  final String uid, role;
  final String? name, phone, email, department;
  final List<int> assignedWards;
  final bool isActive;
  AppUser({required this.uid, required this.role, this.name, this.phone, this.email, this.department, this.assignedWards = const [], this.isActive = true});
  factory AppUser.fromMap(String uid, Map<String, dynamic> m) => AppUser(
        uid: uid, role: m['role'] ?? 'citizen', name: m['name'], phone: m['phone'], email: m['email'],
        department: m['department'], assignedWards: List<int>.from(m['assignedWards'] ?? []), isActive: m['isActive'] ?? true);
  bool get isAdmin => role == 'department_admin';
  bool get isSuper => role == 'super_admin';
}
