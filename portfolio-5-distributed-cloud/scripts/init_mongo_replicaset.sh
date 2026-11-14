#!/usr/bin/env bash
# Initialises the optional 3-node MongoDB replica set started with: docker compose --profile mongo-rs up -d
set -euo pipefail
docker compose exec -T mongors1 mongosh --quiet --eval '
rs.initiate({_id: "rs0", members: [
  {_id: 0, host: "mongors1:27017", priority: 2},
  {_id: 1, host: "mongors2:27017", priority: 1},
  {_id: 2, host: "mongors3:27017", priority: 1}]});
'
sleep 10
docker compose exec -T mongors1 mongosh --quiet --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'
echo
echo "Failover test:  docker compose stop mongors1   then:"
echo "docker compose exec -T mongors2 mongosh --quiet --eval 'rs.status().members.forEach(m => print(m.name, m.stateStr))'"
echo "(a new PRIMARY is elected automatically; restart with: docker compose start mongors1)"
