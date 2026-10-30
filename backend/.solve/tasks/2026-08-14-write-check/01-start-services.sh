# sh .solve/tasks/2026-08-14-write-check/01-start-services.sh
docker start languagetool 2>/dev/null || docker run -d --name languagetool -p 8010:8010 erikvl87/languagetool
curl -sf http://localhost:3456/api/review >/dev/null && echo "dev-server: up" || echo "dev-server: down"
