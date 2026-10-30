#!/bin/bash
set -e
cd ~/Code/Misc
rm -rf ix-icon-lazy-route-repro
npx --yes @angular/cli@22 new ix-icon-lazy-route-repro \
  --standalone --routing --style=css --skip-git --skip-tests \
  --package-manager=npm --defaults

cd ix-icon-lazy-route-repro
npm install @siemens/ix-icons@3.4.0 @siemens/ix-angular@5.1.0 @siemens/ix@5.1.0

echo "--- installed versions ---"
node -p "require('./node_modules/@siemens/ix-icons/package.json').version"
node -p "require('./node_modules/@siemens/ix-angular/package.json').version"
