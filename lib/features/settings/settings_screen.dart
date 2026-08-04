import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:coro_lldm/core/localization/app_strings.dart';

class SettingsDialog extends ConsumerStatefulWidget {
  const SettingsDialog({super.key});

  @override
  ConsumerState<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<SettingsDialog> {
  @override
  Widget build(BuildContext context) {
    final currentTheme = ref.watch(themeProvider);
    final accentColor = ref.watch(accentColorProvider);
    final isCarousel = ref.watch(pdfNavModeProvider);
    final language = ref.watch(languageFilterProvider);
    final strings = AppStrings.of(context);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    strings.t('Ajustes', 'Settings'),
                    style: GoogleFonts.inter(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded,
                        color: Theme.of(context).colorScheme.onSurface),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _buildSectionTitle(strings.t('IDIOMA', 'LANGUAGE')),
              Row(
                children: [
                  Expanded(
                    child: _buildPdfNavOption(
                      title: 'Español',
                      icon: Icons.language_rounded,
                      isSelected: language == 'es',
                      onTap: () =>
                          ref.read(languageFilterProvider.notifier).set('es'),
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPdfNavOption(
                      title: 'English',
                      icon: Icons.language_rounded,
                      isSelected: language == 'en',
                      onTap: () =>
                          ref.read(languageFilterProvider.notifier).set('en'),
                      accentColor: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 1. COLOR DE ACENTO
              _buildSectionTitle(
                strings.t('COLOR DE ACENTO', 'ACCENT COLOR'),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _buildColorDot(
                      const Color(0xFFD4AF37), accentColor), // Dorado
                  _buildColorDot(const Color(0xFF3B82F6), accentColor), // Azul
                  _buildColorDot(const Color(0xFF10B981), accentColor), // Verde
                  _buildColorDot(
                      const Color(0xFFEF4444), accentColor), // Carmesí
                  _buildColorDot(
                      const Color(0xFF8B5CF6), accentColor), // Púrpura
                  _buildColorDot(
                      const Color(0xFFF97316), accentColor), // Naranja
                  _buildColorDot(
                      const Color(0xFF06B6D4), accentColor), // Cian (Teal)
                  _buildColorDot(
                      const Color(0xFFEC4899), accentColor), // Rosa (Magenta)
                  _buildColorDot(
                      const Color(0xFF6366F1), accentColor), // Índigo
                  _buildColorDot(
                      const Color(0xFF64748B), accentColor), // Plata (Slate)
                ],
              ),
              const SizedBox(height: 24),

              // 2. MODO PDF (SCROLL VS CAROUSEL)
              _buildSectionTitle(strings.t(
                'NAVEGACIÓN DE PARTITURA',
                'SCORE NAVIGATION',
              )),
              Row(
                children: [
                  Expanded(
                    child: _buildPdfNavOption(
                      title: strings.t('Desplazamiento', 'Scrolling'),
                      icon: Icons.swap_vert_rounded,
                      isSelected: !isCarousel,
                      onTap: () =>
                          ref.read(pdfNavModeProvider.notifier).set(false),
                      accentColor: accentColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildPdfNavOption(
                      title: strings.t('Carrusel', 'Carousel'),
                      icon: Icons.view_carousel_rounded,
                      isSelected: isCarousel,
                      onTap: () =>
                          ref.read(pdfNavModeProvider.notifier).set(true),
                      accentColor: accentColor,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 3. TEMAS
              _buildSectionTitle(strings.t(
                'PERFIL DE DISEÑO',
                'DISPLAY PROFILE',
              )),
              _buildThemeOption(
                context: context,
                title: strings.t(
                  'Normal (Día/Noche)',
                  'Normal (Day/Night)',
                ),
                icon: Icons.light_mode_rounded,
                isSelected: currentTheme == AppThemeMode.claro ||
                    currentTheme == AppThemeMode.oscuro,
                onTap: () =>
                    ref.read(themeProvider.notifier).setProfileNormal(),
                accentColor: accentColor,
              ),
              _buildThemeOption(
                context: context,
                title: strings.t(
                  'Lectura (Sepia/Quiet)',
                  'Reading (Sepia/Quiet)',
                ),
                icon: Icons.auto_stories_rounded,
                isSelected: currentTheme == AppThemeMode.sepia ||
                    currentTheme == AppThemeMode.quiet,
                onTap: () =>
                    ref.read(themeProvider.notifier).setProfileLectura(),
                accentColor: accentColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1,
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color, Color selectedColor) {
    final isSelected = color.toARGB32() == selectedColor.toARGB32();
    return GestureDetector(
      onTap: () => ref.read(accentColorProvider.notifier).set(color),
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.onSurface, width: 3)
              : null,
          boxShadow: [
            if (isSelected)
              BoxShadow(
                  color: color.withValues(alpha: 0.4),
                  blurRadius: 8,
                  spreadRadius: 2)
          ],
        ),
        child: isSelected
            ? const Icon(Icons.check_rounded, color: Colors.white, size: 20)
            : null,
      ),
    );
  }

  Widget _buildPdfNavOption({
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor
                : Colors.grey.withValues(alpha: 0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween(begin: 0.9, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child)),
              child: Icon(icon,
                  key: ValueKey(isSelected),
                  color: isSelected ? accentColor : Colors.grey),
            ),
            const SizedBox(height: 4),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? accentColor : Colors.grey,
              ),
              child: Text(title),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildThemeOption({
    required BuildContext context,
    required String title,
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required Color accentColor,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? accentColor
                : Colors.grey.withValues(alpha: 0.2),
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? accentColor.withValues(alpha: 0.1)
              : Colors.transparent,
        ),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => RotationTransition(
                  turns: Tween(begin: 0.9, end: 1.0).animate(anim),
                  child: FadeTransition(opacity: anim, child: child)),
              child: Icon(icon,
                  key: ValueKey(isSelected),
                  color: isSelected ? accentColor : Colors.grey,
                  size: 20),
            ),
            const SizedBox(width: 16),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 300),
              style: GoogleFonts.inter(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected
                    ? accentColor
                    : Theme.of(context).colorScheme.onSurface,
              ),
              child: Text(title),
            ),
            const Spacer(),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              transitionBuilder: (child, anim) => ScaleTransition(
                  scale: anim,
                  child: FadeTransition(opacity: anim, child: child)),
              child: isSelected
                  ? Icon(Icons.check_circle_rounded,
                      key: const ValueKey('check'),
                      color: accentColor,
                      size: 20)
                  : const SizedBox(
                      key: ValueKey('empty'), width: 20, height: 20),
            ),
          ],
        ),
      ),
    );
  }
}
