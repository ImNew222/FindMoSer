import 'package:flutter/material.dart';
import '../../core/app_theme.dart';

/// Neumorphic-style card widget
///
/// A raised neumorphic card with dual-shadow embossed effect.
/// Used throughout FindMoSer for a premium, tactile feel.
class GlassCard extends StatefulWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final double opacity;
  final Color? color;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.borderRadius = 20,
    this.opacity = 0.75,
    this.color,
    this.onTap,
  });

  @override
  State<GlassCard> createState() => _GlassCardState();
}

class _GlassCardState extends State<GlassCard> {
  bool _isPressed = false;

  void _onTapDown(TapDownDetails _) {
    if (widget.onTap != null) {
      setState(() => _isPressed = true);
    }
  }

  void _onTapUp(TapUpDetails _) {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
      widget.onTap?.call();
    }
  }

  void _onTapCancel() {
    if (widget.onTap != null) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin:
            widget.margin ??
            const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: _isPressed
            ? AppTheme.neumorphicInsetDecoration(
                borderRadius: widget.borderRadius,
                color: widget.color,
              )
            : AppTheme.neumorphicDecoration(
                borderRadius: widget.borderRadius,
                color: widget.color ?? AppTheme.background,
              ),
        child: Padding(
          padding: widget.padding ?? const EdgeInsets.all(20),
          child: widget.child,
        ),
      ),
    );
  }
}
