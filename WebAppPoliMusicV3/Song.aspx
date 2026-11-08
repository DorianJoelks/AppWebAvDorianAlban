<%@ Page Title="Canciones" Language="C#" MasterPageFile="~/Site.Master" AutoEventWireup="true" CodeBehind="Song.aspx.cs" Inherits="WebAppPoliMusicV3.Song" %>

<asp:Content ID="BodyContent" ContentPlaceHolderID="MainContent" runat="server">
    <style>
        :root { --wine: #800020; --wine-light: #a3002a; --wine-dark: #4a0a1c; --black: #0d0d0d; --panel: #171717; --line: #2a2a2a; --white: #ffffff; --muted: #b5b5b5; }
        body { background: var(--black); }
        .body-content { max-width: 1100px; }
        .songs-hero { position: relative; margin: 28px 0 20px; padding: 36px 32px; border-radius: 16px; color: var(--white); overflow: hidden;
            background: radial-gradient(circle at 90% 10%, rgba(255,255,255,.12), transparent 40%), linear-gradient(135deg, var(--wine-dark) 0%, var(--wine) 100%);
            box-shadow: 0 10px 30px rgba(128,0,32,.35); }
        .songs-hero h1 { margin: 0; font-size: 2.4rem; font-weight: 800; letter-spacing: .02em; }
        .songs-hero p { margin: 8px 0 0; color: rgba(255,255,255,.8); }
        .songs-hero .badge-count { display: inline-block; margin-top: 16px; padding: 4px 14px; border: 1px solid rgba(255,255,255,.6); border-radius: 20px; font-size: .8rem; letter-spacing: .08em; text-transform: uppercase; }
        .toolbar { margin-bottom: 14px; }
        .toolbar input { width: 100%; padding: 12px 18px; border-radius: 30px; border: 1px solid var(--line); background: var(--panel); color: var(--white); outline: none; }
        .toolbar input:focus { border-color: var(--wine-light); box-shadow: 0 0 0 3px rgba(128,0,32,.35); }
        .table-card { background: var(--panel); border: 1px solid var(--line); border-radius: 14px; padding: 8px 8px 4px; margin-bottom: 110px; overflow-x: auto; }
        .song-table { width: 100%; border-collapse: collapse; color: var(--white); }
        .song-table th { text-align: left; color: var(--muted); font-size: .75rem; text-transform: uppercase; letter-spacing: .1em; padding: 12px 14px; border-bottom: 2px solid var(--wine); background: transparent; }
        .song-table td { padding: 12px 14px; border-bottom: 1px solid var(--line); vertical-align: middle; background: transparent; color: var(--white); }
        .song-table .num { text-align: right; }
        .song-table .center { text-align: center; }
        .song { cursor: pointer; transition: background .15s; }
        .song:hover td { background: rgba(255,255,255,.06); }
        .song.playing td { background: rgba(128,0,32,.45); }
        .song.playing .title { color: var(--white); }
        .title { font-weight: 600; }
        .sub { color: var(--muted) !important; font-size: .85rem; }
        .play-btn { width: 38px; height: 38px; border-radius: 50%; border: 2px solid var(--white); background: var(--wine); color: var(--white); font-size: 13px; cursor: pointer; transition: transform .15s, background .15s; }
        .play-btn:hover { background: var(--wine-light); transform: scale(1.1); }
        .message { color: #ff8aa5; display: block; padding: 12px 14px; }
        .player { position: fixed; left: 0; right: 0; bottom: 0; z-index: 1000; background: linear-gradient(90deg, #000, var(--wine-dark)); color: var(--white); border-top: 2px solid var(--wine); padding: 12px 24px; display: flex; align-items: center; gap: 18px; }
        .player .now { min-width: 200px; }
        .player .now strong { display: block; }
        .player .now span { color: var(--muted); font-size: .85rem; }
        .player audio { flex: 1; height: 40px; }
        .player button { background: var(--white); color: var(--wine); font-weight: 700; border: none; border-radius: 20px; padding: 8px 18px; cursor: pointer; }
        .player button:hover { background: #f0d9de; }
        @media (max-width: 640px) { .song-table td:nth-child(3), .song-table th:nth-child(3) { display: none; } .player { flex-wrap: wrap; } .songs-hero h1 { font-size: 1.8rem; } }
    </style>

    <main>
        <div class="songs-hero">
            <h1>&#9835; Canciones</h1>
            <p>Selecciona una canci&oacute;n para empezar a escuchar.</p>
            <span class="badge-count" id="songCount"></span>
        </div>
        <div class="toolbar">
            <input type="text" id="txtSearch" placeholder="Buscar por nombre o artista..." autocomplete="off" />
        </div>

        <asp:Label ID="lblMessage" runat="server" CssClass="message"></asp:Label>
        <div class="table-card">
        <asp:GridView ID="gvSongs" runat="server" AutoGenerateColumns="False" CssClass="song-table"
            GridLines="None" DataKeyNames="ID_SONG" OnRowDataBound="gvSongs_RowDataBound" EmptyDataText="No hay canciones disponibles.">
            <Columns>
                <asp:BoundField DataField="ID_SONG" HeaderText="Id" />
                <asp:BoundField DataField="SONG_NAME" HeaderText="Nombre" ItemStyle-CssClass="title" />
                <asp:BoundField DataField="SONG_PATH" HeaderText="Ruta" ItemStyle-CssClass="sub" />
                <asp:BoundField DataField="ARTIST" HeaderText="Artista" />
                <asp:BoundField DataField="PLAYS" HeaderText="Reproducciones" ItemStyle-CssClass="num" HeaderStyle-CssClass="num" />
                <asp:TemplateField HeaderText="Play" ItemStyle-CssClass="center" HeaderStyle-CssClass="center">
                    <ItemTemplate>
                        <button type="button" class="play-btn" title="Reproducir">&#9654;</button>
                    </ItemTemplate>
                </asp:TemplateField>
            </Columns>
        </asp:GridView>
        </div>
    </main>

    <div class="player">
        <div class="now">
            <strong id="nowTitle">Nada en reproducción</strong>
            <span id="nowArtist">&nbsp;</span>
        </div>
        <audio id="audio" controls preload="none"></audio>
        <button type="button" id="btnNext">Siguiente &#9197;</button>
    </div>

    <script>
        (function () {
            var audio = document.getElementById('audio');
            var items = Array.prototype.slice.call(document.querySelectorAll('#<%= gvSongs.ClientID %> tr.song'));
            var current = -1;
            var errorMsg = 'Archivo de audio no encontrado o no se puede reproducir.';

            function setButtons() {
                items.forEach(function (row, i) {
                    var playing = i === current && !audio.paused;
                    row.classList.toggle('playing', i === current);
                    row.querySelector('.play-btn').innerHTML = playing ? '&#10074;&#10074;' : '&#9654;';
                });
            }

            function play(index) {
                if (index < 0 || index >= items.length) return;
                var row = items[index];
                if (index === current) {
                    if (audio.paused) audio.play(); else audio.pause();
                    return;
                }
                current = index;
                audio.src = row.getAttribute('data-src');
                document.getElementById('nowTitle').textContent = row.getAttribute('data-title');
                document.getElementById('nowArtist').textContent = row.getAttribute('data-artist');
                audio.play().catch(function () {
                    document.getElementById('nowArtist').textContent = errorMsg;
                });
                setButtons();
            }

            items.forEach(function (row, i) {
                row.addEventListener('click', function () { play(i); });
            });
            document.getElementById('btnNext').addEventListener('click', function () {
                if (items.length) play((current + 1) % items.length);
            });
            audio.addEventListener('play', setButtons);
            audio.addEventListener('pause', setButtons);
            audio.addEventListener('ended', function () {
                if (current + 1 < items.length) play(current + 1); else setButtons();
            });
            audio.addEventListener('error', function () {
                if (current >= 0) document.getElementById('nowArtist').textContent = errorMsg;
            });
        var countEl = document.getElementById('songCount');
            countEl.textContent = items.length + ' canciones';
            document.getElementById('txtSearch').addEventListener('input', function () {
                var q = this.value.toLowerCase(), shown = 0;
                items.forEach(function (row) {
                    var hit = (row.getAttribute('data-title') + ' ' + row.getAttribute('data-artist')).toLowerCase().indexOf(q) !== -1;
                    row.style.display = hit ? '' : 'none';
                    if (hit) shown++;
                });
                countEl.textContent = shown + ' canciones';
            });
        })();
    </script>
</asp:Content>
