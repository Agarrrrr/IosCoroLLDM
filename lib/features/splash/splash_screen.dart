import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    _timer = Timer(const Duration(milliseconds: 1300), () {
      if (mounted) {
        context.go('/');
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final baseAccent = ref.watch(accentColorProvider);
    final accentColor = AppTheme.adaptAccent(themeMode, baseAccent);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final titleColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subtitleColor = isDark
        ? Colors.white.withValues(alpha: 0.65)
        : const Color(0xFF475569);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 3),
              Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: accentColor.withValues(alpha: isDark ? 0.28 : 0.18),
                      blurRadius: 36,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: Image.asset(
                  'assets/brand/emblem-transparent.png',
                  fit: BoxFit.contain,
                ),
              )
                  .animate()
                  .fadeIn(duration: 500.ms, curve: Curves.easeOut)
                  .scale(
                    begin: const Offset(0.85, 0.85),
                    end: const Offset(1.0, 1.0),
                    duration: 650.ms,
                    curve: Curves.easeOutBack,
                  ),
              const SizedBox(height: 28),
              Text(
                'CORO LLDM',
                style: GoogleFonts.cinzel(
                  fontSize: 26,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4.0,
                  color: titleColor,
                ),
              )
                  .animate()
                  .fadeIn(delay: 200.ms, duration: 450.ms)
                  .slideY(begin: 0.15, end: 0, duration: 450.ms, curve: Curves.easeOut),
              const SizedBox(height: 8),
              Text(
                'HIMNOS & PARTITURAS',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 3.2,
                  color: subtitleColor,
                ),
              )
                  .animate()
                  .fadeIn(delay: 350.ms, duration: 450.ms),
              const Spacer(flex: 2),
              SizedBox(
                width: 72,
                height: 3,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: LinearProgressIndicator(
                    backgroundColor: accentColor.withValues(alpha: 0.18),
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 450.ms, duration: 400.ms),
              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
