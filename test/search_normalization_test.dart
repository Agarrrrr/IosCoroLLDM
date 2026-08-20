import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalización numérica de búsqueda', () {
    test('unifica dígitos con números escritos en español', () {
      expect(normalizeSearchText('Salmo 125'), 'salmo 125');
      expect(normalizeSearchText('Salmo ciento veinticinco'), 'salmo 125');
      expect(normalizeSearchText('Veinticinco'), '25');
    });

    test('unifica dígitos con números escritos en inglés', () {
      expect(normalizeSearchText('Psalm 125'), 'psalm 125');
      expect(normalizeSearchText('Psalm one hundred twenty-five'), 'psalm 125');
      expect(normalizeSearchText('Twenty five'), '25');
    });
  });
}
