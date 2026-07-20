const fs = require('fs');

const pluginCallPath = 'node_modules/@capacitor/ios/Capacitor/Capacitor/CAPPluginCall.swift';
if (fs.existsSync(pluginCallPath)) {
    let content = fs.readFileSync(pluginCallPath, 'utf8');
    content = content.replace(/    func reject\(/g, '    public func reject(');
    content = content.replace(/    func resolve\(/g, '    public func resolve(');
    content = content.replace(/    func unimplemented\(/g, '    public func unimplemented(');
    content = content.replace(/    func unavailable\(/g, '    public func unavailable(');
    content = content.replace(/    func hasOption\(/g, '    public func hasOption(');
    fs.writeFileSync(pluginCallPath, content);
    console.log('Patched CAPPluginCall.swift');
} else {
    console.log('CAPPluginCall.swift not found');
}

const jsTypesPath = 'node_modules/@capacitor/ios/Capacitor/Capacitor/JSTypes.swift';
if (fs.existsSync(jsTypesPath)) {
    let content = fs.readFileSync(jsTypesPath, 'utf8');
    content = content.replace(/^extension JS/gm, 'public extension JS');
    fs.writeFileSync(jsTypesPath, content);
    console.log('Patched JSTypes.swift');
} else {
    console.log('JSTypes.swift not found');
}
