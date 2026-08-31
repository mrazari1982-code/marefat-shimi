(function (global) {
  'use strict';

  function mount(options) {
    options = options || {};
    var client = options.client;
    var backTarget = options.backTarget === 'admin-panel.html' ? options.backTarget : 'admin-panel.html';

    var menus = document.querySelectorAll('.menu-grid');
    var existingCurriculum = document.querySelectorAll('[data-curriculum-admin]');
    if (menus.length && !existingCurriculum.length) {
      var menu = menus[0];
      var curriculum = document.createElement('section');
      curriculum.className = 'menu-group';
      curriculum.setAttribute('data-curriculum-admin', '');
      var heading = document.createElement('h2');
      heading.textContent = 'ساختار جدید مدرسه';
      var links = document.createElement('div');
      links.className = 'nav';
      [
        ['admin-school-structure.html', 'سال و کلاس‌ها'],
        ['admin-curriculum-question-bank.html', 'بانک سؤال جدید'],
        ['admin-curriculum-exam-builder.html', 'آزمون‌ساز جدید']
      ].forEach(function (item) {
        var link = document.createElement('a');
        link.href = item[0];
        link.textContent = item[1];
        links.appendChild(link);
      });
      curriculum.appendChild(heading);
      curriculum.appendChild(links);
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
