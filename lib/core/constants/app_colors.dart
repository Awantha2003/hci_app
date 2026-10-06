import 'package:flutter/material.dart';

/// MindCheck colour palette, following the team's 60-30-10 rule.
///
/// * 60% dominant – soft off-white / light lavender background
/// * 30% secondary – muted teal / sage for cards and sections
/// * 10% accent – soft purple (primary actions) and warm coral (highlights)
///
/// Calming, non-clinical colours: no harsh red (feels alarming) and no stark
/// white/black (feels too clinical).
class AppColors {
  AppColors._();

  // 60% – dominant
  static const background = Color(0xFFF7F5FA);
  static const surface = Color(0xFFFFFFFF);

  // 30% – secondary (sage)
  static const sage = Color(0xFF7FB3A8);
  static const sageLight = Color(0xFFE4F0ED);
  static const sageDark = Color(0xFF2E5A51);

  /// Text on solid sage; meets WCAG AA (about 5:1).
  static const sageInk = Color(0xFF1B3A34);

  // 10% – accents
  static const purple = Color(0xFF9B7EDE);
  static const purpleLight = Color(0xFFEDE6FB);
  static const purpleDark = Color(0xFF4A3485);
  static const coral = Color(0xFFFF9F87);
  static const coralLight = Color(0xFFFFE6DF);
  static const coralDark = Color(0xFF7A3322);

  // Text
  static const textPrimary = Color(0xFF2D2A35);
  static const textSecondary = Color(0xFF6B6776);
  static const outline = Color(0xFFDCD7E3);

  /// Errors and destructive actions: a soft terracotta instead of harsh red.
  static const error = Color(0xFFC0563F);
}
