'use strict';

const flutterConfig = {
  canvasKitBaseUrl: "/canvaskit/",
  renderer: "canvaskit"
};

// Initialize Flutter Web
function initFlutterWeb() {
  const script = document.createElement('script');
  script.src = "main.dart.js";
  script.type = "application/javascript";
  document.body.appendChild(script);
}

// Service worker registration
if ('serviceWorker' in navigator) {
  window.addEventListener('load', async function() {
    try {
      const registration = await navigator.serviceWorker.register('/flutter_service_worker.js', {
        scope: '.'
      });
      console.log('Service worker registration succeeded:', registration);
    } catch (e) {
      console.log('Service worker registration failed:', e);
    }
  });
}

// Prevent back button
window.addEventListener('load', function() {
  history.pushState(null, null, location.href);
  window.onpopstate = function(event) {
    history.pushState(null, null, location.href);
  };
});

// Initialize Flutter
window.addEventListener('load', function() {
  initFlutterWeb();
});

// Export configuration
window.flutterConfiguration = flutterConfig;