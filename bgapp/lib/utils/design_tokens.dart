import 'package:flutter/material.dart';

/// ═══════════════════════════════════════════════════════════════
///  DESIGN TOKENS — single source of truth for all UI constants.
///  Change once here → applies everywhere.
/// ═══════════════════════════════════════════════════════════════

class DS {
  DS._(); // prevent instantiation

  // ─────────────────────────────────────────
  //  BRAND / SOURCE COLORS
  // ─────────────────────────────────────────
  static const Color posColor       = Color(0xFF0369A1);  // POS / Penny Lane — blue
  static const Color shopifyColor   = Color(0xFF96BF48);  // Shopify — green
  static const Color shopifyDark    = Color(0xFF4D7C0F);  // Shopify text dark
  static const Color firebaseColor  = Color(0xFFEA580C);  // Firebase — orange
  static const Color labelColor     = Color(0xFF7C3AED);  // Label queue — purple
  static const Color conflictColor  = Color(0xFFDC2626);  // Mismatch/error — red
  static const Color warningColor   = Color(0xFFF59E0B);  // Warning — amber
  static const Color successColor   = Color(0xFF047857);  // Success — emerald
  static const Color successLight   = Color(0xFF34D399);  // Success light border
  static const Color successBorder  = Color(0xFF6EE7B7);  // Success chip border
  static const Color successDeep    = Color(0xFF065F46);  // Deep emerald text
  static const Color warningDark    = Color(0xFFD97706);  // Warning — dark amber
  static const Color warningDeep    = Color(0xFF92400E);  // Warning — deep amber
  static const Color warningBorder  = Color(0xFFFBBF24);  // Warning light border
  static const Color errorLight     = Color(0xFFFCA5A5);  // Error light border
  static const Color infoBorder     = Color(0xFFBAE6FD);  // Info light border
  static const Color accentBlue     = Color(0xFF2563EB);  // Bright blue CTA
  static const Color dividerColor   = Color(0xFFE5E7EB);  // Light dividers
  static const Color borderLight    = Color(0xFFE2E8F0);  // Light card borders
  static const Color subLabel       = Color(0xFF374151);  // Sub-label text
  static const Color chipSlate      = Color(0xFF64748B);  // Slate chip/label

  // ─────────────────────────────────────────
  //  TAG PICKER DARK THEME
  // ─────────────────────────────────────────
  static const Color tagPickerBg       = Color(0xFF1A1A2E);
  static const Color tagPickerSurface  = Color(0xFF0F0F1A);
  static const Color tagPickerBorder   = Color(0xFF2D2D44);
  static const Color tagPickerChipOff  = Color(0xFF1E1E32);  // Unselected chip bg
  static const Color tagPickerTextDim  = Color(0xFFD1D5DB);  // Dimmed white text

  // ─────────────────────────────────────────
  //  SURFACES & BACKGROUNDS
  // ─────────────────────────────────────────
  static const Color scaffoldBg     = Color(0xFFF3F4F6);  // Light grey page bg
  static const Color cardBg         = Colors.white;
  static const Color gridColor      = Color(0xFFD0D5DD);  // Grid lines / borders
  static const Color labelBg        = Color(0xFFF1F5F9);  // Row label background
  static const Color cellEditBg     = Color(0xFFFFFBEB);  // Editable cell warm tint
  static const Color headerBg       = Color(0xFF374151);  // Dark section headers
  static const Color headerText     = Colors.white;
  static const Color subtitleBar    = Color(0xFF1E293B);  // Vendor/store bar
  static const Color skuBg          = Color(0xFF0F172A);  // SKU icon bg
  static const Color darkCodeBg     = Color(0xFF1E293B);  // Dark code block bg

  // ─────────────────────────────────────────
  //  STATUS BACKGROUNDS
  // ─────────────────────────────────────────
  static const Color successBg      = Color(0xFFD1FAE5);
  static const Color errorBg        = Color(0xFFFEE2E2);
  static const Color warningBg      = Color(0xFFFEF3C7);
  static const Color infoBg         = Color(0xFFF0F9FF);
  static const Color neutralBg      = Color(0xFFF1F5F9);
  static const Color shopifyBg      = Color(0xFFF0FDF4);
  static const Color shopifyChipBg  = Color(0xFFECFDF5);
  static const Color errorLightBg   = Color(0xFFFEF2F2);  // Very light red bg
  static const Color surfaceSlate   = Color(0xFFF8FAFC);  // Near-white surface
  static const Color posInfoBg      = Color(0xFFE0F2FE);  // Light blue info bg

  // ─────────────────────────────────────────
  //  TEXT COLORS
  // ─────────────────────────────────────────
  static const Color textDark       = Color(0xFF111827);  // Primary text — near black
  static const Color textBody       = Color(0xFF0F172A);  // Body text
  static const Color textLabel      = Color(0xFF4B5563);  // Labels
  static const Color textMuted      = Color(0xFF6B7280);  // Muted / placeholders
  static const Color textFaint      = Color(0xFF9CA3AF);  // Subtle descriptions
  static const Color textDisabled   = Color(0xFFBBBBBB);  // Disabled / dashes
  static const Color textSubtitle   = Color(0xFF94A3B8);  // Subtitle bar text

  // ─────────────────────────────────────────
  //  FONT SIZES
  // ─────────────────────────────────────────
  static const double fontXXS       = 7.0;   // Badges (MASTER, MISMATCH)
  static const double fontXS        = 8.0;   // Mode badge, tiny pills
  static const double fontS         = 9.0;   // Sub-labels, system labels
  static const double fontSM        = 10.0;  // Secondary labels, button text
  static const double fontM         = 11.0;  // Status text, section info
  static const double fontMD        = 12.0;  // Status label, row labels
  static const double fontL         = 13.0;  // Comparison values, names
  static const double fontLG        = 14.0;  // Editable inputs, buttons
  static const double fontXL        = 15.0;  // App bar title
  static const double fontXXL       = 16.0;  // SKU field

  // ─────────────────────────────────────────
  //  FONT WEIGHTS
  // ─────────────────────────────────────────
  static const FontWeight weightNormal  = FontWeight.w400;
  static const FontWeight weightMedium  = FontWeight.w500;
  static const FontWeight weightSemi    = FontWeight.w600;
  static const FontWeight weightBold    = FontWeight.w700;
  static const FontWeight weightHeavy   = FontWeight.w800;

  // ─────────────────────────────────────────
  //  SPACING / PADDING (px)
  // ─────────────────────────────────────────
  static const double spaceXXS     = 2.0;
  static const double spaceXS      = 3.0;
  static const double spaceS       = 4.0;
  static const double spaceSM      = 5.0;
  static const double spaceM       = 6.0;
  static const double spaceMD      = 8.0;
  static const double spaceL       = 10.0;
  static const double spaceLG      = 12.0;
  static const double spaceXL      = 16.0;

  // ─────────────────────────────────────────
  //  ROW HEIGHTS
  // ─────────────────────────────────────────
  static const double gridRowMin        = 38.0;
  static const double statusRowPadV     = 4.0;
  static const double compRowPadV       = 6.0;
  static const double subHeaderPadV     = 3.0;
  static const double sectionHeaderPadV = 5.0;

  // ─────────────────────────────────────────
  //  BORDER RADIUS
  // ─────────────────────────────────────────
  static const double radiusS      = 3.0;
  static const double radiusM      = 4.0;
  static const double radiusMD     = 6.0;
  static const double radiusL      = 8.0;
  static const double radiusXL     = 10.0;

  // ─────────────────────────────────────────
  //  ICON SIZES
  // ─────────────────────────────────────────
  static const double iconXS       = 11.0;
  static const double iconS        = 12.0;
  static const double iconSM       = 13.0;
  static const double iconM        = 14.0;
  static const double iconL        = 16.0;
  static const double iconXL       = 18.0;
  static const double iconXXL      = 20.0;
  static const double iconScan     = 22.0;

  // ─────────────────────────────────────────
  //  GRID COLUMN WIDTHS
  // ─────────────────────────────────────────
  static const double labelColWidth     = 110.0;  // Single-row label
  static const double dblLabelColWidth  = 55.0;   // Double-row label
  static const double nameColWidth      = 100.0;  // Name comparison system label

  // ─────────────────────────────────────────
  //  REUSABLE TEXT STYLES
  // ─────────────────────────────────────────

  /// Values shown in comparison table & name rows — bold, easy to read
  static const TextStyle valueStyle = TextStyle(
    fontSize: fontL,
    fontWeight: weightBold,
    color: textDark,
  );

  /// Disabled / placeholder value
  static const TextStyle valueMutedStyle = TextStyle(
    fontSize: fontL,
    fontWeight: weightBold,
    color: textDisabled,
  );

  /// Editable input fields
  static const TextStyle inputStyle = TextStyle(
    fontSize: fontLG,
    fontWeight: weightBold,
    color: textDark,
  );

  /// Input prefix (\$)
  static const TextStyle inputPrefixStyle = TextStyle(
    fontSize: fontLG,
    fontWeight: weightBold,
    color: textMuted,
  );

  /// Grid row labels
  static const TextStyle rowLabelStyle = TextStyle(
    fontSize: fontSM,
    fontWeight: weightSemi,
    color: textLabel,
  );

  /// Section header text (dark bars)
  static const TextStyle sectionHeaderStyle = TextStyle(
    fontSize: fontSM,
    fontWeight: weightBold,
    color: headerText,
    letterSpacing: 0.8,
  );

  /// Sub-header text (STORE→POS, COST, etc.)
  static TextStyle subHeaderStyle(Color color) => TextStyle(
    fontSize: fontS,
    fontWeight: weightHeavy,
    color: color,
    letterSpacing: 0.5,
  );

  /// System label in name/status rows (e.g. "POS (Penny Lane)")
  static TextStyle systemLabelStyle(Color color) => TextStyle(
    fontSize: fontS,
    fontWeight: weightBold,
    color: color,
    letterSpacing: 0.3,
  );

  /// Status row title (e.g. "POS (Penny Lane) ✓")
  static TextStyle statusTitleStyle(Color color) => TextStyle(
    fontSize: fontMD,
    fontWeight: weightHeavy,
    color: color,
  );

  /// Status row detail text
  static TextStyle statusDetailStyle(Color color) => TextStyle(
    fontSize: fontSM,
    fontWeight: weightSemi,
    color: color.withOpacity(0.85),
  );

  /// Comparison column header
  static TextStyle compHeaderStyle(Color color) => TextStyle(
    fontSize: fontS,
    fontWeight: weightHeavy,
    color: color,
    letterSpacing: 0.5,
  );

  /// Comparison row label
  static TextStyle compLabelStyle({bool isConflict = false}) => TextStyle(
    fontSize: fontSM,
    fontWeight: weightSemi,
    color: isConflict ? conflictColor : textLabel,
  );

  /// Quick action button text
  static TextStyle actionBtnStyle(Color color) => TextStyle(
    fontSize: fontSM,
    fontWeight: weightSemi,
    color: color,
  );

  /// Tiny badge text (MASTER, MISMATCH, REQUIRED)
  static const TextStyle badgeStyle = TextStyle(
    fontSize: fontXXS,
    fontWeight: weightHeavy,
    color: Colors.white,
  );

  /// Mode badge (STOCK / ORDER)
  static const TextStyle modeBadgeStyle = TextStyle(
    fontSize: fontXS,
    fontWeight: weightHeavy,
    color: Colors.white,
    letterSpacing: 0.5,
  );

  // ─────────────────────────────────────────
  //  DECORATION HELPERS
  // ─────────────────────────────────────────

  /// Standard grid bottom border
  static const BoxDecoration gridBottomBorder = BoxDecoration(
    border: Border(bottom: BorderSide(color: gridColor, width: 0.5)),
  );

  /// Badge pill decoration
  static BoxDecoration badgeDecoration(Color color) => BoxDecoration(
    color: color,
    borderRadius: BorderRadius.circular(radiusS),
  );

  /// Outlined pill for action buttons
  static BoxDecoration outlinedPill(Color color, {double opacity = 0.3}) => BoxDecoration(
    borderRadius: BorderRadius.circular(radiusMD),
    border: Border.all(color: color.withOpacity(opacity)),
  );

  /// Filled pill for action buttons
  static BoxDecoration filledPill(Color color, {double bgOpacity = 0.1, double borderOpacity = 0.4}) => BoxDecoration(
    color: color.withOpacity(bgOpacity),
    borderRadius: BorderRadius.circular(radiusMD),
    border: Border.all(color: color.withOpacity(borderOpacity)),
  );
}
