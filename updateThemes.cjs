const fs = require('fs');
let content = fs.readFileSync('src/core/themeConfig.js', 'utf8');

const regexClaro = /(claro:\s*\{[\s\S]*?)('--mix-blend-canvas':\s*'[^']+')(.*?)/;
content = content.replace(regexClaro, "$1'--color-icono': 'var(--color-texto-principal)',\n        $2$3");

const regexOthers = /([a-z]+:\s*\{[\s\S]*?)('--mix-blend-canvas':\s*'[^']+')(.*?)/g;
content = content.replace(regexOthers, (match, p1, p2, p3) => {
    if (p1.includes('claro:')) return match;
    return p1 + "'--color-icono': 'var(--color-acento)',\n        " + p2 + p3;
});

// Append custom theme logic
content += `
export function getCustomThemes() {
    try {
        const stored = localStorage.getItem('custom_themes');
        return stored ? JSON.parse(stored) : {};
    } catch (e) {
        return {};
    }
}

export function saveCustomTheme(name, themeData) {
    const customThemes = getCustomThemes();
    customThemes[name] = themeData;
    localStorage.setItem('custom_themes', JSON.stringify(customThemes));
}

export function deleteCustomTheme(name) {
    const customThemes = getCustomThemes();
    delete customThemes[name];
    localStorage.setItem('custom_themes', JSON.stringify(customThemes));
}
`;

// Replace getThemeColors and getAllThemes
content = content.replace(/export function getThemeColors[\s\S]*?export function getAllThemes\(\) \{\n    return Object.keys\(THEMES\);\n\}/, `export function getThemeColors(nombreTema) {
    if (THEMES[nombreTema]) return THEMES[nombreTema];
    const customThemes = getCustomThemes();
    if (customThemes[nombreTema]) return customThemes[nombreTema];
    return THEMES['claro'];
}

export function getAllThemes() {
    const customThemes = getCustomThemes();
    return [...Object.keys(THEMES), ...Object.keys(customThemes)];
}`);

fs.writeFileSync('src/core/themeConfig.js', content);
console.log("Updated themes successfully!");
