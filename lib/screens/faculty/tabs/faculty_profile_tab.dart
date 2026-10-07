import 'package:flutter/material.dart';
import '../../../widgets/account_profile_panel.dart';

class FacultyProfileTab extends StatelessWidget {
  final VoidCallback? onBeforeSignOut;
  const FacultyProfileTab({super.key, this.onBeforeSignOut});
  @override
  Widget build(BuildContext context) =>
      AccountProfilePanel(faculty: true, onBeforeSignOut: onBeforeSignOut);
}
