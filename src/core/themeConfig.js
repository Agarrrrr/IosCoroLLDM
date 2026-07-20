/**
 * themeConfig.js
 * Configuración dinámica de paletas de colores (CSS variables)
 * Elimina la necesidad de clases estáticas y permite color-mixing.
 */

export const THEMES = {
    claro: {
        '--color-fondo-app': '#fdfdfd',
        '--color-texto-principal': '#333333',
        '--color-superficie': '#ffffff',
        '--color-superficie-secundaria': '#fcfcfc',
        '--color-borde': '#eaeaea',
        '--color-acento': '#d4af37',
        '--color-acento-fuerte': '#8c732a',
        '--color-acento-suave': '#f6f1df',
        '--color-sombra-acento': 'rgba(212, 175, 55, 0.4)',
        '--color-texto-suave': '#666666',
        '--color-input-fondo': '#f5f5f5',
        '--color-input-borde': '#e0e0e0',
        '--color-pdf-fondo': '#f4f4f4',
        '--color-topbar-fondo': 'rgba(255, 255, 255, 0.95)',
        '--color-topbar-borde': '#cccccc',
        '--filtro-canvas': 'none',
        '--color-icono': 'var(--color-texto-principal)',
        '--mix-blend-canvas': 'normal'
    },
    oscuro: {
        '--color-fondo-app': '#11161c',
        '--color-texto-principal': '#f1f5f9',
        '--color-superficie': '#1b2430',
        '--color-superficie-secundaria': '#16202a',
        '--color-borde': '#314052',
        '--color-acento': '#f6d96b',
        '--color-acento-fuerte': '#ffe48f',
        '--color-acento-suave': '#2f3a4a',
        '--color-sombra-acento': 'rgba(246, 217, 107, 0.3)',
        '--color-texto-suave': '#c3cfdb',
        '--color-input-fondo': '#222d3a',
        '--color-input-borde': '#3b4a5d',
        '--color-pdf-fondo': '#1b2430',
        '--color-topbar-fondo': 'rgba(27, 36, 48, 0.95)',
        '--color-topbar-borde': '#314052',
        '--filtro-canvas': 'invert(1) contrast(1.4) brightness(0.9)',
        '--color-icono': 'var(--color-acento)',
        '--mix-blend-canvas': 'screen'
    },
    sepia: {
        '--color-fondo-app': '#f4ecd8',
        '--color-texto-principal': '#5b4636',
        '--color-superficie': '#fdf5e6',
        '--color-superficie-secundaria': '#efe6cf',
        '--color-borde': '#dcd0b9',
        '--color-acento': '#8b5a2b',
        '--color-acento-fuerte': '#5e3a1d',
        '--color-acento-suave': '#e8dbc1',
        '--color-sombra-acento': 'rgba(139, 90, 43, 0.3)',
        '--color-texto-suave': '#8b7355',
        '--color-input-fondo': '#e9e0c9',
        '--color-input-borde': '#d4c8af',
        '--color-pdf-fondo': '#fdf5e6',
        '--color-topbar-fondo': 'rgba(253, 245, 230, 0.95)',
        '--color-topbar-borde': '#dcd0b9',
        '--filtro-canvas': 'none',
        '--color-icono': 'var(--color-acento)',
        '--mix-blend-canvas': 'multiply'
    },
    contraste: {
        '--color-fondo-app': '#000000',
        '--color-texto-principal': '#ffff00',
        '--color-superficie': '#000000',
        '--color-superficie-secundaria': '#111111',
        '--color-borde': '#ffff00',
        '--color-acento': '#ffff00',
        '--color-acento-fuerte': '#ffffff',
        '--color-acento-suave': '#222200',
        '--color-sombra-acento': 'rgba(255, 255, 0, 0.5)',
        '--color-texto-suave': '#cccc00',
        '--color-input-fondo': '#111111',
        '--color-input-borde': '#ffff00',
        '--color-pdf-fondo': '#000000',
        '--color-topbar-fondo': 'rgba(0, 0, 0, 0.95)',
        '--color-topbar-borde': '#ffff00',
        '--filtro-canvas': 'invert(1) grayscale(1) sepia(1) saturate(30) contrast(2) brightness(1.2)',
        '--color-icono': 'var(--color-acento)',
        '--mix-blend-canvas': 'screen'
    },
    oled: {
        '--color-fondo-app': '#000000',
        '--color-texto-principal': '#e2e8f0',
        '--color-superficie': '#000000',
        '--color-superficie-secundaria': '#080808',
        '--color-borde': '#1a1a1a',
        '--color-acento': '#d4af37',
        '--color-acento-fuerte': '#f6d96b',
        '--color-acento-suave': '#111111',
        '--color-sombra-acento': 'rgba(212, 175, 55, 0.3)',
        '--color-texto-suave': '#94a3b8',
        '--color-input-fondo': '#0a0a0a',
        '--color-input-borde': '#222222',
        '--color-pdf-fondo': '#000000',
        '--color-topbar-fondo': 'rgba(0, 0, 0, 0.95)',
        '--color-topbar-borde': '#333333',
        '--filtro-canvas': 'invert(1) contrast(1.5) brightness(1)',
        '--color-icono': 'var(--color-acento)',
        '--mix-blend-canvas': 'screen'
    },
    quiet: {
        '--color-fondo-app': '#3c3f42',
        '--color-texto-principal': '#ffffff',
        '--color-superficie': '#4a4d51',
        '--color-superficie-secundaria': '#3c3f42',
        '--color-borde': '#515457',
        '--color-acento': '#e5e5e7',
        '--color-acento-fuerte': '#ffffff',
        '--color-acento-suave': 'rgba(255, 255, 255, 0.15)',
        '--color-sombra-acento': 'rgba(255, 255, 255, 0.1)',
        '--color-texto-suave': '#aeaeb2',
        '--color-input-fondo': '#4a4d51',
        '--color-input-borde': '#515457',
        '--color-pdf-fondo': '#3c3f42',
        '--color-topbar-fondo': 'rgba(60, 63, 66, 0.95)',
        '--color-topbar-borde': '#515457',
        '--filtro-canvas': 'invert(1) brightness(1.2) contrast(1.1)',
        '--color-icono': 'var(--color-acento)',
        '--mix-blend-canvas': 'screen'
    },
    rosa: {
        '--color-fondo-app': '#ffffff',
        '--color-texto-principal': '#4d3a3d',
        '--color-superficie': '#ffffff',
        '--color-superficie-secundaria': '#fff5f7',
        '--color-borde': '#ffe1e9',
        '--color-acento': '#ffb7c5',
        '--color-acento-fuerte': '#f06292',
        '--color-acento-suave': '#fff0f3',
        '--color-sombra-acento': 'rgba(255, 183, 197, 0.4)',
        '--color-texto-suave': '#8a7074',
        '--color-input-fondo': '#ffffff',
        '--color-input-borde': '#ffe1e9',
        '--color-pdf-fondo': '#ffffff',
        '--color-topbar-fondo': 'rgba(255, 255, 255, 0.95)',
        '--color-topbar-borde': '#ffe1e9',
        '--filtro-canvas': 'none',
        '--color-icono': 'var(--color-acento)',
        '--mix-blend-canvas': 'normal'
    },
    azul: {
        '--color-fondo-app': '#ffffff',
        '--color-texto-principal': '#0a1931',
        '--color-superficie': '#ffffff',
        '--color-superficie-secundaria': '#f0f5ff',
        '--color-borde': '#d1d9e6',
        '--color-acento': '#0047ab',
        '--color-acento-fuerte': '#d4af37',
        '--color-acento-suave': '#e8f0ff',
        '--color-sombra-acento': 'rgba(212, 175, 55, 0.6)',
        '--color-texto-suave': '#5c6b89',
        '--color-input-fondo': '#ffffff',
        '--color-input-borde': '#d1d9e6',
        '--color-pdf-fondo': '#ffffff',
        '--color-topbar-fondo': 'rgba(255, 255, 255, 0.95)',
        '--color-topbar-borde': '#d4af37',
        '--filtro-canvas': 'none',
        '--color-icono': 'var(--color-acento)',
        '--mix-blend-canvas': 'normal'
    },
    jade: {
        '--color-fondo-app': '#ffffff',
        '--color-texto-principal': '#00332a',
        '--color-superficie': '#ffffff',
        '--color-superficie-secundaria': '#f2fbf9',
        '--color-borde': '#c1e1d9',
        '--color-acento': '#00a86b',
        '--color-acento-fuerte': '#008552',
        '--color-acento-suave:': '#e6f7f2',
        '--color-sombra-acento': 'rgba(0, 168, 107, 0.3)',
        '--color-texto-suave': '#3d665e',
        '--color-input-fondo': '#ffffff',
        '--color-input-borde': '#c1e1d9',
        '--color-pdf-fondo': '#ffffff',
        '--color-topbar-fondo': 'rgba(255, 255, 255, 0.95)',
        '--color-topbar-borde': '#c1e1d9',
        '--filtro-canvas': 'none',
        '--color-icono': 'var(--color-acento)',
        '--mix-blend-canvas': 'normal'
    },
    rojo: {
        '--color-fondo-app': '#ffffff',
        '--color-texto-principal': '#3d0a0a',
        '--color-superficie': '#ffffff',
        '--color-superficie-secundaria': '#fff0f0',
        '--color-borde': '#ffcccc',
        '--color-acento': '#ff6b6b',
        '--color-acento-fuerte': '#e03e3e',
        '--color-acento-suave:': '#ffe5e5',
        '--color-sombra-acento': 'rgba(255, 107, 107, 0.3)',
        '--color-texto-suave': '#855c5c',
        '--color-input-fondo': '#ffffff',
        '--color-input-borde': '#ffcccc',
        '--color-pdf-fondo': '#ffffff',
        '--color-topbar-fondo': 'rgba(255, 255, 255, 0.95)',
        '--color-topbar-borde': '#ffcccc',
        '--filtro-canvas': 'none',
        '--color-icono': 'var(--color-acento)',
        '--mix-blend-canvas': 'normal'
    },
    morado: {
        '--color-fondo-app': '#ffffff',
        '--color-texto-principal': '#251642',
        '--color-superficie': '#ffffff',
        '--color-superficie-secundaria': '#f4f0ff',
        '--color-borde': '#dcd0fa',
        '--color-acento': '#9775fa',
        '--color-acento-fuerte': '#7048e8',
        '--color-acento-suave:': '#e5dbff',
        '--color-sombra-acento': 'rgba(151, 117, 250, 0.3)',
        '--color-texto-suave': '#5c4b82',
        '--color-input-fondo': '#ffffff',
        '--color-input-borde': '#dcd0fa',
        '--color-pdf-fondo': '#ffffff',
        '--color-topbar-fondo': 'rgba(255, 255, 255, 0.95)',
        '--color-topbar-borde': '#dcd0fa',
        '--filtro-canvas': 'none',
        '--color-icono': 'var(--color-acento)',
        '--mix-blend-canvas': 'normal'
    }
};

export const THEME_BASE_PROPS = {
    '--tema-transicion': 'background-color 0.3s ease, color 0.3s ease, border-color 0.3s ease'
};

export function getThemeColors(nombreTema) {
    if (THEMES[nombreTema]) return THEMES[nombreTema];
    const customThemes = getCustomThemes();
    if (customThemes[nombreTema]) return customThemes[nombreTema];
    return THEMES['claro'];
}

export function getAllThemes() {
    const customThemes = getCustomThemes();
    return [...Object.keys(THEMES), ...Object.keys(customThemes)];
}

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
