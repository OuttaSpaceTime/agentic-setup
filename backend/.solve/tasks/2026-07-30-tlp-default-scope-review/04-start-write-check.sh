# bash .solve/tasks/2026-07-30-tlp-default-scope-review/04-start-write-check.sh
cd /home/felix/Code/Misc/write-check || exit 1
docker start languagetool 2>/dev/null || docker run -d --name languagetool -p 8010:8010 erikvl87/languagetool
curl -sf http://localhost:3456/api/review >/dev/null 2>&1 || (nohup npm run dev >/tmp/write-check-dev.log 2>&1 &)
for _ in $(seq 1 45); do curl -sf http://localhost:3456/api/review >/dev/null 2>&1 && break; sleep 1; done
curl -sf http://localhost:3456/api/review >/dev/null 2>&1 && echo "app up" || echo "app NOT up, see /tmp/write-check-dev.log"
xdg-open http://localhost:3456 >/dev/null 2>&1 &
