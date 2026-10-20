const fs=require('fs');
const p='lib/features/visor/visor_screen.dart';
let s=fs.readFileSync(p,'utf8');
const start=s.indexOf('    // Evaluamos el brillo del sistema directamente');
const end=s.indexOf('    return PopScope(',start);
if(start<0||end<0)throw Error('Missing filter block');
const filters=[...s.slice(start,end).matchAll(/const (\w+) = ColorFilter.matrix\((\[[\s\S]*?\])\);/g)];
if(filters.length!==4)throw Error('Expected four existing filters');
let content=`import 'package:flutter/material.dart';
import 'package:coro_lldm/core/providers/theme_provider.dart';

/// Shared paper and toolbar palette. Existing filter matrices are unchanged.
abstract final class PdfThemePalette {
  static Color background(AppThemeMode mode) => switch (mode) {
    AppThemeMode.claro => Colors.white,
    AppThemeMode.oscuro => Colors.black,
    AppThemeMode.oscuroNormal => const Color(0xFF1B2430),
    AppThemeMode.sepia => const Color(0xFFF4ECD8),
    AppThemeMode.quiet => const Color(0xFF3C3F42),
  };
  static ColorFilter? filter(AppThemeMode mode) => switch (mode) {
    AppThemeMode.claro => null,
    AppThemeMode.oscuro => invertFilter,
    AppThemeMode.oscuroNormal => normalDarkFilter,
    AppThemeMode.sepia => sepiaFilter,
    AppThemeMode.quiet => quietFilter,
  };
`;
for(const f of filters)content+='  static const '+f[1]+' = ColorFilter.matrix('+f[2]+');\n';
content+='}\n';
s=s.slice(0,start)+s.slice(end);
s=s.replace("import 'package:coro_lldm/features/visor/widgets/pdf_color_filter.dart';","import 'package:coro_lldm/features/visor/widgets/pdf_color_filter.dart';\nimport 'package:coro_lldm/features/visor/widgets/pdf_theme_palette.dart';");
const re=/colorFilter: isDark[\s\S]*?: null\),/;
if(!re.test(s))throw Error('Missing selection expression');
s=s.replace(re,'colorFilter: PdfThemePalette.filter(themeMode),');
const bg=/color: theme.appBarTheme.backgroundColor \?\?\r?\n\s*theme.scaffoldBackgroundColor,/;
if(!bg.test(s))throw Error('Missing topbar color');
s=s.replace(bg,'color: PdfThemePalette.background(themeMode),');
fs.writeFileSync('lib/features/visor/widgets/pdf_theme_palette.dart',content);
fs.writeFileSync(p,s);
console.log('Four existing matrices extracted unchanged; toolbar uses paper background.');
