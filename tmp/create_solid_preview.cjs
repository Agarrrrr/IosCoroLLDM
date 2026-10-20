const fs=require('fs');
let s=fs.readFileSync('tmp/theme_preview_test.dart','utf8');
s=s.replaceAll('s.onSecondaryContainer','s.onSecondary').replaceAll('s.secondaryContainer','s.secondary');
s=s.replace('border:Border.all(color:s.secondary,width:2),','');
s=s.replace('themes-2026-10-09.png','themes-solid-2026-10-09.png').replace('contrast-2026-10-09.json','contrast-solid-2026-10-09.json');
fs.writeFileSync('tmp/theme_solid_preview_test.dart',s);
