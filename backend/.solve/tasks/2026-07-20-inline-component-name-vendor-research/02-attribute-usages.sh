#!/usr/bin/env bash
paths="app lib"
echo "### distinctive columns (raw grep) ###"
for col in abbreviation sec_url; do
  echo "== $col =="; rg -n "$col" $paths
done
echo "### noisy columns (anchored to a name/vendor receiver) ###"
for expr in 'component_vendor\.' 'component_name\.' 'vendor\.name' 'vendor\.url' 'component_vendor\.url' 'vendor\.active' 'name\.active'; do
  echo "== $expr =="; rg -n "$expr" $paths
done
