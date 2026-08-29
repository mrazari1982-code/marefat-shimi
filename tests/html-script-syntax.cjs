const fs = require('node:fs');
const path = require('node:path');

const publicDir = path.join(__dirname, '..', 'public');
let count = 0;
for (const name of fs.readdirSync(publicDir).filter(name => name.endsWith('.html'))) {
  const html = fs.readFileSync(path.join(publicDir, name), 'utf8');
  const scripts = [...html.matchAll(/<script(?![^>]*\bsrc=)[^>]*>([\s\S]*?)<\/script>/gi)];
  scripts.forEach((match, index) => {
    try {
      new Function(match[1]);
      count++;
    } catch (error) {
      throw new Error(`${name}: inline script ${index + 1}: ${error.message}`);
    }
  });
}
console.log(`PASS: ${count} inline browser scripts parse successfully`);
