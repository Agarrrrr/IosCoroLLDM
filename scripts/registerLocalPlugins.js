import fs from 'fs';
import path from 'path';

const configPath = path.resolve('ios/App/App/capacitor.config.json');

try {
    if (fs.existsSync(configPath)) {
        const configContent = fs.readFileSync(configPath, 'utf8');
        const config = JSON.parse(configContent);
        
        if (!config.packageClassList) {
            config.packageClassList = [];
        }
        
        if (!config.packageClassList.includes("NativePDFPlugin")) {
            config.packageClassList.push("NativePDFPlugin");
            console.log('[registerLocalPlugins] Added NativePDFPlugin to packageClassList');
        }
        
        if (!config.packageClassList.includes("NativeAudioPlugin")) {
            config.packageClassList.push("NativeAudioPlugin");
            console.log('[registerLocalPlugins] Added NativeAudioPlugin to packageClassList');
        }
        
        fs.writeFileSync(configPath, JSON.stringify(config, null, '\t'), 'utf8');
        console.log('[registerLocalPlugins] Successfully updated capacitor.config.json');
    } else {
        console.error('[registerLocalPlugins] capacitor.config.json not found at:', configPath);
    }
} catch (e) {
    console.error('[registerLocalPlugins] Error updating capacitor.config.json:', e);
}
