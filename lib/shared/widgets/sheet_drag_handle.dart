import 'package:flutter/material.dart';

/// Small grey bar at the top of a bottom sheet (the "drag handle").
/// Same size and colour on every sheet in the app.
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key, this.bottomSpacing = 14});

  /// Space below the handle, before the sheet's content.
  final double bottomSpacing;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: EdgeInsets.only(bottom: bottomSpacing),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: const Color(0xFFCBD5E1),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
