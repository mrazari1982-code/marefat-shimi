(function (global) {
  'use strict';

  function mount(options) {
    options = options || {};
    var client = options.client;
    var backTarget = options.backTarget === 'admin-panel.html' ? options.backTarget : 'admin-panel.html';

    document.querySelectorAll('[data-admin-nav]').forEach(function (node) {
      var link = document.createElement('a');
      link.className = 'btn secondary';
      link.href = backTarget;
      link.textContent = 'پنل اصلی';
      node.replaceChildren(link);
    });

    document.querySelectorAll('[data-admin-logout]').forEach(function (node) {
      node.addEventListener('click', async function (event) {
        event.preventDefault();
        if (client && client.auth && typeof client.auth.signOut === 'function') {
          await client.auth.signOut();
        }
        location.href = 'admin-login-v2.html';
      });
    });
  }

  global.MarefatAdminNav = { mount: mount };
})(window);
