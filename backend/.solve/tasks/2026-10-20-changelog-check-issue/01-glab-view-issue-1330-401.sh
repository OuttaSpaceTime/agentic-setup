# bash .solve/tasks/2026-10-20-changelog-check-issue/current.sh
# Step: read-only look at issue #1330 before overwriting its description
# Look at: title, and whether the description holds anything worth keeping
glab issue view 1330 --repo vilocify/vilocify-portal
