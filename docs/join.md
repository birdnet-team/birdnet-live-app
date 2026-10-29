---
title: Join an upload destination
hide:
  - navigation
  - toc
---

# Join an upload destination

<div id="join-open" class="join-card" hidden>
  <p>A project lead invited you to upload BirdNET Live sessions to <strong id="join-name">their storage</strong>.</p>
  <p><a id="join-button" class="md-button md-button--primary" href="#">Open in BirdNET Live</a></p>
  <p class="join-small">Nothing happened? Install the app first, then tap the button again, or copy the link below and paste it under <em>Settings › Export &amp; Sync › Upload destinations › Add destination</em>.</p>
  <p><button id="join-copy" class="md-button">Copy join link</button> <span id="join-copied" class="join-small" hidden>Copied.</span></p>
  <p class="join-small">
    <a href="https://play.google.com/store/apps/details?id=de.tu_chemnitz.mi.kahst.birdnet_live">Google Play</a> ·
    <a href="https://apps.apple.com/us/app/birdnet-live/id6776168518">App Store</a> ·
    <a href="https://github.com/birdnet-team/birdnet-live-app/releases/latest">Windows / APK</a>
  </p>
</div>

<div id="join-make" class="join-card">
  <h2>Make a join link and QR code</h2>
  <p>For project leads. Everything stays in this browser tab: the link is built here, the QR code is drawn here, and the secret sits in the part of the link after <code>#</code>, which browsers never send to any server. Treat the result like a password.</p>
  <label>Share link or WebDAV address<br><input id="mk-url" type="url" placeholder="https://cloud.example.org/s/AbCdEf123" size="48"></label><br>
  <label>User name (leave empty for a Nextcloud share link)<br><input id="mk-user" type="text" size="48"></label><br>
  <label>Share password or token<br><input id="mk-secret" type="text" size="48"></label><br>
  <label>Project name shown in the app<br><input id="mk-name" type="text" placeholder="Spring Survey 2027" size="48"></label><br>
  <label><input id="mk-audio" type="checkbox"> Suggest including audio</label><br>
  <label><input id="mk-wifi" type="checkbox" checked> Suggest Wi-Fi only</label>
  <p><button id="mk-build" class="md-button md-button--primary">Build link and QR code</button></p>
  <div id="mk-out" hidden>
    <div id="mk-qr"></div>
    <p><textarea id="mk-link" rows="4" cols="60" readonly></textarea></p>
    <p><button id="mk-copy" class="md-button">Copy link</button> <span id="mk-copied" class="join-small" hidden>Copied.</span></p>
    <p class="join-small">Print the QR code or show it on a screen; contributors scan it with their phone camera. A Nextcloud share link is converted to its File Drop endpoint by the app; set a password on the share.</p>
  </div>
</div>

<style>
.join-card { border: 1px solid var(--md-default-fg-color--lightest); border-radius: 8px; padding: 1rem 1.25rem; margin: 1rem 0; }
.join-small { font-size: .8rem; opacity: .8; }
#mk-qr canvas, #mk-qr img { background: #fff; padding: 12px; border-radius: 8px; }
.join-card label { display: inline-block; margin: .25rem 0; }
</style>

<script src="/birdnet-live-app/assets/js/qrcode-generator-1.4.4.js"></script>
<script>
(function () {
  var LANDING = 'https://birdnet-team.github.io/birdnet-live-app/join';
  function params() {
    var raw = location.hash ? location.hash.substring(1) : location.search.substring(1);
    var out = {};
    raw.split('&').forEach(function (pair) {
      if (!pair) return;
      var i = pair.indexOf('=');
      try {
        var k = decodeURIComponent(i < 0 ? pair : pair.substring(0, i));
        var v = i < 0 ? '' : decodeURIComponent(pair.substring(i + 1).replace(/\+/g, ' '));
        out[k] = v;
      } catch (e) {
        // A mangled parameter is dropped; the rest of the link still works.
      }
    });
    return out;
  }
  function encode(obj) {
    return Object.keys(obj).filter(function (k) { return obj[k] !== undefined && obj[k] !== ''; })
      .map(function (k) { return encodeURIComponent(k) + '=' + encodeURIComponent(obj[k]); }).join('&');
  }
  function copy(text, badge) {
    navigator.clipboard.writeText(text).then(function () {
      badge.hidden = false;
      setTimeout(function () { badge.hidden = true; }, 2000);
    });
  }

  // Landing mode: the fragment carries a join link.
  var p = params();
  if (p.url) {
    var open = document.getElementById('join-open');
    open.hidden = false;
    document.getElementById('join-make').hidden = true;
    if (p.name) document.getElementById('join-name').textContent = p.name;
    var custom = 'birdnetlive://join?' + encode(p);
    document.getElementById('join-button').href = custom;
    document.getElementById('join-copy').onclick = function () {
      copy(LANDING + '#' + encode(p), document.getElementById('join-copied'));
    };
  }

  // Generator mode.
  document.getElementById('mk-build').onclick = function () {
    var url = document.getElementById('mk-url').value.trim();
    if (!url) { document.getElementById('mk-url').focus(); return; }
    var share = url.match(/^(https?:\/\/[^\/]+(?:\/.*?)?)\/(?:index\.php\/)?s\/([^\/?#]+)/);
    var user = document.getElementById('mk-user').value.trim();
    if (share) {
      // Drop a trailing /index.php: the share lives at the install root.
      url = share[1].replace(/\/index\.php$/, '') + '/public.php/webdav/';
      user = share[2];
    } else {
      if (!/^https?:\/\//.test(url)) url = 'https://' + url;
      if (url.charAt(url.length - 1) !== '/') url += '/';
    }
    var link = LANDING + '#' + encode({
      v: '1', kind: 'webdav',
      name: document.getElementById('mk-name').value.trim(),
      url: url, user: user,
      secret: document.getElementById('mk-secret').value,
      audio: document.getElementById('mk-audio').checked ? '1' : '0',
      wifi: document.getElementById('mk-wifi').checked ? '1' : '0'
    });
    document.getElementById('mk-link').value = link;
    var qr = qrcode(0, 'M');
    qr.addData(link);
    qr.make();
    document.getElementById('mk-qr').innerHTML = qr.createSvgTag({ cellSize: 4, margin: 2, scalable: false });
    document.getElementById('mk-out').hidden = false;
  };
  document.getElementById('mk-copy').onclick = function () {
    copy(document.getElementById('mk-link').value, document.getElementById('mk-copied'));
  };
})();
</script>
