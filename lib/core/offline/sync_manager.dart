import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:coro_lldm/core/offline/offline_files.dart';
import 'package:coro_lldm/core/providers/cantos_provider.dart';

class SyncState {
  final bool isSyncing;
  final int totalFiles;
  final int downloadedFiles;
  final String currentItemName;

  SyncState({
    this.isSyncing = false,
    this.totalFiles = 0,
    this.downloadedFiles = 0,
    this.currentItemName = '',
  });

  SyncState copyWith({
    bool? isSyncing,
    int? totalFiles,
    int? downloadedFiles,
    String? currentItemName,
  }) {
    return SyncState(
      isSyncing: isSyncing ?? this.isSyncing,
      totalFiles: totalFiles ?? this.totalFiles,
      downloadedFiles: downloadedFiles ?? this.downloadedFiles,
      currentItemName: currentItemName ?? this.currentItemName,
    );
  }

  double get progress => totalFiles == 0 ? 0 : downloadedFiles / totalFiles;
}

/// Reporte de estado del caché offline.
///
/// Las descargas de PDF/MIDI son bajo demanda (ver [OfflineFiles]); este
/// notifier solo contabiliza cuántas partituras del catálogo ya están
/// disponibles localmente para mostrarlo en el drawer.
class SyncManagerNotifier extends Notifier<SyncState> {
  @override
  SyncState build() {
    ref.listen(cantosBaseProvider, (previous, next) {
      if (next.value != null) {
        _recount(next.value!);
      }
    });

    final initial = ref.read(cantosBaseProvider).value;
    if (initial != null && initial.isNotEmpty) {
      Future.microtask(() => _recount(initial));
    }

    return SyncState();
  }

  /// Recuenta las partituras presentes en disco. Se puede llamar tras
  /// completar una descarga bajo demanda para refrescar el indicador.
  Future<void> refresh() async {
    final cantos = ref.read(cantosBaseProvider).value;
    if (cantos != null) await _recount(cantos);
  }

  Future<void> _recount(List<dynamic> cantos) async {
    int cached = 0;
    for (final canto in cantos) {
      try {
        final pdf = await OfflineFiles.pdfFile(canto.id);
        if (await pdf.exists()) cached++;
      } catch (_) {}
    }
    state = state.copyWith(
      isSyncing: false,
      totalFiles: cantos.length,
      downloadedFiles: cached,
      currentItemName: '',
    );
  }
}

final syncManagerProvider = NotifierProvider<SyncManagerNotifier, SyncState>(SyncManagerNotifier.new);
