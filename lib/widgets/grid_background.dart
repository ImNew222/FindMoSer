import 'package:flutter/material.dart';
import '../config/app_theme.dart';

/// A flat warm background for the FindMoSer app.
///
/// Replaced the old grid pattern with a clean neumorphic-friendly
/// flat warm cream background.
class GridBackground extends StatelessWidget {
  final Widget child;

  const GridBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(color: AppTheme.background, child: child);
  }
}
