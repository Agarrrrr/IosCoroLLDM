import 'package:flutter_test/flutter_test.dart';
import 'package:coro_lldm/features/interactive_score/native_score_document.dart';
import 'package:xml/xml.dart';

void main() {
  test('la voz silenciada atenúa barras, silencios y alteraciones, y conserva texto común', () {
    const svg='''<svg xmlns="http://www.w3.org/2000/svg"><g class="barLine"><path d="M10 0 L10 50"/><path d="M10 50 L10 100"/></g><g id="layer" class="layer"><g class="beam"><polygon id="beam" points="1,2 3,4 5,6"/><g class="note" id="note"><g class="accid"><use id="accidental" href="#sharp"/></g><g class="notehead"><use id="head" href="#n"/></g><g class="verse"><text id="words">Texto común</text></g></g></g><g class="rest"><use id="rest" href="#r"/></g></g></svg>''';
    final doc=XmlDocument.parse(styleScoreSvg({'svg':svg,'roles':{'note':1},'layers':{'layer':1},'muted':[1]}));
    for(final id in ['beam','head','rest','accidental']) {
      expect(doc.descendants.whereType<XmlElement>().singleWhere((e)=>e.getAttribute('id')==id).getAttribute('opacity'),'.20');
    }
    expect(doc.findAllElements('text').single.getAttribute('opacity'),isNull);
    expect(doc.findAllElements('path').every((p)=>p.getAttribute('opacity')=='0'),isTrue);
  });
}
