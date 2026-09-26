import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';

/* ============================ PREMIUM PALETTE ============================ */

const Color kPremiumBg      = Color(0xFF050B18);
const Color kPremiumBg2     = Color(0xFF0A1326);
const Color kPremiumSurface = Color(0xFF111B31);
const Color kPremiumCard    = Color(0xE617223A);
const Color kPremiumGold    = Color(0xFFD6A84F);
const Color kPremiumBlue    = Color(0xFF4F8CFF);
const Color kPremiumText    = Color(0xFFF8FAFC);
const Color kPremiumMuted   = Color(0xFFB6C2D9);

const Color kPremiumGoldSoft = Color(0xFFF2DCA4);
const Color kPremiumBorder   = Color(0x1FFFFFFF);
const Color kPremiumTeal     = Color(0xFF35D6C3);
const Color kPremiumViolet   = Color(0xFF9B7BFF);
const Color kPremiumSuccess  = Color(0xFF3FBF87);
const Color kPremiumWarning  = Color(0xFFE0A63A);
const Color kPremiumDanger   = Color(0xFFE5645A);

const LinearGradient kGradGold = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kPremiumGoldSoft, kPremiumGold],
);

const LinearGradient kGradBlue = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF6FA6FF), Color(0xFF2B5FCF)],
);

const LinearGradient kGradTeal = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFF5BE7D6), Color(0xFF17A594)],
);

const LinearGradient kGradViolet = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [Color(0xFFB79BFF), Color(0xFF6C4BE0)],
);

const LinearGradient kGradBg = LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [kPremiumBg, kPremiumBg2, kPremiumBg],
);

const List<LinearGradient> kAvatarGradients = [
  kGradBlue,
  kGradGold,
  kGradTeal,
  kGradViolet,
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF9A8B), Color(0xFFD65A6C)],
  ),
  LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8FD3FF), Color(0xFF3A7BD5)],
  ),
];

LinearGradient gradientFor(String seed) {
  final i = seed.isEmpty ? 0 : seed.codeUnits.fold<int>(0, (a, b) => a + b);
  return kAvatarGradients[i % kAvatarGradients.length];
}

/* ============================ PREMIUM THEME ============================ */

ThemeData premiumTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: kPremiumBlue,
    brightness: Brightness.dark,
    primary: kPremiumGold,
    onPrimary: kPremiumBg,
    secondary: kPremiumBlue,
    onSecondary: Colors.white,
    surface: kPremiumSurface,
    onSurface: kPremiumText,
    error: kPremiumDanger,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.transparent,
    canvasColor: Colors.transparent,
    splashFactory: InkSparkle.splashFactory,

    textTheme: Typography.whiteMountainView
        .apply(bodyColor: kPremiumText, displayColor: kPremiumText)
        .copyWith(
          headlineSmall: const TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.7,
              color: kPremiumText),
          titleLarge: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: kPremiumText),
          titleMedium: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: kPremiumText),
          bodyMedium: const TextStyle(color: kPremiumText, fontSize: 14),
          bodySmall: const TextStyle(fontSize: 12.5, color: kPremiumMuted),
        ),

    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      foregroundColor: kPremiumText,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: kPremiumText),
    ),

    cardTheme: CardThemeData(
      elevation: 0,
      color: kPremiumCard,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: kPremiumBorder),
      ),
    ),

    dividerTheme: const DividerThemeData(color: kPremiumBorder, thickness: 1),

    listTileTheme: const ListTileThemeData(
      iconColor: kPremiumMuted,
      textColor: kPremiumText,
      titleTextStyle:
          TextStyle(color: kPremiumText, fontWeight: FontWeight.w700, fontSize: 15),
      subtitleTextStyle: TextStyle(color: kPremiumMuted, fontSize: 12.5, height: 1.45),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(16))),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(.045),
      labelStyle: const TextStyle(color: kPremiumMuted),
      hintStyle: const TextStyle(color: kPremiumMuted),
      helperStyle: const TextStyle(color: kPremiumMuted, fontSize: 11.5),
      prefixIconColor: kPremiumMuted,
      floatingLabelStyle:
          const TextStyle(color: kPremiumGold, fontWeight: FontWeight.w700),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPremiumBorder)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPremiumBorder)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPremiumGold, width: 1.6)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPremiumDanger)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: kPremiumDanger, width: 1.6)),
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kPremiumGold,
        foregroundColor: kPremiumBg,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
        textStyle: const TextStyle(
            fontWeight: FontWeight.w800, fontSize: 14.5, letterSpacing: .2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: kPremiumGold,
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),

    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: kPremiumText),
    ),

    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withOpacity(.055),
      selectedColor: kPremiumGold.withOpacity(.20),
      checkmarkColor: kPremiumGold,
      side: const BorderSide(color: kPremiumBorder),
      labelStyle:
          const TextStyle(color: kPremiumText, fontWeight: FontWeight.w600),
      secondaryLabelStyle: const TextStyle(color: kPremiumGold),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    ),

    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((s) =>
          s.contains(WidgetState.selected) ? kPremiumGold : Colors.transparent),
      checkColor: const WidgetStatePropertyAll(kPremiumBg),
      side: const BorderSide(color: kPremiumMuted, width: 1.5),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
    ),

    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: Colors.transparent,
      indicatorColor: kPremiumGold.withOpacity(.16),
      indicatorShape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      selectedIconTheme: const IconThemeData(color: kPremiumGold, size: 23),
      unselectedIconTheme: const IconThemeData(color: kPremiumMuted, size: 22),
      selectedLabelTextStyle: const TextStyle(
          color: kPremiumGold, fontWeight: FontWeight.w700, fontSize: 11.5),
      unselectedLabelTextStyle:
          const TextStyle(color: kPremiumMuted, fontSize: 11.5),
    ),

    drawerTheme: const DrawerThemeData(
      backgroundColor: kPremiumSurface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: kPremiumSurface,
      surfaceTintColor: Colors.transparent,
      elevation: 24,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(26),
        side: const BorderSide(color: kPremiumBorder),
      ),
      titleTextStyle: const TextStyle(
          fontSize: 20, fontWeight: FontWeight.w800, color: kPremiumText),
      contentTextStyle: const TextStyle(color: kPremiumMuted),
    ),

    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: kPremiumSurface,
      contentTextStyle: const TextStyle(color: kPremiumText),
      actionTextColor: kPremiumGold,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      linearMinHeight: 8,
      color: kPremiumGold,
      linearTrackColor: Colors.white.withOpacity(.07),
    ),

    dataTableTheme: const DataTableThemeData(
      headingTextStyle:
          TextStyle(color: kPremiumGold, fontWeight: FontWeight.w800),
      dataTextStyle: TextStyle(color: kPremiumText),
      dividerThickness: .6,
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: kPremiumSurface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kPremiumBorder),
      ),
      textStyle: const TextStyle(color: kPremiumText, fontSize: 12),
    ),

    iconTheme: const IconThemeData(color: kPremiumMuted),
  );
}

/* ============================ BACKGROUND ============================ */

class PremiumBackground extends StatefulWidget {
  const PremiumBackground({super.key, required this.child});
  final Widget child;

  @override
  State<PremiumBackground> createState() => _PremiumBackgroundState();
}

class _PremiumBackgroundState extends State<PremiumBackground>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 22))
        ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const DecoratedBox(
          decoration: BoxDecoration(gradient: kGradBg),
          child: SizedBox.expand(),
        ),
        AnimatedBuilder(
          animation: _c,
          builder: (_, __) {
            final t = _c.value;
            return Stack(
              children: [
                _glow(
                    top: -150 + 60 * t,
                    left: -120 + 80 * t,
                    size: 420,
                    color: kPremiumBlue.withOpacity(.30)),
                _glow(
                    top: 220 + 90 * (1 - t),
                    right: -170 + 70 * t,
                    size: 360,
                    color: kPremiumGold.withOpacity(.16)),
                _glow(
                    bottom: -180 + 80 * t,
                    left: 60 + 110 * (1 - t),
                    size: 400,
                    color: kPremiumTeal.withOpacity(.13)),
                _glow(
                    bottom: 120 + 40 * t,
                    right: 40 + 60 * (1 - t),
                    size: 280,
                    color: kPremiumViolet.withOpacity(.14)),
              ],
            );
          },
        ),
        const Positioned.fill(
          child: IgnorePointer(child: CustomPaint(painter: _GridPainter())),
        ),
        Positioned.fill(
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.15,
                  colors: [Colors.transparent, Colors.black.withOpacity(.45)],
                ),
              ),
            ),
          ),
        ),
        widget.child,
      ],
    );
  }

  Widget _glow({
    double? top,
    double? left,
    double? right,
    double? bottom,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withOpacity(0)]),
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  const _GridPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Colors.white.withOpacity(.028)
      ..strokeWidth = 1;
    const step = 46.0;
    for (double x = 0; x < size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/* ============================ ANIMATION HELPERS ============================ */

class FadeInSlide extends StatefulWidget {
  const FadeInSlide({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 320),
    this.delay = Duration.zero,
    this.offset = 0.06,
    this.index,
  });

  final Widget child;
  final Duration duration;
  final Duration delay;
  final double offset;
  final int? index;

  @override
  State<FadeInSlide> createState() => _FadeInSlideState();
}

class _FadeInSlideState extends State<FadeInSlide> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slideAnimation = Tween<Offset>(
      begin: Offset(0, widget.offset),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    final effectiveDelay = widget.delay != Duration.zero
        ? widget.delay
        : (widget.index != null ? Duration(milliseconds: widget.index! * 60) : Duration.zero);

    if (effectiveDelay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(effectiveDelay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: widget.child,
      ),
    );
  }
}

/* ============================ GLASS CARD ============================ */

class GlassCard extends StatelessWidget {
  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin = const EdgeInsets.symmetric(vertical: 6),
    this.radius = 22,
    this.glow,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets margin;
  final double radius;
  final Color? glow;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Padding(
        padding: margin,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kPremiumCard.withOpacity(0.85),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(.07),
                    Colors.white.withOpacity(.02),
                  ],
                ),
                borderRadius: BorderRadius.circular(radius),
                border: Border.all(color: kPremiumBorder),
                boxShadow: [
                  BoxShadow(
                    color: (glow ?? Colors.black).withOpacity(glow != null ? .18 : .35),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(radius),
                  child: Padding(padding: padding, child: child),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/* ============================ IMAGE STYLES ============================ */

enum AvatarStyle { gradient, pattern, photo, glowIcon }

class PremiumAvatar extends StatelessWidget {
  const PremiumAvatar({
    super.key,
    this.label,
    this.icon,
    this.imageUrl,
    this.style = AvatarStyle.gradient,
    this.size = 48,
    this.radius = 16,
    this.gradient,
  });

  final String? label;
  final IconData? icon;
  final String? imageUrl;
  final AvatarStyle style;
  final double size;
  final double radius;
  final LinearGradient? gradient;

  @override
  Widget build(BuildContext context) {
    final g = gradient ?? gradientFor(label ?? icon?.codePoint.toString() ?? 'x');
    final initials = _initials(label ?? '');

    Widget inner;
    switch (style) {
      case AvatarStyle.photo:
        inner = (imageUrl == null || imageUrl!.isEmpty)
            ? _gradientInitials(g, initials)
            : Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl!,
                    fit: BoxFit.cover,
                    loadingBuilder: (c, w, p) =>
                        p == null ? w : _shimmer(),
                    errorBuilder: (c, e, s) => _gradientInitials(g, initials),
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          kPremiumBg.withOpacity(.45),
                        ],
                      ),
                    ),
                  ),
                ],
              );
        break;

      case AvatarStyle.pattern:
        inner = Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(decoration: BoxDecoration(gradient: g)),
            CustomPaint(painter: _PatternPainter(seed: label ?? 'a')),
            Center(
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: size * .34,
                  shadows: const [
                    Shadow(color: Colors.black45, blurRadius: 6),
                  ],
                ),
              ),
            ),
          ],
        );
        break;

      case AvatarStyle.glowIcon:
        inner = DecoratedBox(
          decoration: BoxDecoration(gradient: g),
          child: Icon(icon ?? Icons.star_rounded,
              color: Colors.white, size: size * .48),
        );
        break;

      case AvatarStyle.gradient:
        inner = _gradientInitials(g, initials);
        break;
    }

    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: Colors.white.withOpacity(.16), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: g.colors.last.withOpacity(.38),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius - 1),
        child: inner,
      ),
    );
  }

  Widget _gradientInitials(LinearGradient g, String initials) => DecoratedBox(
        decoration: BoxDecoration(gradient: g),
        child: Center(
          child: icon != null
              ? Icon(icon, color: Colors.white, size: size * .46)
              : Text(
                  initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: size * .34,
                    letterSpacing: .5,
                  ),
                ),
        ),
      );

  Widget _shimmer() => DecoratedBox(
        decoration: BoxDecoration(color: Colors.white.withOpacity(.06)),
      );

  static String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0][0] + parts[1][0]).toUpperCase();
  }
}

class _PatternPainter extends CustomPainter {
  _PatternPainter({required this.seed});
  final String seed;

  @override
  void paint(Canvas canvas, Size size) {
    final rnd = math.Random(seed.codeUnits.fold<int>(7, (a, b) => a * 31 + b));
    final p = Paint()..color = Colors.white.withOpacity(.16);
    for (int i = 0; i < 9; i++) {
      final dx = rnd.nextDouble() * size.width;
      final dy = rnd.nextDouble() * size.height;
      final r = 2.0 + rnd.nextDouble() * 7;
      if (rnd.nextBool()) {
        canvas.drawCircle(Offset(dx, dy), r, p);
      } else {
        canvas.drawRect(
            Rect.fromCenter(center: Offset(dx, dy), width: r * 2, height: r * 2),
            p);
      }
    }
    final line = Paint()
      ..color = Colors.white.withOpacity(.12)
      ..strokeWidth = 1.4;
    canvas.drawLine(Offset(0, size.height * .7),
        Offset(size.width, size.height * .3), line);
  }

  @override
  bool shouldRepaint(covariant _PatternPainter old) => old.seed != seed;
}

/* ------------------ HERO BANNER (image-style header) ------------------ */

class HeroBanner extends StatelessWidget {
  const HeroBanner({
    super.key,
    required this.title,
    required this.subtitle,
    required this.badge,
    this.imageUrl,
  });

  final String title;
  final String subtitle;
  final String badge;
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 190),
        child: Stack(
          children: [
            Positioned.fill(
              child: imageUrl == null
                  ? const DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFF15305C),
                            Color(0xFF0B1730),
                            Color(0xFF1B2B12),
                          ],
                        ),
                      ),
                    )
                  : Image.network(
                      imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(
                        color: kPremiumSurface,
                      ),
                    ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: const _WavePainter()),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      kPremiumBg.withOpacity(.92),
                      kPremiumBg.withOpacity(.55),
                      kPremiumBg.withOpacity(.25),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: kGradGold,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                            color: kPremiumGold.withOpacity(.35),
                            blurRadius: 16,
                            offset: const Offset(0, 6)),
                      ],
                    ),
                    child: Text(
                      badge.toUpperCase(),
                      style: const TextStyle(
                        color: kPremiumBg,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ShaderMask(
                    shaderCallback: (r) => const LinearGradient(colors: [
                      Colors.white,
                      kPremiumGoldSoft,
                    ]).createShader(r),
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 27,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.8,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(subtitle,
                      style: const TextStyle(
                          color: kPremiumMuted, fontSize: 13.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  const _WavePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = kPremiumGold.withOpacity(.18);
    for (int i = 0; i < 5; i++) {
      final path = Path();
      final off = i * 22.0;
      path.moveTo(size.width * .35, size.height + off);
      path.quadraticBezierTo(
        size.width * .72,
        size.height * .45 - off * .5,
        size.width + off,
        -30 - off,
      );
      canvas.drawPath(path, paint);
    }
    final dot = Paint()..color = kPremiumBlue.withOpacity(.22);
    canvas.drawCircle(Offset(size.width * .86, size.height * .28), 46, dot);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/* ------------------ GRADIENT BUTTON ------------------ */

class GoldButton extends StatelessWidget {
  const GoldButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.expand = false,
    this.isLoading = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool expand;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final btn = DecoratedBox(
      decoration: BoxDecoration(
        gradient: kGradGold,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: kPremiumGold.withOpacity(.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: isLoading
          ? Container(
              height: 48,
              alignment: Alignment.center,
              child: const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(color: kPremiumBg, strokeWidth: 2.5),
              ),
            )
          : (icon != null
              ? FilledButton.icon(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: kPremiumBg,
                  ),
                  icon: Icon(icon, size: 18),
                  label: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )
              : FilledButton(
                  onPressed: onPressed,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: kPremiumBg,
                  ),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                )),
    );
    return expand ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// Displays a sleek, premium confirmation modal when the user requests to sign out.
Future<bool> showLogoutConfirmationDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) {
      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF121C31), Color(0xFF0B1220)],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPremiumBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 32),
              ),
              const SizedBox(height: 16),
              const Text(
                'Confirm Sign Out',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: kPremiumText,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Are you sure you want to sign out of your account? You will need to sign in again to access the workspace.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  color: kPremiumMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: kPremiumBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Cancel', style: TextStyle(color: kPremiumText, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Sign Out', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return confirmed ?? false;
}
