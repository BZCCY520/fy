import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/liquid_glass_theme.dart';

/// Liquid Glass 按钮组件
/// 特点：玻璃材质、悬浮效果、点击缩放动画
class LiquidGlassButton extends StatefulWidget {
  const LiquidGlassButton({
    super.key,
    required this.onPressed,
    this.child,
    this.icon,
    this.text,
    this.width,
    this.height = 48.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    this.backgroundColor,
    this.foregroundColor,
    this.borderColor,
    this.enabled = true,
    this.loading = false,
  }) : assert(child != null || icon != null || text != null,
            'Must provide either child, icon, or text');

  final VoidCallback? onPressed;
  final Widget? child;
  final IconData? icon;
  final String? text;
  final double? width;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? borderColor;
  final bool enabled;
  final bool loading;

  @override
  State<LiquidGlassButton> createState() => _LiquidGlassButtonState();
}

class _LiquidGlassButtonState extends State<LiquidGlassButton> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.enabled && !widget.loading;
    final scale = _isPressed && isEnabled ? 0.95 : 1.0;

    return GestureDetector(
      onTapDown: isEnabled ? (_) => setState(() => _isPressed = true) : null,
      onTapUp: isEnabled ? (_) => setState(() => _isPressed = false) : null,
      onTapCancel: isEnabled ? () => setState(() => _isPressed = false) : null,
      onTap: isEnabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: scale,
        duration: LiquidGlassTheme.animationFast,
        curve: LiquidGlassTheme.animationCurve,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMedium),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: LiquidGlassTheme.blurMedium,
              sigmaY: LiquidGlassTheme.blurMedium,
            ),
            child: Container(
              width: widget.width,
              height: widget.height,
              padding: widget.padding,
              decoration: BoxDecoration(
                color: widget.backgroundColor ??
                    (isEnabled
                        ? LiquidGlassTheme.glassBackground
                        : LiquidGlassTheme.glassBackground.withValues(alpha: 0.3)),
                borderRadius:
                    BorderRadius.circular(LiquidGlassTheme.radiusMedium),
                border: Border.all(
                  color: widget.borderColor ??
                      (isEnabled
                          ? LiquidGlassTheme.glassBorder
                          : LiquidGlassTheme.glassBorder.withValues(alpha: 0.3)),
                  width: 1.0,
                ),
                boxShadow: isEnabled
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ]
                    : null,
              ),
              child: widget.loading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: LiquidGlassTheme.textPrimary,
                        ),
                      ),
                    )
                  : widget.child ??
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (widget.icon != null) ...[
                            Icon(
                              widget.icon,
                              color: widget.foregroundColor ??
                                  (isEnabled
                                      ? LiquidGlassTheme.textPrimary
                                      : LiquidGlassTheme.textTertiary),
                              size: 20,
                            ),
                            if (widget.text != null)
                              const SizedBox(width: LiquidGlassTheme.spaceS),
                          ],
                          if (widget.text != null)
                            Text(
                              widget.text!,
                              style: TextStyle(
                                color: widget.foregroundColor ??
                                    (isEnabled
                                        ? LiquidGlassTheme.textPrimary
                                        : LiquidGlassTheme.textTertiary),
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                        ],
                      ),
            ),
          ),
        ),
      ),
    );
  }
}
