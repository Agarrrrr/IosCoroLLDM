class Canto {
  final String id;
  final String nombre;
  final String archivo;
  final List<String> temas;
  final String? midiArchivo;

  /// Idioma del canto: 'es' (Español) o 'en' (Inglés).
  /// Se asigna según el catálogo de origen (catalogo.json / catalogo_en.json).
  final String idioma;

  /// ID del canto vinculado en el otro idioma (versión bilingüe).
  final String? vinculoIdioma;
  final String? updatedAt;

  Canto({
    required this.id,
    required this.nombre,
    required this.archivo,
    required this.temas,
    this.midiArchivo,
    this.idioma = 'es',
    this.vinculoIdioma,
    this.updatedAt,
  });

  factory Canto.fromJson(Map<String, dynamic> json) {
    return Canto(
      id: json['id'].toString(),
      nombre: json['nombre'] as String? ?? '',
      archivo: json['archivo'] as String? ?? '',
      temas: (json['temas'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      midiArchivo: json['midi_archivo'] as String?,
      idioma: json['_idioma'] as String? ?? 'es',
      vinculoIdioma: json['vinculo_idioma'] as String?,
      updatedAt: json['updated_at']?.toString() ?? json['updatedAt']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'archivo': archivo,
      'temas': temas,
      if (midiArchivo != null) 'midi_archivo': midiArchivo,
      '_idioma': idioma,
      if (vinculoIdioma != null) 'vinculo_idioma': vinculoIdioma,
    };
  }
}
