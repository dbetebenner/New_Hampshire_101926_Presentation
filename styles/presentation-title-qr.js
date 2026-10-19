/**
 * Park the QR on the title slide only. It must not be a sibling of the
 * other <section>s inside .slides — that extra child was shifting slide 2.
 */
(function () {
  'use strict';

  function placeQr() {
    var slide = document.getElementById('title-slide');
    var qr = document.getElementById('deck-qr-src');
    if (!slide || !qr) return;
    qr.hidden = false;
    slide.appendChild(qr);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', placeQr);
  } else {
    placeQr();
  }
})();
