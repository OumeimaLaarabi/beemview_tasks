import 'package:flutter/material.dart';

/// Design tokens from the BeemView Tasks Figma design.
abstract final class AppColors {
  static const ink = Color(0xFF172036);
  static const muted = Color(0xFF697386);
  static const line = Color(0xFFE4E8F0);
  static const surface = Color(0xFFFFFFFF);
  static const canvas = Color(0xFFF7F8FB);

  static const brand = Color(0xFF5B52D9);
  static const brandDark = Color(0xFF4037B8);
  static const brandSoft = Color(0xFFEEECFF);
  static const brandOnDark = Color(0xFFC4C0FF);

  static const danger = Color(0xFFD83A52);
  static const dangerSoft = Color(0xFFFFF3F5);
  static const dangerLine = Color(0xFFF1CCD2);
  static const dangerIconBg = Color(0xFFF9D9DE);
  static const dangerMuted = Color(0xFF8C5B64);

  // Form fields.
  static const fieldBorder = Color(0xFFDFE3EB);
  static const fieldFill = Color(0xFFFBFCFE);
  static const fieldIcon = Color(0xFF8C94A5);
  static const fieldAction = Color(0xFF7D8595);
  static const subtle = Color(0xFF98A0AE);

  /// Hero header behind the login screen.
  static const heroGradient = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [Color(0xFF25205F), Color(0xFF5148CA), Color(0xFF675EE1)],
    stops: [0, 0.68, 1],
  );

  /// Primary call-to-action buttons.
  static const buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF655CE2), Color(0xFF4D45C8)],
  );

  /// The square behind the logo bars.
  static const logoGradient = LinearGradient(
    begin: Alignment(-0.6, -1),
    end: Alignment(0.6, 1),
    colors: [Color(0xFF7C73EF), Color(0xFF4D45CF)],
  );
}
