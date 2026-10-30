# Laptop matching — optimize Felix Eschey's 100 points

Colleagues each spread 100 points over 14 ThinkPad models; laptops are then
assigned by a max-weight bipartite matching. Goal: find laptops that are (a) good
for dev side-projects (RAM) and (b) under-contested, so Felix's points win one.

## data.csv
23 people who bid on specific models, copied verbatim from the sheet (trailing
Erklaerung column dropped). Columns after `name`: kein, keine_praef, then 14
laptop codes, then `gesamt`. Excluded: 25 "Kein Notebook" people (out of the
running) and 2 pure "keine Praeferenz" floaters (no effect on a specific model).

## 01-competition-per-laptop.rb
Prints transcription checksum (each row must sum to its gesamt), flags sheet
totals != 100 (Sven Ellis = 200, an original data error), then lists every
laptop with its bidders sorted high->low. Felix's own bids marked `<= YOU`.
Run:    ruby .solve/tasks/2026-07-08-laptop-matching/01-competition-per-laptop.rb
Verify: mismatches line says "none"; spot-check a row against the sheet.
