#!/bin/bash
set -e
cd ~/Code/Misc
rm -rf ix-icon-verify
npx --yes @angular/cli@22 new ix-icon-verify \
  --standalone --routing --style=css --skip-git --skip-tests \
  --package-manager=npm --defaults

cd ix-icon-verify
npm install @siemens/ix-icons@3.4.0 @siemens/ix-angular@5.1.0 @siemens/ix@5.1.0 zone.js
npm install -D playwright

# enable zone.js polyfill (matches vilocify)
node -e "
const fs = require('fs');
const p = 'angular.json';
const j = JSON.parse(fs.readFileSync(p, 'utf8'));
const opts = j.projects['ix-icon-verify'].architect.build.options;
opts.polyfills = ['zone.js'];
fs.writeFileSync(p, JSON.stringify(j, null, 2));
console.log('zone.js polyfill enabled');
"

echo '--- versions ---'
node -p "require('./node_modules/@siemens/ix-icons/package.json').version"
node -p "require('./node_modules/@siemens/ix-angular/package.json').version"
node -p "require('./node_modules/playwright/package.json').version"
ls /usr/bin/google-chrome
