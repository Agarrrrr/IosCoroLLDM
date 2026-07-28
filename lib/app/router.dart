import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:coro_lldm/features/dashboard/dashboard_screen.dart';
import 'package:coro_lldm/features/visor/visor_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: '/visor/:id',
        builder: (context, state) {
          final id = state.pathParameters['id']!;
          return VisorScreen(
            cantoId: id,
            ignorePreferredLanguage:
                state.uri.queryParameters['manualLanguage'] == '1',
          );
        },
      ),
    ],
  );
});
