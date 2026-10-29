/// Lista de cantos retirados permanentemente de la aplicación y del catálogo.
/// Bloquea su aparición en listas, menús, búsqueda, almacenamiento Hive y apertura de PDFs.
const Set<String> kPurgedCantoIds = {
  'usmc_661dccb9d6b0cc15aeab1039', // A Ti, oh Señor
  'usmc_661dd60ad6b0cc15aeab11ea', // Santa Elección
  'usmc_64b5fd5021b21cae02606c33', // Quién Como Tú, Señor!
  'usmc_d0dbd75a3431c8c03f',       // Quien como tu
  'usmc_ee70deb59b27d58c73',       // Es tu Presencia
};

const Set<String> kPurgedCantoNames = {
  'a ti, oh señor',
  'a ti oh señor',
  'a ti, oh senor',
  'a ti oh senor',
  'santa elección',
  'santa eleccion',
  'quién como tú, señor!',
  'quién como tú, señor',
  'quien como tu, señor!',
  'quien como tu, señor',
  'quien como tu',
  'quién como tú',
  'es tu presencia',
};

bool isPurgedCanto(dynamic item) {
  if (item == null) return false;
  if (item is Map) {
    final id = item['id']?.toString() ?? '';
    if (kPurgedCantoIds.contains(id)) return true;
    final nombre = (item['nombre']?.toString() ?? '').toLowerCase().trim();
    if (kPurgedCantoNames.contains(nombre)) return true;
  }
  return false;
}
