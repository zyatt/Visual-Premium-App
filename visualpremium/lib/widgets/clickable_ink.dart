import 'package:flutter/material.dart';

class ClickableInk extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius? borderRadius;
  final Color? splashColor;
  final Color? hoverColor;
  final Color? highlightColor;

  const ClickableInk({
    super.key,
    required this.child,
    this.onTap,
    this.borderRadius,
    this.splashColor = Colors.transparent,
    this.hoverColor = Colors.transparent,
    this.highlightColor = Colors.transparent,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        mouseCursor: SystemMouseCursors.click,
        splashColor: splashColor,
        hoverColor: hoverColor,
        highlightColor: highlightColor,
        borderRadius: borderRadius,
        child: child,
      ),
    );
  }
}