import 'package:coro_lldm/core/localization/app_strings.dart';
import 'package:coro_lldm/core/monetization/monetization_controller.dart';

String restoreFeedback(RestoreResult result, AppStrings strings) =>
    switch (result) {
      RestoreResult.restored => strings.t(
          'Compras restauradas. Premium está activo.',
          'Purchases restored. Premium is active.'),
      RestoreResult.noPurchase => strings.t(
          'La tienda no encontró una compra Premium activa. Comprueba que usas la cuenta con la que compraste.',
          'The store found no active Premium purchase. Check that you are using the store account you purchased with.'),
      RestoreResult.unavailable => strings.t(
          'No se puede conectar con la tienda en este momento. Inténtalo de nuevo más tarde.',
          'Cannot connect to the store right now. Try again later.'),
      RestoreResult.failed => strings.t(
          'No se pudieron comprobar tus compras. Revisa tu conexión e inténtalo de nuevo.',
          'Your purchases could not be checked. Check your connection and try again.'),
      RestoreResult.busy => strings.t(
          'Espera a que termine la operación actual.',
          'Wait for the current operation to finish.'),
    };
