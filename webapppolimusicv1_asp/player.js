/* =============================================================================
   PoliMusic · player.js
   -----------------------------------------------------------------------------
   Responsabilidades:
     1. Reproductor de audio persistente (play/pausa, anterior/siguiente,
        aleatorio, repetir, progreso interactivo y volumen).
     2. Resaltado de la pista activa y contador de reproducciones.
     3. Lectura de la duración real de cada .mp3 (el esquema no la almacena).
     4. UI del catálogo: búsqueda en vivo, modales de administración y toasts.

   El script es defensivo: si un elemento no existe en la página (por ejemplo,
   los modales cuando el usuario es "normal"), simplemente no se enlaza.
   ============================================================================= */
(function () {
    'use strict';

    /* -------------------------------------------------------------------------
       Helpers
       ------------------------------------------------------------------------- */
    var $  = function (selector, ctx) { return (ctx || document).querySelector(selector); };
    var $$ = function (selector, ctx) {
        return Array.prototype.slice.call((ctx || document).querySelectorAll(selector));
    };

    var audio = document.getElementById('audio');
    if (!audio) { return; }

    var playerEl   = document.getElementById('player');
    var btnPlay    = document.getElementById('btnPlay');
    var btnPrev    = document.getElementById('btnPrev');
    var btnNext    = document.getElementById('btnNext');
    var btnShuffle = document.getElementById('btnShuffle');
    var btnRepeat  = document.getElementById('btnRepeat');
    var btnMute    = document.getElementById('btnMute');
    var btnLike    = document.getElementById('btnLike');
    var seek       = document.getElementById('seek');
    var volume     = document.getElementById('volume');
    var elCover    = document.getElementById('playerCover');
    var elTitle    = document.getElementById('playerTitle');
    var elArtist   = document.getElementById('playerArtist');
    var elCurrent  = document.getElementById('timeCurrent');
    var elTotal    = document.getElementById('timeTotal');

    var REPEAT_OFF = 0, REPEAT_ALL = 1, REPEAT_ONE = 2;

    var state = {
        tracks: [],
        index: -1,
        shuffle: false,
        repeat: REPEAT_OFF,
        muted: false,
        lastVolume: 0.8,
        countedFor: null      // id de la pista ya contabilizada
    };

    /* -------------------------------------------------------------------------
       Utilidades
       ------------------------------------------------------------------------- */
    function formatTime(seconds) {
        if (!isFinite(seconds) || seconds < 0) { return '0:00'; }
        var total = Math.floor(seconds);
        var h = Math.floor(total / 3600);
        var m = Math.floor((total % 3600) / 60);
        var s = total % 60;
        if (h > 0) {
            return h + ':' + (m < 10 ? '0' : '') + m + ':' + (s < 10 ? '0' : '') + s;
        }
        return m + ':' + (s < 10 ? '0' : '') + s;
    }

    function formatCount(n) {
        n = parseInt(n, 10) || 0;
        return String(n).replace(/\B(?=(\d{3})+(?!\d))/g, '.');
    }

    function setFill(rangeEl, percent) {
        if (!rangeEl) { return; }
        rangeEl.style.setProperty('--fill', Math.max(0, Math.min(100, percent)) + '%');
    }

    /* Toast efímero (no bloquea la interacción) */
    var toastHost = document.getElementById('toasts');
    function toast(message, kind) {
        if (!toastHost) { return; }
        var el = document.createElement('div');
        el.className = 'toast toast--' + (kind || 'info');
        el.textContent = message;
        toastHost.appendChild(el);
        window.setTimeout(function () {
            el.classList.add('is-leaving');
            window.setTimeout(function () {
                if (el.parentNode) { el.parentNode.removeChild(el); }
            }, 220);
        }, 3600);
    }
    window.PoliToast = toast;

    /* -------------------------------------------------------------------------
       1. Catálogo → modelo de pistas
       ------------------------------------------------------------------------- */
    function loadTracks() {
        state.tracks = $$('#trackBody .track-row').filter(function (tr) {
            return !tr.classList.contains('track-row--empty');
        }).map(function (tr) {
            return {
                el:        tr,
                id:        tr.getAttribute('data-id'),
                title:     tr.getAttribute('data-title') || 'Sin título',
                artist:    tr.getAttribute('data-artist') || 'Artista desconocido',
                album:     tr.getAttribute('data-album') || '',
                cover:     tr.getAttribute('data-cover') || '',
                src:       tr.getAttribute('data-src') || '',
                plays:     parseInt(tr.getAttribute('data-plays'), 10) || 0,
                available: tr.getAttribute('data-available') === '1'
            };
        });
    }

    /* Pistas visibles (respetan el filtro de búsqueda) */
    function visibleTracks() {
        return state.tracks.filter(function (t) {
            return !t.el.hidden;
        });
    }

    /* -------------------------------------------------------------------------
       2. Duración real del MP3
          El esquema de referencia no guarda la duración, así que se lee de los
          metadatos del propio archivo (preload="metadata") y se cachea.
       ------------------------------------------------------------------------- */
    var durationCache = {};
    var probeQueue = [];
    var probing = false;

    function enqueueProbe(track) {
        if (!track.available || !track.src) { return; }
        if (durationCache[track.src] !== undefined) {
            paintDuration(track, durationCache[track.src]);
            return;
        }
        probeQueue.push(track);
        runProbes();
    }

    function runProbes() {
        if (probing || probeQueue.length === 0) { return; }
        probing = true;
        var track = probeQueue.shift();
        var probe = new Audio();
        var done = false;

        function finish(seconds) {
            if (done) { return; }
            done = true;
            probe.src = '';
            durationCache[track.src] = seconds;
            paintDuration(track, seconds);
            probing = false;
            runProbes();
        }

        probe.preload = 'metadata';
        probe.addEventListener('loadedmetadata', function () { finish(probe.duration); }, { once: true });
        probe.addEventListener('error', function () { finish(null); }, { once: true });
        window.setTimeout(function () { finish(null); }, 8000);

        probe.src = track.src;
    }

    function paintDuration(track, seconds) {
        var cell = track.el.querySelector('[data-duration-cell]');
        if (!cell) { return; }
        cell.textContent = (seconds && isFinite(seconds)) ? formatTime(seconds) : '--:--';
    }

    /* -------------------------------------------------------------------------
       3. Reproducción
       ------------------------------------------------------------------------- */
    function playIndex(index, options) {
        options = options || {};
        var tracks = state.tracks;
        if (index < 0 || index >= tracks.length) { return; }

        var track = tracks[index];
        if (!track.available || !track.src) {
            toast('«' + track.title + '» no tiene archivo de audio disponible.', 'error');
            return;
        }

        // La misma pista: solo reanudar / pausar
        if (state.index === index && !options.force) {
            togglePlay();
            return;
        }

        state.index = index;
        state.countedFor = null;

        audio.src = track.src;
        audio.load();

        if (elCover)  { elCover.src = track.cover; elCover.alt = 'Carátula de ' + track.title; }
        if (elTitle)  { elTitle.textContent = track.title; }
        if (elArtist) { elArtist.textContent = track.artist + (track.album ? ' · ' + track.album : ''); }

        highlight(index);

        var promise = audio.play();
        if (promise && typeof promise.catch === 'function') {
            promise.catch(function () {
                toast('No se pudo reproducir el archivo de audio.', 'error');
                setPlayingUI(false);
            });
        }

        updateMediaSession(track);
        enqueueProbe(track);
    }

    function togglePlay() {
        if (!audio.src) {
            // Nada cargado: arranca la primera pista disponible
            var first = state.tracks.findIndex(function (t) { return t.available; });
            if (first >= 0) {
                playIndex(first, { force: true });
            } else {
                toast('No hay archivos de audio disponibles en el catálogo.', 'error');
            }
            return;
        }
        if (audio.paused) {
            var p = audio.play();
            if (p && typeof p.catch === 'function') {
                p.catch(function () { toast('No se pudo reanudar la reproducción.', 'error'); });
            }
        } else {
            audio.pause();
        }
    }

    function nextIndex(step) {
        var total = state.tracks.length;
        if (total === 0) { return -1; }

        if (state.shuffle) {
            var pool = [];
            for (var i = 0; i < total; i++) {
                if (i !== state.index && state.tracks[i].available) { pool.push(i); }
            }
            if (pool.length === 0) { return state.index; }
            return pool[Math.floor(Math.random() * pool.length)];
        }

        var idx = state.index;
        for (var guard = 0; guard < total; guard++) {
            idx = idx + step;
            if (idx >= total) {
                if (state.repeat === REPEAT_ALL) { idx = 0; } else { return -1; }
            }
            if (idx < 0) {
                if (state.repeat === REPEAT_ALL) { idx = total - 1; } else { return -1; }
            }
            if (state.tracks[idx].available) { return idx; }
        }
        return -1;
    }

    function playNext(auto) {
        var idx = nextIndex(1);
        if (idx < 0) {
            if (auto) { setPlayingUI(false); }
            return;
        }
        playIndex(idx, { force: true });
    }

    function playPrev() {
        if (audio.currentTime > 3) {
            audio.currentTime = 0;
            return;
        }
        var idx = nextIndex(-1);
        if (idx >= 0) { playIndex(idx, { force: true }); }
    }

    /* -------------------------------------------------------------------------
       4. Sincronización de la interfaz
       ------------------------------------------------------------------------- */
    function setPlayingUI(isPlaying) {
        if (playerEl) { playerEl.classList.toggle('is-playing', isPlaying); }
        if (btnPlay) {
            btnPlay.setAttribute('aria-label', isPlaying ? 'Pausar' : 'Reproducir');
            btnPlay.setAttribute('aria-pressed', isPlaying ? 'true' : 'false');
        }
        document.body.classList.toggle('is-paused', !isPlaying);
    }

    function highlight(index) {
        state.tracks.forEach(function (t, i) {
            var active = (i === index);
            t.el.classList.toggle('is-active', active);
            if (active) {
                t.el.setAttribute('aria-current', 'true');
            } else {
                t.el.removeAttribute('aria-current');
            }
        });
    }

    function updateProgress() {
        var duration = audio.duration;
        var current = audio.currentTime;

        if (elCurrent) { elCurrent.textContent = formatTime(current); }
        if (elTotal)   { elTotal.textContent = formatTime(duration); }

        if (seek && isFinite(duration) && duration > 0) {
            var pct = (current / duration) * 100;
            if (!seek.dataset.dragging) {
                seek.value = Math.round((current / duration) * 1000);
            }
            setFill(seek, pct);
        }
    }

    /* -------------------------------------------------------------------------
       5. Contador de reproducciones
       ------------------------------------------------------------------------- */
    function countPlay(track) {
        if (!track || state.countedFor === track.id) { return; }
        state.countedFor = track.id;

        var body = 'id=' + encodeURIComponent(track.id);

        fetch('song_play.asp', {
            method: 'POST',
            credentials: 'same-origin',
            headers: { 'Content-Type': 'application/x-www-form-urlencoded;charset=UTF-8' },
            body: body
        }).then(function (res) {
            if (!res.ok) { throw new Error('bad status'); }
            return res.json();
        }).then(function (data) {
            if (!data || !data.ok) { return; }
            track.plays = data.plays;
            var cell = track.el.querySelector('[data-plays-cell]');
            if (cell) { cell.textContent = formatCount(data.plays); }
        }).catch(function () {
            /* Sin servidor (p. ej. vista previa estática): se ignora. */
        });
    }

    /* -------------------------------------------------------------------------
       6. Media Session (controles del sistema operativo)
       ------------------------------------------------------------------------- */
    function updateMediaSession(track) {
        if (!('mediaSession' in navigator)) { return; }
        try {
            navigator.mediaSession.metadata = new window.MediaMetadata({
                title: track.title,
                artist: track.artist,
                album: track.album || 'PoliMusic',
                artwork: track.cover ? [{ src: track.cover, sizes: '512x512', type: 'image/png' }] : []
            });
            navigator.mediaSession.setActionHandler('play', function () { audio.play(); });
            navigator.mediaSession.setActionHandler('pause', function () { audio.pause(); });
            navigator.mediaSession.setActionHandler('previoustrack', playPrev);
            navigator.mediaSession.setActionHandler('nexttrack', function () { playNext(false); });
        } catch (e) { /* Navegadores sin soporte completo */ }
    }

    /* -------------------------------------------------------------------------
       7. Eventos del elemento <audio>
       ------------------------------------------------------------------------- */
    audio.addEventListener('timeupdate', updateProgress);

    audio.addEventListener('loadedmetadata', function () {
        updateProgress();
        var track = state.tracks[state.index];
        if (track) {
            durationCache[track.src] = audio.duration;
            paintDuration(track, audio.duration);
        }
    });

    audio.addEventListener('play', function () {
        setPlayingUI(true);
        var track = state.tracks[state.index];
        if (track) { countPlay(track); }
    });

    audio.addEventListener('pause', function () {
        setPlayingUI(false);
    });

    audio.addEventListener('ended', function () {
        if (state.repeat === REPEAT_ONE) {
            audio.currentTime = 0;
            audio.play();
            return;
        }
        playNext(true);
    });

    audio.addEventListener('error', function () {
        if (!audio.src) { return; }
        toast('Archivo de audio no encontrado o ilegible.', 'error');
        setPlayingUI(false);
    });

    /* -------------------------------------------------------------------------
       8. Controles
       ------------------------------------------------------------------------- */
    if (btnPlay) { btnPlay.addEventListener('click', togglePlay); }
    if (btnPrev) { btnPrev.addEventListener('click', playPrev); }
    if (btnNext) { btnNext.addEventListener('click', function () { playNext(false); }); }

    if (btnShuffle) {
        btnShuffle.addEventListener('click', function () {
            state.shuffle = !state.shuffle;
            btnShuffle.setAttribute('aria-pressed', state.shuffle ? 'true' : 'false');
            toast(state.shuffle ? 'Modo aleatorio activado.' : 'Modo aleatorio desactivado.', 'info');
        });
    }

    if (btnRepeat) {
        btnRepeat.addEventListener('click', function () {
            state.repeat = (state.repeat + 1) % 3;
            btnRepeat.setAttribute('aria-pressed', state.repeat !== REPEAT_OFF ? 'true' : 'false');
            btnRepeat.setAttribute('aria-label',
                state.repeat === REPEAT_ONE ? 'Repetir una canción' :
                state.repeat === REPEAT_ALL ? 'Repetir todo' : 'Repetir desactivado');
            toast(state.repeat === REPEAT_ONE ? 'Repetir: una canción.' :
                  state.repeat === REPEAT_ALL ? 'Repetir: todo el catálogo.' :
                  'Repetir desactivado.', 'info');
        });
    }

    /* --- Progreso --- */
    if (seek) {
        seek.addEventListener('input', function () {
            seek.dataset.dragging = '1';
            setFill(seek, (parseInt(seek.value, 10) / 1000) * 100);
            if (isFinite(audio.duration) && audio.duration > 0) {
                var t = (parseInt(seek.value, 10) / 1000) * audio.duration;
                if (elCurrent) { elCurrent.textContent = formatTime(t); }
            }
        });

        seek.addEventListener('change', function () {
            if (isFinite(audio.duration) && audio.duration > 0) {
                audio.currentTime = (parseInt(seek.value, 10) / 1000) * audio.duration;
            }
            delete seek.dataset.dragging;
        });
    }

    /* --- Volumen --- */
    function applyVolume(v, persist) {
        v = Math.max(0, Math.min(1, v));
        audio.volume = v;
        state.muted = (v === 0);
        if (playerEl) { playerEl.classList.toggle('is-muted', state.muted); }
        if (btnMute) { btnMute.setAttribute('aria-pressed', state.muted ? 'true' : 'false'); }
        if (volume) {
            volume.value = Math.round(v * 100);
            setFill(volume, v * 100);
        }
        if (persist) {
            try { window.localStorage.setItem('polimusic.volume', String(v)); } catch (e) { /* modo privado */ }
        }
    }

    if (volume) {
        volume.addEventListener('input', function () {
            var v = parseInt(volume.value, 10) / 100;
            state.lastVolume = v > 0 ? v : state.lastVolume;
            applyVolume(v, true);
        });
    }

    if (btnMute) {
        btnMute.addEventListener('click', function () {
            if (audio.volume > 0) {
                state.lastVolume = audio.volume;
                applyVolume(0, true);
            } else {
                applyVolume(state.lastVolume || 0.8, true);
            }
        });
    }

    if (btnLike) {
        btnLike.addEventListener('click', function () {
            var on = btnLike.getAttribute('aria-pressed') === 'true';
            btnLike.setAttribute('aria-pressed', on ? 'false' : 'true');
            btnLike.classList.toggle('is-on', !on);
        });
    }

    /* -------------------------------------------------------------------------
       9. Interacción con la tabla
       ------------------------------------------------------------------------- */
    document.addEventListener('click', function (event) {
        var playBtn = event.target.closest('[data-play]');
        if (playBtn && !playBtn.disabled) {
            event.preventDefault();
            var id = playBtn.getAttribute('data-play');
            var idx = state.tracks.findIndex(function (t) { return t.id === id; });
            if (idx >= 0) { playIndex(idx, { force: true }); }
            return;
        }

        var playAll = event.target.closest('[data-play-all]');
        if (playAll) {
            event.preventDefault();
            var firstIdx = state.tracks.findIndex(function (t) { return t.available && !t.el.hidden; });
            if (firstIdx >= 0) {
                playIndex(firstIdx, { force: true });
            } else {
                toast('No hay archivos de audio disponibles.', 'error');
            }
            return;
        }

        var shuffleAll = event.target.closest('[data-shuffle-all]');
        if (shuffleAll) {
            event.preventDefault();
            state.shuffle = true;
            if (btnShuffle) { btnShuffle.setAttribute('aria-pressed', 'true'); }
            var pool = state.tracks.map(function (t, i) { return t.available ? i : -1; })
                                  .filter(function (i) { return i >= 0; });
            if (pool.length) {
                playIndex(pool[Math.floor(Math.random() * pool.length)], { force: true });
            } else {
                toast('No hay archivos de audio disponibles.', 'error');
            }
        }
    });

    /* Doble clic sobre una fila = reproducir */
    document.addEventListener('dblclick', function (event) {
        var row = event.target.closest('.track-row');
        if (!row || row.classList.contains('track-row--empty')) { return; }
        var idx = state.tracks.findIndex(function (t) { return t.el === row; });
        if (idx >= 0) { playIndex(idx, { force: true }); }
    });

    /* -------------------------------------------------------------------------
       10. Búsqueda en vivo
       ------------------------------------------------------------------------- */
    var searchInput = document.getElementById('searchInput');
    var emptySearch = document.getElementById('emptySearch');

    if (searchInput) {
        searchInput.addEventListener('input', function () {
            var q = searchInput.value.trim().toLowerCase();
            var shown = 0;

            state.tracks.forEach(function (t) {
                var haystack = (t.title + ' ' + t.artist + ' ' + t.album).toLowerCase();
                var match = q === '' || haystack.indexOf(q) !== -1;
                t.el.hidden = !match;
                if (match) { shown++; }
            });

            if (emptySearch) { emptySearch.hidden = (shown !== 0); }
        });
    }

    /* -------------------------------------------------------------------------
       11. Modales de administración (solo existen en el DOM si el rol es admin)
       ------------------------------------------------------------------------- */
    var activeModal = null;

    function openModal(modal) {
        if (!modal) { return; }
        modal.hidden = false;
        activeModal = modal;
        document.body.style.overflow = 'hidden';
        var focusable = modal.querySelector('input:not([type="hidden"]), select, button');
        if (focusable) { window.setTimeout(function () { focusable.focus(); }, 60); }
    }

    function closeModal(modal) {
        if (!modal) { return; }
        modal.hidden = true;
        activeModal = null;
        document.body.style.overflow = '';
    }

    document.addEventListener('click', function (event) {
        var opener = event.target.closest('[data-open-modal]');
        if (opener) {
            event.preventDefault();
            var kind = opener.getAttribute('data-open-modal');

            if (kind === 'song') {
                var modal = document.getElementById('modal-song');
                var mode = opener.getAttribute('data-mode') || 'create';
                var form = document.getElementById('formSong');
                if (!modal || !form) { return; }

                form.reset();

                var titleEl  = document.getElementById('modalSongTitle');
                var actionEl = document.getElementById('songAction');
                var idEl     = document.getElementById('songId');
                var submitEl = document.getElementById('songSubmit');

                if (mode === 'edit') {
                    var row = opener.closest('.track-row');
                    if (!row) { return; }

                    actionEl.value = 'update';
                    idEl.value     = row.getAttribute('data-id');
                    document.getElementById('songName').value  = row.getAttribute('data-title') || '';
                    document.getElementById('songPath').value  = row.getAttribute('data-path') || '';
                    document.getElementById('songPlays').value = row.getAttribute('data-plays') || '0';

                    var albumSel  = document.getElementById('songAlbum');
                    var artistSel = document.getElementById('songArtist');
                    if (albumSel)  { albumSel.value  = row.getAttribute('data-album-id')  || '0'; }
                    if (artistSel) { artistSel.value = row.getAttribute('data-artist-id') || '0'; }

                    if (titleEl)  { titleEl.textContent = 'Editar canción'; }
                    if (submitEl) { submitEl.textContent = 'Guardar cambios'; }
                } else {
                    actionEl.value = 'create';
                    idEl.value     = '';
                    document.getElementById('songPlays').value = '0';
                    if (titleEl)  { titleEl.textContent = 'Añadir canción'; }
                    if (submitEl) { submitEl.textContent = 'Guardar canción'; }
                }

                openModal(modal);
                return;
            }

            if (kind === 'delete') {
                var delModal = document.getElementById('modal-delete');
                var row2 = opener.closest('.track-row');
                if (!delModal || !row2) { return; }

                document.getElementById('deleteId').value = row2.getAttribute('data-id');
                var nameEl = document.getElementById('deleteName');
                if (nameEl) { nameEl.textContent = '«' + (row2.getAttribute('data-title') || '') + '»'; }

                openModal(delModal);
            }
            return;
        }

        var closer = event.target.closest('[data-close-modal]');
        if (closer) {
            event.preventDefault();
            closeModal(closer.closest('.modal'));
        }
    });

    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && activeModal) {
            closeModal(activeModal);
        }
    });

    /* -------------------------------------------------------------------------
       12. Barra lateral en móvil
       ------------------------------------------------------------------------- */
    var sidebar = document.getElementById('sidebar');
    var sidebarToggle = document.getElementById('sidebarToggle');

    if (sidebar && sidebarToggle) {
        sidebarToggle.addEventListener('click', function () {
            var open = sidebar.classList.toggle('is-open');
            sidebarToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
        });

        sidebar.addEventListener('click', function (event) {
            if (event.target.closest('a') && window.innerWidth <= 860) {
                sidebar.classList.remove('is-open');
                sidebarToggle.setAttribute('aria-expanded', 'false');
            }
        });
    }

    var focusSearch = document.querySelector('[data-focus-search]');
    if (focusSearch && searchInput) {
        focusSearch.addEventListener('click', function (event) {
            event.preventDefault();
            searchInput.focus();
        });
    }

    /* -------------------------------------------------------------------------
       13. Atajos de teclado del reproductor
       ------------------------------------------------------------------------- */
    document.addEventListener('keydown', function (event) {
        var tag = (event.target.tagName || '').toLowerCase();
        if (tag === 'input' || tag === 'textarea' || tag === 'select' || event.target.isContentEditable) {
            return;
        }
        if (event.ctrlKey || event.metaKey || event.altKey) { return; }

        switch (event.key) {
            case ' ':
            case 'Spacebar':
                event.preventDefault();
                togglePlay();
                break;
            case 'ArrowRight':
                if (isFinite(audio.duration)) {
                    event.preventDefault();
                    audio.currentTime = Math.min(audio.duration, audio.currentTime + 5);
                }
                break;
            case 'ArrowLeft':
                event.preventDefault();
                audio.currentTime = Math.max(0, audio.currentTime - 5);
                break;
            case 'ArrowUp':
                event.preventDefault();
                applyVolume(audio.volume + 0.05, true);
                break;
            case 'ArrowDown':
                event.preventDefault();
                applyVolume(audio.volume - 0.05, true);
                break;
            case 'm':
            case 'M':
                if (btnMute) { btnMute.click(); }
                break;
            default:
                break;
        }
    });

    /* -------------------------------------------------------------------------
       14. Arranque
       ------------------------------------------------------------------------- */
    loadTracks();

    // Volumen recordado entre sesiones
    var storedVolume = null;
    try { storedVolume = window.localStorage.getItem('polimusic.volume'); } catch (e) { storedVolume = null; }
    applyVolume(storedVolume !== null ? parseFloat(storedVolume) : 0.8, false);

    // Duración de cada pista (secuencial, sin bloquear la página)
    state.tracks.forEach(function (track) { enqueueProbe(track); });

    setPlayingUI(false);
    updateProgress();
})();
