#!/bin/bash
set -e
echo "--- installed ---"
node -p "require('./node_modules/@siemens/ix-icons/package.json').version"
node -p "require('./node_modules/@siemens/ix-angular/package.json').version"
node -p "require('./node_modules/@siemens/ix/package.json').version"
echo "--- latest on npm ---"
npm view @siemens/ix-icons version
npm view @siemens/ix-angular version
npm view @siemens/ix version
