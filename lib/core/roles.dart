enum Workspace { parent, teacher, student, principal, admin }

Workspace? parseWorkspace(Object? value) {
  for (final role in Workspace.values) {
    if (role.name == value) return role;
  }
  return null;
}

extension WorkspacePermissions on Workspace {
  bool get isStaff => this == Workspace.teacher || isLeadership;
  bool get isLeadership =>
      this == Workspace.admin || this == Workspace.principal;
  bool get canMarkAttendance => isStaff;
  bool get canPublishNotices => isStaff;
  bool get canSubmitWork =>
      this == Workspace.parent || this == Workspace.student;
  String get label => '${name[0].toUpperCase()}${name.substring(1)}';
}
