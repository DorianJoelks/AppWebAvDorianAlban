<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="Song.aspx.cs" Inherits="WebAppPoliMusicV2.Song" %>

<!DOCTYPE html>

<html xmlns="http://www.w3.org/1999/xhtml">
<head runat="server">
<meta http-equiv="Content-Type" content="text/html; charset=utf-8"/>
<meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>PoliMusic - Songs</title>
    <style>
        :root { --wine: #800020; --wine-dark: #5B0E2D; --bg: #121212; --text: #f2f2f2; --muted: #a8a8a8; }
        * { box-sizing: border-box; }
        body { margin: 0; font-family: "Segoe UI", Arial, sans-serif; background: linear-gradient(180deg, var(--wine-dark) 0, var(--bg) 320px) no-repeat var(--bg); color: var(--text); min-height: 100vh; padding-bottom: 110px; }
        header { padding: 40px 32px 16px; display: flex; justify-content: space-between; align-items: flex-start; }
        header h1 { margin: 0; font-size: 2.2rem; }
        header p { margin: 6px 0 0; color: var(--muted); }
        main { padding: 0 32px; }
        .logout-btn { background: transparent; color: #fff; border: 1px solid #fff; border-radius: 20px; padding: 8px 20px; text-decoration: none; font-weight: 600; }
        .logout-btn:hover { background: var(--wine); border-color: var(--wine); }
        .song-table { width: 100%; border-collapse: collapse; }
        .song-table th { text-align: left; color: var(--muted); font-size: .8rem; text-transform: uppercase; letter-spacing: .05em; padding: 10px 14px; border-bottom: 1px solid #333; }
        .song-table td { padding: 10px 14px; border-bottom: 1px solid rgba(255,255,255,.05); }
        .song-table .num { text-align: right; }
        .song-table .center { text-align: center; }
        .song { cursor: pointer; transition: background .15s; }
        .song:hover { background: rgba(255,255,255,.08); }
        .song.playing { background: rgba(128,0,32,.45); }
        .song.playing .title { color: #ff8aa5; }
        .title { font-weight: 600; }
        .sub { color: var(--muted); font-size: .9rem; }
        .play-btn { width: 36px; height: 36px; border-radius: 50%; border: none; background: var(--wine); color: #fff; font-size: 14px; cursor: pointer; }
        .play-btn:hover { background: #a3002a; }
        .message { color: #ff8aa5; display: block; padding: 12px 14px; }
        .player { position: fixed; left: 0; right: 0; bottom: 0; background: #181818; border-top: 1px solid #333; padding: 12px 24px; display: flex; align-items: center; gap: 18px; }
        .player .now { min-width: 180px; }
        .player .now strong { display: block; }
        .player .now span { color: var(--muted); font-size: .85rem; }
        .player audio { flex: 1; height: 40px; }
        .player button { background: var(--wine); color: #fff; border: none; border-radius: 6px; padding: 8px 14px; cursor: pointer; }
        @media (max-width: 640px) { .song-table td:nth-child(3), .song-table th:nth-child(3) { display: none; } .player { flex-wrap: wrap; } }
    </style>
</head>
<body>
    <form id="form1" runat="server">
        <header>
            <div>
                <h1>Welcome Dorian.Alban</h1>
                <p>Select a song to start listening.</p>
            </div>
            <a href="Logout.aspx" class="logout-btn">Logout</a>
        </header>
        <main>
            <asp:Label ID="lblMessage" runat="server" CssClass="message"></asp:Label>
            <table class="song-table">
                <thead>
                    <tr>
                        <th>Id</th>
                        <th>Name</th>
                        <th>Path</th>
                        <th class="num">Plays</th>
                        <th class="center">Play</th>
                    </tr>
                </thead>
                <tbody>
                <asp:Repeater ID="rptSongs" runat="server">
                    <ItemTemplate>
                        <tr class="song" data-src="<%# Server.HtmlEncode(ResolveUrl(Eval("SONG_PATH").ToString())) %>"
                            data-title="<%# Server.HtmlEncode(Eval("SONG_NAME").ToString()) %>"
                            data-artist="<%# Server.HtmlEncode(Eval("ARTIST").ToString()) %>">
                            <td><%# Eval("ID_SONG") %></td>
                            <td class="title"><%# Server.HtmlEncode(Eval("SONG_NAME").ToString()) %></td>
                            <td class="sub"><%# Server.HtmlEncode(Eval("SONG_PATH").ToString()) %></td>
                            <td class="num"><%# Eval("PLAYS") %></td>
                            <td class="center"><button type="button" class="play-btn" title="Play">&#9654;</button></td>
                        </tr>
                    </ItemTemplate>
                </asp:Repeater>
                </tbody>
            </table>
        </main>

        <div class="player">
            <div class="now">
                <strong id="nowTitle">Nothing playing</strong>
                <span id="nowArtist">&nbsp;</span>
            </div>
            <audio id="audio" controls preload="none"></audio>
            <button type="button" id="btnNext">Next &#9197;</button>
        </div>
    </form>

    <script>
        (function () {
            var audio = document.getElementById('audio');
            var items = Array.prototype.slice.call(document.querySelectorAll('.song'));
            var current = -1;

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
                    document.getElementById('nowArtist').textContent = 'Audio file not found or cannot be played.';
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
                if (current >= 0) document.getElementById('nowArtist').textContent = 'Audio file not found or cannot be played.';
            });
        })();
    </script>
</body>
</html>
