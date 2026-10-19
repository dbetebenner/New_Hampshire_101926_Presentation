/**
 * Place the title-slide QR on the Reveal viewport (bottom-right) and
 * show it only while the title slide is current.
 */
(function () {
  'use strict';

  function currentIsTitle() {
    if (typeof Reveal !== 'undefined' && Reveal.getCurrentSlide) {
      var slide = Reveal.getCurrentSlide();
      return !!(slide && slide.id === 'title-slide');
    }
    var hash = window.location.hash || '';
    return hash === '' || hash === '#/' || hash.indexOf('#/title-slide') === 0;
  }

  function sync(qr) {
    qr.classList.toggle('is-visible', currentIsTitle());
  }

  function placeQr() {
    var slides = document.querySelector('.reveal .slides');
    var qr = document.getElementById('deck-qr-src');
    if (!slides || !qr) return;
    qr.hidden = false;
    slides.appendChild(qr);
    sync(qr);

    if (typeof Reveal !== 'undefined' && Reveal.on) {
      Reveal.on('ready', function () { sync(qr); });
      Reveal.on('slidechanged', function () { sync(qr); });
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', placeQr);
  } else {
    placeQr();
  }
})();
