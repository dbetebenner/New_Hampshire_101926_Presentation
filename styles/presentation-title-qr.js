/**
 * Title-slide QR code. Lives on the .slides canvas (not inside a slide
 * <section>) and is shown only while the title slide is current.
 */
(function () {
  'use strict';

  function onTitle() {
    if (typeof Reveal !== 'undefined' && Reveal.getCurrentSlide) {
      var slide = Reveal.getCurrentSlide();
      if (slide) return slide.id === 'title-slide';
    }
    var hash = window.location.hash || '';
    return hash === '' || hash === '#/' || hash.indexOf('#/title-slide') === 0;
  }

  function placeQr() {
    var slides = document.querySelector('.reveal .slides');
    var qr = document.getElementById('deck-qr-src');
    if (!slides || !qr) return;
    qr.hidden = false;
    slides.appendChild(qr);

    var sync = function () { qr.classList.toggle('is-visible', onTitle()); };
    sync();
    if (typeof Reveal !== 'undefined' && Reveal.on) {
      Reveal.on('ready', sync);
      Reveal.on('slidechanged', sync);
    }
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', placeQr);
  } else {
    placeQr();
  }
})();
