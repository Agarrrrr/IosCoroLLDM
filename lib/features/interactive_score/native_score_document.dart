import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:jovial_svg/jovial_svg.dart';
import 'package:verovio_flutter/verovio_flutter.dart';
import 'package:xml/xml.dart';

class NativeScorePage {
  final String svg;
  final PageHitMap hitMap;
  final Map<String, int> layerRoles;
  NativeScorePage(this.svg, this.hitMap, this.layerRoles);
}

/// The C++ toolkit lives in its own worker isolate. No browser or JS bridge.
class NativeScoreDocument {
  final List<VerovioAsyncService> _sections = [];
  final List<({int section, int page})> _pages = [];
  final Map<int, Future<NativeScorePage>> _cache = {};
  final Map<(int, int), Future<ScalableImage>> _visuals = {};
  final Map<String, int> _notePages = {};
  final Map<int, Map<String, int>> _layerRoles = {};
  late Map<String, int> noteRoles;
  bool disposed = false;
  int get pageCount => _pages.length;

  Future<void> load(String xml, String layout, List<dynamic> events,
      double width) async {
    noteRoles = {for (final e in events) e['id'] as String: e['role'] as int};
    final inputs = await compute(_sectionInputs, {'xml': xml, 'layout': layout});
    final resources = await VerovioResourceManager.ensureVerovioAssetsReady();
    for (final input in inputs) {
      if (disposed) return;
      final worker = await VerovioAsyncService.spawn(resourcePath: resources);
      _sections.add(worker);
      await worker.setOptionsJson(jsonEncode({
        'scale': 36, 'pageWidth': (width * 100 / 36).round(),
        'pageHeight': 1750, 'adjustPageHeight': true, 'breaks': 'auto',
        'header': 'none', 'footer': 'none', 'font': 'Leipzig',
        'condense': 'none', 'lyricSize': 3.6, 'lyricWordSpace': 2.5,
        'spacingStaff': 14, 'spacingSystem': 16, 'svgViewBox': true,
        'xmlIdSeed': 17,
      }));
      await worker.loadData(input);
      final mei = await worker.getMei('{}');
      final prepared = await compute(_prepareMei,
          {'mei': mei, 'xml': input, 'roles': noteRoles});
      await worker.loadData(prepared['mei'] as String);
      _layerRoles[_sections.length - 1] =
          Map<String, int>.from(prepared['layers'] as Map);
      final count = await worker.pageCount;
      for (var page = 1; page <= count; page++) {
        _pages.add((section: _sections.length - 1, page: page));
      }
    }
  }

  Future<NativeScorePage> page(int index) => _cache.putIfAbsent(index, () async {
    final ref = _pages[index];
    final result = await _sections[ref.section].renderPageWithHitMap(ref.page,
        config: const ParseConfig(captureClasses: {'note', 'notehead', 'system'},
            buildSpatialIndex: false));
    final svg = await compute(styleScoreSvg, {
      'svg': result.svg, 'roles': noteRoles,
      'layers': _layerRoles[ref.section]!, 'muted': <int>[],
    });
    for (final hit in result.hitMap.byId.values) {
      if (hit.type == 'note') _notePages[hit.id] = index;
    }
    return NativeScorePage(svg, result.hitMap, _layerRoles[ref.section]!);
  });

  /// Keep only a small working set of compiled vectors. Preparing the next
  /// page ahead of playback avoids parsing its SVG during the page animation.
  Future<ScalableImage> visual(int index, int mask) {
    final key = (index, mask);
    final cached = _visuals.remove(key);
    if (cached != null) {
      _visuals[key] = cached;
      return cached;
    }
    final future = () async {
      final data = await page(index);
      final svg = mask == 0 ? data.svg : await compute(styleScoreSvg, {
        'svg': data.svg, 'roles': noteRoles, 'layers': data.layerRoles,
        'muted': [for (var i = 0; i < 4; i++) if (mask & (1 << i) != 0) i],
      });
      return SchedulerBinding.instance.scheduleTask(() {
        final timer = Stopwatch()..start();
        final image = ScalableImage.fromSvgString(svg,
            warnF: (warning) => debugPrint('NATIVE_SVG $warning'));
        debugPrint('NATIVE_PAGE $index parseMs=${timer.elapsedMilliseconds}');
        return image;
      }, Priority.animation);
    }();
    _visuals[key] = future;
    if (_visuals.length > 6) _visuals.remove(_visuals.keys.first);
    return future;
  }

  Future<int?> pageFor(String id, int measure) async {
    if (disposed) return null;
    if (_notePages.containsKey(id)) return _notePages[id];
    final section = _sections.length == 2 && measure > 8 ? 1 : 0;
    final page = await _sections[section].getPageWithElement(id);
    final index = _pages.indexWhere((p) => p.section == section && p.page == page);
    if (index < 0) return null;
    _notePages[id] = index;
    return index;
  }

  Future<void> dispose() async {
    disposed = true;
    for (final worker in _sections) { await worker.dispose(); }
    _cache.clear();
    _visuals.clear();
    _notePages.clear();
  }
}

List<String> _sectionInputs(Map<String, String> args) {
  if (args['layout'] != 'mixed') return [args['xml']!];
  final result = <String>[];
  for (var half = 0; half < 2; half++) {
    final doc = XmlDocument.parse(args['xml']!);
    for (final part in doc.rootElement.findElements('part').toList()) {
      if (half == 0 && part.getAttribute('id') == 'P1') {
        part.parent!.children.remove(part); continue;
      }
      final measures = part.findElements('measure').toList();
      final attributes = measures.first.getElement('attributes')!.copy();
      for (var i = 0; i < measures.length; i++) {
        if (half == 0 ? i >= 8 : i < 8) part.children.remove(measures[i]);
      }
      if (half == 1) part.findElements('measure').first.children.insert(0, attributes);
    }
    final list = doc.rootElement.getElement('part-list')!;
    if (half == 0) {
      list.children.removeWhere((n) => n is XmlElement && n.getAttribute('id') == 'P1');
    } else {
      list.findElements('score-part').firstWhere((p) => p.getAttribute('id') == 'P2')
          .getElement('part-name')!.innerText = 'A';
    }
    result.add(doc.toXmlString());
  }
  return result;
}

Map<String, dynamic> _prepareMei(Map<String, dynamic> args) {
  final mei = XmlDocument.parse(args['mei'] as String);
  final source = XmlDocument.parse(args['xml'] as String);
  final roles = Map<String, int>.from(args['roles'] as Map);
  final above = <String, Set<String>>{};
  for (final n in source.findAllElements('note')) {
    final verses = n.findElements('lyric').where((l) => l.getAttribute('placement') == 'above')
        .map((l) => l.getAttribute('number') ?? '1').toSet();
    if (verses.isNotEmpty) above[n.getAttribute('id')!] = verses;
  }
  for (final n in mei.findAllElements('note')) {
    final set = above[n.getAttribute('xml:id')];
    if (set != null) {
      for (final v in n.findElements('verse')) {
        if (set.contains(v.getAttribute('n'))) v.setAttribute('place', 'above');
      }
    }
  }
  final voices = <String, int>{}, layers = <String, int>{};
  String identity(XmlElement l) => '${(l.parent as XmlElement).getAttribute('n')}:${l.getAttribute('n')}';
  for (final layer in mei.findAllElements('layer')) {
    for (final note in layer.findAllElements('note')) {
      final role = roles[note.getAttribute('xml:id')];
      if (role != null) { voices[identity(layer)] = role; break; }
    }
  }
  for (final tag in ['tie','slur']) {
    for (final mark in mei.findAllElements(tag)) {
      final role = roles[mark.getAttribute('startid')?.replaceFirst('#', '')];
      final id = mark.getAttribute('xml:id');
      if (role != null && id != null) layers[id] = role;
    }
  }
  for (final layer in mei.findAllElements('layer')) {
    final role = voices[identity(layer)];
    if (role != null) layers[layer.getAttribute('xml:id')!] = role;
  }
  return {'mei': mei.toXmlString(), 'layers': layers};
}

/// This transformation only runs when a page loads or its voice mask changes.
/// Playback cursor frames never parse or rewrite the SVG.
String styleScoreSvg(Map<String, dynamic> args) {
  final doc = XmlDocument.parse(args['svg'] as String);
  // Verovio nests a coordinate-space SVG inside the outer viewport. Flutter's
  // SVG painter needs an ordinary group with the equivalent viewport scale.
  final root = doc.rootElement;
  final outer = (root.getAttribute('viewBox') ?? '').split(RegExp(r'\s+')).map(double.tryParse).toList();
  for (final nested in root.findElements('svg').toList()) {
    final inner = (nested.getAttribute('viewBox') ?? '').split(RegExp(r'\s+')).map(double.tryParse).toList();
    if (outer.length == 4 && inner.length == 4 && !outer.contains(null) && !inner.contains(null)) {
      final scale = outer[2]! / inner[2]!;
      final group = XmlElement(XmlName('g'), [XmlAttribute(XmlName('transform'), 'scale($scale)')]);
      for (final attr in nested.attributes.where((a) => !{'viewBox','width','height'}.contains(a.name.local))) {
        group.attributes.add(attr.copy());
      }
      group.children.addAll(nested.children.map((n) => n.copy()));
      final index = root.children.indexOf(nested);root.children[index] = group;
    }
  }
  final roles = Map<String, int>.from(args['roles'] as Map);
  final layers = Map<String, int>.from(args['layers'] as Map);
  final muted = Set<int>.from(args['muted'] as List);
  // Resolve Verovio's CSS into SVG attributes for the native Flutter painter.
  // Staff lines and stems otherwise have no stroke outside a browser CSS DOM.
  for (final element in doc.descendants.whereType<XmlElement>()) {
    if ({'path','ellipse','polygon','polyline','rect'}.contains(element.name.local)) {
      if (element.getAttribute('stroke') == null || element.getAttribute('stroke') == 'currentColor') {
        element.setAttribute('stroke', '#24211c');
      }
    }
    final classes = (element.getAttribute('class') ?? '').split(' ');
    if (classes.any({'ending','fing','reh','tempo'}.contains)) element.setAttribute('font-weight', 'bold');
    if (classes.any({'dir','dynam','mNum'}.contains)) element.setAttribute('font-style', 'italic');
    if (element.name.local == 'tspan' && element.innerText.contains('\uE551')) {
      // SMuFL lyricsElision uses a private glyph; use its standard text form.
      element.innerText = element.innerText.replaceAll('\uE551', '\u203F');
      element.setAttribute('font-family', 'ScoreText');
      element.setAttribute('font-size', '300px');
    }
    if (element.getAttribute('style')?.contains('font-family:') == true) {
      element.removeAttribute('style');
      element.setAttribute('font-family', 'ScoreText');
    }
    if (element.getAttribute('font-family') != null || {'text','tspan'}.contains(element.name.local)) {
      element.setAttribute('font-family', 'ScoreText');
    }
  }
  for (final style in doc.findAllElements('style').toList()) {style.parent!.children.remove(style);}
  for (final g in doc.findAllElements('g')) {
    if (g.getAttribute('class') == 'barLine') {
      final paths = g.findElements('path').toList();
      final xs = paths.map((p) => RegExp(r'^M\s*(-?[\d.]+)').firstMatch(p.getAttribute('d') ?? '')?.group(1)).toSet();
      if (g.findElements('use').isEmpty && paths.isNotEmpty && xs.length == 1 && !xs.contains(null)) {
        for (final p in paths) {p.setAttribute('opacity', '0');}
      }
    }
  }
  for (final node in doc.descendants.whereType<XmlElement>()) {
    if (!{'path', 'use', 'polygon', 'polyline', 'line', 'ellipse', 'circle'}.contains(node.name.local)) continue;
    int? role;
    var lyric = false;
    for (final ancestor in node.ancestors.whereType<XmlElement>()) {
      final classes = (ancestor.getAttribute('class') ?? '').split(' ');
      if (classes.any({'verse', 'syl', 'lyric'}.contains)) {lyric = true; break;}
      if (classes.contains('note')) role ??= roles[ancestor.getAttribute('id')];
      if (classes.contains('layer')) role ??= layers[ancestor.getAttribute('id')];
      if (classes.contains('tie') || classes.contains('slur')) role ??= layers[ancestor.getAttribute('id')];
    }
    if (!lyric && role != null && muted.contains(role)) node.setAttribute('opacity', '.20');
  }
  return doc.toXmlString();
}
