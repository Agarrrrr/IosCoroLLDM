const fs = require('fs');
const path = require('path');

const extensionCode = `
public extension CAPPluginCall {
    func reject(_ message: String, _ code: String? = nil, _ error: Error? = nil, _ data: [String: Any]? = nil) {
        self.unimplemented(message)
    }
}
`;

function appendExtension(filePath) {
    if (fs.existsSync(filePath)) {
        let content = fs.readFileSync(filePath, 'utf8');
        if (!content.includes('func reject(_ message: String')) {
            fs.appendFileSync(filePath, extensionCode);
            console.log(`Appended extension to ${filePath}`);
        } else {
            console.log(`Extension already in ${filePath}`);
        }
    } else {
        console.log(`File not found: ${filePath}`);
    }
}

// 1. AppPlugin
const appPluginPath = 'node_modules/@capacitor/app/ios/Sources/AppPlugin/AppPlugin.swift';
appendExtension(appPluginPath);

// 2. LegacyFilesystemImplementation
const fsLegacyPath = 'node_modules/@capacitor/filesystem/ios/Sources/FilesystemPlugin/LegacyFilesystemImplementation.swift';
if (fs.existsSync(fsLegacyPath)) {
    let content = fs.readFileSync(fsLegacyPath, 'utf8');
    content = content.replace(/call\.getString\("path"\)/g, 'call.options["path"] as? String');
    content = content.replace(/call\.getString\("url"\)/g, 'call.options["url"] as? String');
    content = content.replace(/\.urlQueryAllowed/g, 'CharacterSet.urlQueryAllowed');
    content = content.replace(/HttpRequestHandler\.setCookiesFromResponse.*/g, '// HttpRequestHandler.setCookiesFromResponse disabled');
    fs.writeFileSync(fsLegacyPath, content);
    console.log(`Patched specific errors in ${fsLegacyPath}`);
}

// 3. FilesystemPlugin
const fsPluginPath = 'node_modules/@capacitor/filesystem/ios/Sources/FilesystemPlugin/FilesystemPlugin.swift';
appendExtension(fsPluginPath);

