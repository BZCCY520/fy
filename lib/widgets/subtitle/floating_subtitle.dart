import 'dart:ui';
import 'package:flutter/material.dart';
import '../../theme/liquid_glass_theme.dart';

/// 悬浮字幕组件
/// 特点：可拖拽、玻璃背景、自适应大小
class FloatingSubtitle extends StatefulWidget {
  const FloatingSubtitle({
    super.key,
    required this.text,
    required this.initialOffset,
    required this.maxSize,
    this.onPositionChanged,
    this.visible = true,
    this.fontSize = 20.0,
    this.maxLines = 3,
  });

  final String text;
  final Offset initialOffset;
  final Size maxSize;
  final ValueChanged<Offset>? onPositionChanged;
  final bool visible;
  final double fontSize;
  final int maxLines;

  @override
  State<FloatingSubtitle> createState() => _FloatingSubtitleState();
}

class _FloatingSubtitleState extends State<FloatingSubtitle> {
  late Offset _position;

  @override
  void initState() {
    super.initState();
    _position = widget.initialOffset;
  }

  @override
  void didUpdateWidget(FloatingSubtitle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialOffset != widget.initialOffset) {
      _position = widget.initialOffset;
    }
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _position = Offset(
        (_position.dx + details.delta.dx).clamp(
          LiquidGlassTheme.spaceM,
          widget.maxSize.width - 200,
        ),
        (_position.dy + details.delta.dy).clamp(
          LiquidGlassTheme.spaceM,
          widget.maxSize.height - 100,
        ),
      );
    });
  }

  void _onPanEnd(DragEndDetails details) {
    widget.onPositionChanged?.call(_position);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.visible || widget.text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final maxWidth = widget.maxSize.width - (LiquidGlassTheme.spaceM * 2);

    return Positioned(
      left: _position.dx,
      top: _position.dy,
      child: GestureDetector(
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            minWidth: 100,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(LiquidGlassTheme.radiusMedium),
            child: BackdropFilter(
              filter: ImageFilter.blur(
                sigmaX: LiquidGlassTheme.blurHeavy,
                sigmaY: LiquidGlassTheme.blurHeavy,
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.7),
                  borderRadius:
                      BorderRadius.circular(LiquidGlassTheme.radiusMedium),
                  border: Border.all(
                    color: LiquidGlassTheme.glassBorder,
                    width: 1.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 30,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.drag_indicator,
                          color: LiquidGlassTheme.textSecondary,
                          size: 16,
                        ),
                        const SizedBox(width: LiquidGlassTheme.spaceXs),
                        Text(
                          '可拖拽字幕',
                          style: TextStyle(
                            color: LiquidGlassTheme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: LiquidGlassTheme.spaceS),
                    Text(
                      widget.text,
                      maxLines: widget.maxLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: LiquidGlassTheme.textPrimary,
                        fontSize: widget.fontSize,
                        fontWeight: FontWeight.w700,
                        height: 1.4,
                        letterSpacing: -0.3,
                        shadows: const [
                          Shadow(
                            color: Colors.black,
                            blurRadius: 10,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
