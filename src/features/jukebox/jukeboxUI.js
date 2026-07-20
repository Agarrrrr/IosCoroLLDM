import { jukeboxController } from './jukeboxController.js';
import { i18n } from '../../core/i18n.js';

export const jukeboxUI = {
    modal: null,
    
    inicializar() {
        if (!document.getElementById('modal-jukebox-app')) {
            this.inyectarDOM();
            i18n.updateDOM();
        }
        
        this.modal = document.getElementById('modal-jukebox-app');
        this.bindEvents();
    },

    inyectarDOM() {
        const div = document.createElement('div');
        div.id = 'modal-jukebox-app';
        div.className = 'modal-jukebox';
        div.innerHTML = `
            <div class="jukebox-header">
                <button id="btn-cerrar-jukebox" class="btn-cerrar-ico">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="6 9 12 15 18 9"></polyline></svg>
                </button>
            </div>
            
            <div class="jukebox-playlist-container">
                <div class="jukebox-search-wrapper">
                    <input type="text" id="jukebox-buscador" placeholder="Buscar canto..." data-i18n-placeholder="jukebox.buscar" autocomplete="off">
                </div>
                <ul id="jukebox-lista-cantos" class="jukebox-lista"></ul>
            </div>

            <div class="jukebox-info">
                <h2 id="jukebox-titulo" class="jukebox-title">Selecciona un canto</h2>
                <p id="jukebox-autor" class="jukebox-author">Repertorio BC</p>
            </div>

            <div class="jukebox-progress">
                <div class="jukebox-progress-bar-bg" id="jukebox-progress-bg">
                    <div id="jukebox-progress-fill" class="jukebox-progress-bar-fill"></div>
                </div>
                <div class="jukebox-progress-times">
                    <span id="jukebox-time-current">0:00</span>
                    <span id="jukebox-time-total">-:--</span>
                </div>
            </div>

            <div class="jukebox-controls">
                <button id="btn-jukebox-shuffle" class="jukebox-btn secundario">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="16 3 21 3 21 8"></polyline><line x1="4" y1="20" x2="21" y2="3"></line><polyline points="21 16 21 21 16 21"></polyline><line x1="15" y1="15" x2="21" y2="21"></line><line x1="4" y1="4" x2="9" y2="9"></line></svg>
                </button>
                <button id="btn-jukebox-prev" class="jukebox-btn">
                    <svg width="36" height="36" viewBox="0 0 24 24" fill="var(--color-texto-principal)" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"><polygon points="19 20 9 12 19 4 19 20"></polygon><line x1="5" y1="19" x2="5" y2="5"></line></svg>
                </button>
                <button id="btn-jukebox-play" class="jukebox-btn jukebox-btn-play">
                    <svg id="icon-play" width="32" height="32" viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"><polygon points="5 3 19 12 5 21 5 3"></polygon></svg>
                    <svg id="icon-pause" style="display: none;" width="32" height="32" viewBox="0 0 24 24" fill="currentColor" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"><rect x="6" y="4" width="4" height="16"></rect><rect x="14" y="4" width="4" height="16"></rect></svg>
                </button>
                <button id="btn-jukebox-next" class="jukebox-btn">
                    <svg width="36" height="36" viewBox="0 0 24 24" fill="var(--color-texto-principal)" stroke="currentColor" stroke-width="1" stroke-linecap="round" stroke-linejoin="round"><polygon points="5 4 15 12 5 20 5 4"></polygon><line x1="19" y1="5" x2="19" y2="19"></line></svg>
                </button>
                <button id="btn-jukebox-repeat" class="jukebox-btn secundario">
                    <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="17 1 21 5 17 9"></polyline><path d="M3 11V9a4 4 0 0 1 4-4h14"></path><polyline points="7 23 3 19 7 15"></polyline><path d="M21 13v2a4 4 0 0 1-4 4H3"></path></svg>
                </button>
            </div>
        `;
        document.body.appendChild(div);
    },

    bindEvents() {
        document.getElementById('btn-cerrar-jukebox').onclick = () => {
            this.modal.classList.remove('activo');
            jukeboxController.cerrar();
        };

        document.getElementById('btn-jukebox-play').onclick = () => {
            if (jukeboxController.isPlaying) {
                jukeboxController.pause();
            } else {
                jukeboxController.resume();
            }
        };

        document.getElementById('btn-jukebox-next').onclick = () => jukeboxController.nextTrack();
        document.getElementById('btn-jukebox-prev').onclick = () => jukeboxController.prevTrack();
        
        document.getElementById('btn-jukebox-shuffle').onclick = (e) => {
            jukeboxController.toggleShuffle();
            e.currentTarget.classList.toggle('activo', jukeboxController.isShuffle);
        };
        
        document.getElementById('btn-jukebox-repeat').onclick = (e) => {
            jukeboxController.toggleRepeat();
            e.currentTarget.classList.toggle('activo', jukeboxController.isRepeat);
        };
        
        // Progress bar seek
        const bg = document.getElementById('jukebox-progress-bg');
        bg.onclick = (e) => {
            const rect = bg.getBoundingClientRect();
            const percent = Math.max(0, Math.min(100, ((e.clientX - rect.left) / rect.width) * 100));
            jukeboxController.seek(percent);
        };
        
        // Buscador de playlist
        const inputBuscador = document.getElementById('jukebox-buscador');
        inputBuscador.oninput = (e) => {
            jukeboxController.filtrarLista(e.target.value);
        };
    },

    renderizarPlaylist(cantos, currentIndex) {
        const lista = document.getElementById('jukebox-lista-cantos');
        lista.innerHTML = '';
        
        cantos.forEach((canto, idx) => {
            const li = document.createElement('li');
            li.className = 'jukebox-lista-item' + (idx === currentIndex ? ' activo' : '');
            
            const temasStr = (canto.temas && canto.temas.length > 0) ? canto.temas.join(', ') : 'Repertorio BC';
            
            li.innerHTML = `
                <div class="item-info">
                    <div class="item-titulo">${canto.titulo || canto.nombre}</div>
                    <div class="item-autor">${temasStr}</div>
                </div>
                ${idx === currentIndex ? '<svg class="jukebox-playing-icon" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V5l12-2v13"></path><circle cx="6" cy="18" r="3"></circle><circle cx="18" cy="16" r="3"></circle></svg>' : ''}
            `;
            li.onclick = () => jukeboxController.playTrackByIndex(idx);
            lista.appendChild(li);
        });
    },

    abrir() {
        this.modal.classList.add('activo');
    },

    actualizarMetadatos(canto) {
        if (!canto) return;
        document.getElementById('jukebox-titulo').textContent = canto.titulo || canto.nombre;
        document.getElementById('jukebox-autor').textContent = (canto.temas && canto.temas.length > 0) ? canto.temas.join(', ') : 'Repertorio BC';
    },

    actualizarProgreso(percent, timeStr, totalStr) {
        document.getElementById('jukebox-progress-fill').style.width = percent + '%';
        document.getElementById('jukebox-time-current').textContent = timeStr;
        if (totalStr) document.getElementById('jukebox-time-total').textContent = totalStr;
    },

    setPlayingState(playing) {
        if (playing) {
            this.modal.classList.add('playing');
            document.getElementById('icon-play').style.display = 'none';
            document.getElementById('icon-pause').style.display = 'block';
        } else {
            this.modal.classList.remove('playing');
            document.getElementById('icon-play').style.display = 'block';
            document.getElementById('icon-pause').style.display = 'none';
        }
    },

    mostrarIndicadorReanudar() {
        let banner = document.getElementById('jukebox-reanudar-banner');
        if (!banner) {
            banner = document.createElement('div');
            banner.id = 'jukebox-reanudar-banner';
            banner.textContent = 'Toca Play para continuar';
            this.modal?.appendChild(banner);
        }
        banner.style.display = 'block';
    },

    ocultarIndicadorReanudar() {
        const banner = document.getElementById('jukebox-reanudar-banner');
        if (banner) banner.style.display = 'none';
    }
};
