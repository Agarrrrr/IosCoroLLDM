import 'package:coro_lldm/core/providers/cantos_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coro_lldm/core/providers/favoritos_provider.dart';

void main() {
  test('Buscar activa Todos los cantos y no recupera el filtro al limpiar', () {
    final scope = ProviderContainer();
    addTearDown(scope.dispose);
    scope.read(categoryFilterProvider.notifier).set('tema_Alabanza');
    scope.read(soloFavoritosProvider.notifier).set(true);
    scope.read(searchTextProvider.notifier).set('   ');
    expect(scope.read(categoryFilterProvider), 'tema_Alabanza');
    scope.read(searchTextProvider.notifier).set('Salmo');
    expect(scope.read(categoryFilterProvider), '');
    expect(scope.read(soloFavoritosProvider), isFalse);
    scope.read(searchTextProvider.notifier).set('');
    expect(scope.read(categoryFilterProvider), '');
    expect(scope.read(soloFavoritosProvider), isFalse);
  });
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
