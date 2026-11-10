import 'package:flutter/material.dart';
import '../../auth/widgets/account_profile_panel.dart';
import '../../presence/widgets/sharing_settings.dart';

class FacultyProfileTab extends StatelessWidget {
  const FacultyProfileTab({super.key});
  @override
  Widget build(BuildContext context) => const AccountProfilePanel(
    faculty: true,
    extraSections: [SharingSettings()],
  );
}
