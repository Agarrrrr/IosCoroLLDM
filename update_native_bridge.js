const fs = require('fs');
const path = 'src/core/nativePdfBridge.js';
let content = fs.readFileSync(path, 'utf8');

content = content.replace(/return \`android_asset\/public\/pdfs\/\$\{archivo\}\`;/g, 
`            if (Capacitor.getPlatform() === 'ios') {
                return \`public/pdfs/\${archivo}\`; // iOS plugin handle relative path
            } else {
                return \`android_asset/public/pdfs/\${archivo}\`;
            }`);

fs.writeFileSync(path, content);
