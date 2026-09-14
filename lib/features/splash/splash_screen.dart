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
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
    // Inicia un fade out suave antes de salir
    _timer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _closing = true);
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) context.go('/');
        });
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
          child: AnimatedOpacity(
            opacity: _closing ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOut,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 3),
                // Emblema con difuminado suave sin saltos
                Container(
                  width: 124,
                  height: 124,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: accentColor.withValues(alpha: isDark ? 0.20 : 0.12),
                        blurRadius: 32,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/brand/emblem-transparent.png',
                    fit: BoxFit.contain,
                  ),
                )
                    .animate()
                    .fadeIn(duration: 650.ms, curve: Curves.easeInOut),
                const SizedBox(height: 26),
                // Título institucional sobrio
                Text(
                  'CORO LLDM',
                  style: GoogleFonts.cinzel(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4.0,
                    color: titleColor,
                  ),
                )
                    .animate()
                    .fadeIn(delay: 200.ms, duration: 600.ms, curve: Curves.easeInOut),
                const SizedBox(height: 8),
                // Subtítulo
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
                    .fadeIn(delay: 350.ms, duration: 550.ms, curve: Curves.easeInOut),
                const Spacer(flex: 2),
                // Barra de progreso minimalista teñida con el color de resalte
                SizedBox(
                  width: 64,
                  height: 2.5,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      backgroundColor: accentColor.withValues(alpha: 0.15),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 450.ms, duration: 500.ms, curve: Curves.easeInOut),
                const Spacer(flex: 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
