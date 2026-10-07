import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_theme.dart';

/// Neumorphic raised button with press animation
///
/// A premium-looking button with dual-shadow neumorphic effect,
/// rounded corners, and scale-down + inset animation on press.
class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final LinearGradient? gradient;
  final IconData? icon;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.gradient,
    this.icon,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDisabled = widget.onPressed == null || widget.isLoading;

    return GestureDetector(
      onTapDown: isDisabled
          ? null
          : (_) {
              _controller.forward();
              setState(() => _isPressed = true);
            },
      onTapUp: isDisabled
          ? null
          : (_) {
              _controller.reverse();
              setState(() => _isPressed = false);
              widget.onPressed?.call();
            },
      onTapCancel: isDisabled
          ? null
          : () {
              _controller.reverse();
              setState(() => _isPressed = false);
            },
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, animChild) =>
            Transform.scale(scale: _scaleAnimation.value, child: animChild),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: widget.width ?? double.infinity,
          height: 56,
          decoration: isDisabled
              ? AppTheme.neumorphicFlatDecoration(
                  borderRadius: 16,
                  color: AppTheme.surfaceVariant,
                )
              : _isPressed
              ? AppTheme.neumorphicInsetDecoration(borderRadius: 16)
              : AppTheme.neumorphicDecoration(borderRadius: 16, blurRadius: 12),
          child: Center(
            child: widget.isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: AppTheme.primary,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.icon != null) ...[
                        Icon(
                          widget.icon,
                          color: isDisabled
                              ? AppTheme.textHint
                              : AppTheme.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 10),
                      ],
                      Text(
                        widget.text,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: isDisabled
                              ? AppTheme.textHint
                              : AppTheme.textPrimary,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// AnimatedBuilder is just an alias for AnimatedWidget pattern
/// Using the standard AnimatedBuilder from Flutter
