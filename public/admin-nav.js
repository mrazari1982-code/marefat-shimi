(function (global) {
  'use strict';

  function mount(options) {
    options = options || {};
    var client = options.client;
    var backTarget = options.backTarget === 'admin-panel.html' ? options.backTarget : 'admin-panel.html';

    var menu = document.querySelector('.menu-grid');
    if (menu && !menu.querySelector('[data-curriculum-admin]')) {
      var curriculum = document.createElement('section');
      curriculum.className = 'menu-group';
      curriculum.setAttribute('data-curriculum-admin', '');
      curriculum.innerHTML = '<h2>ساختار جدید مدرسه</h2><div class="nav"><a href="admin-school-structure.html">سال و کلاس‌ها</a><a href="admin-curriculum-question-bank.html">بانک سؤال جدید</a><a href="admin-curriculum-exam-builder.html">آزمون‌ساز جدید</a></div>';
      menu.prepend(curriculum);
    }

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
