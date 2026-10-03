import 'package:flutter/material.dart';

/// Constrains presentation while preserving the child's scrolling and state.
class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent(
      {super.key, required this.child, this.maxWidth = 1120});
  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: SizedBox(width: double.infinity, child: child),
        ),
      );
}
