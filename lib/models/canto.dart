class Canto {
  final String id;
  final String nombre;
  final String archivo;
  final List<String> temas;
  final String? midiArchivo;

  /// ID y versión del canto que posee físicamente el MIDI. Normalmente
  /// coinciden con este canto; pueden apuntar a su contraparte bilingüe.
  final String? midiSourceId;
  final int? midiSourceVersion;

  /// Idioma del canto: 'es' (Español) o 'en' (Inglés).
  /// Se asigna según el catálogo de origen (catalogo.json / catalogo_en.json).
  final String idioma;

  /// ID del canto vinculado en el otro idioma (versión bilingüe).
  final String? vinculoIdioma;
  final String? updatedAt;
  final int version;
  final int cifradoVersion;

  Canto({
    required this.id,
    required this.nombre,
    required this.archivo,
    required this.temas,
    this.midiArchivo,
    this.midiSourceId,
    this.midiSourceVersion,
    this.idioma = 'es',
    this.vinculoIdioma,
    this.updatedAt,
    this.version = 1,
    this.cifradoVersion = 1,
  });

  factory Canto.fromJson(Map<String, dynamic> json) {
    return Canto(
      id: json['id'].toString(),
      nombre: json['nombre'] as String? ?? '',
      archivo: json['archivo'] as String? ?? '',
      temas: (json['temas'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      midiArchivo: json['midi_archivo'] as String?,
      midiSourceId: json['_midi_source_id'] as String?,
      midiSourceVersion: (json['_midi_source_version'] as num?)?.toInt(),
      idioma: json['_idioma'] as String? ?? json['idioma'] as String? ?? 'es',
      vinculoIdioma: json['vinculo_idioma'] as String?,
      updatedAt:
          json['updated_at']?.toString() ?? json['updatedAt']?.toString(),
      version: (json['version'] as num?)?.toInt() ?? 1,
      cifradoVersion: (json['cifrado_version'] as num?)?.toInt() ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'archivo': archivo,
      'temas': temas,
      if (midiArchivo != null) 'midi_archivo': midiArchivo,
      if (midiSourceId != null) '_midi_source_id': midiSourceId,
      if (midiSourceVersion != null) '_midi_source_version': midiSourceVersion,
      '_idioma': idioma,
      if (vinculoIdioma != null) 'vinculo_idioma': vinculoIdioma,
      'version': version,
      'cifrado_version': cifradoVersion,
    };
  }

  String get effectiveMidiSourceId => midiSourceId ?? id;
  int get effectiveMidiVersion => midiSourceVersion ?? version;

  /// Conserva la partitura y su idioma, pero reutiliza el arreglo musical de
  /// una contraparte explícitamente vinculada.
  Canto withMidiFrom(Canto source) {
    return Canto(
      id: id,
      nombre: nombre,
      archivo: archivo,
      temas: temas,
      midiArchivo: source.midiArchivo,
      midiSourceId: source.effectiveMidiSourceId,
      midiSourceVersion: source.effectiveMidiVersion,
      idioma: idioma,
      vinculoIdioma: vinculoIdioma,
      updatedAt: updatedAt,
      version: version,
      cifradoVersion: cifradoVersion,
    );
  }
}
