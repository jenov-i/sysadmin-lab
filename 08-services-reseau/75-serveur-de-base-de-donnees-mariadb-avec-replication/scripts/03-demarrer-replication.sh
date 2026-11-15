#!/bin/bash
# Branche le réplica sur le primaire et démarre la réplication GTID.
# Le mot de passe du compte repl est lu dans /root/.repl-password (mode 600),
# déposé hors dépôt : il n'apparaît ni ici ni dans les journaux.
set -euo pipefail

PRIMAIRE=${1:-192.168.99.11}
PW_FILE=${2:-/root/.repl-password}
[ -r "$PW_FILE" ] || { echo "mot de passe introuvable : $PW_FILE"; exit 1; }
PW=$(cat "$PW_FILE")

mariadb <<SQL
STOP SLAVE;
CHANGE MASTER TO
  MASTER_HOST='$PRIMAIRE',
  MASTER_USER='repl',
  MASTER_PASSWORD='$PW',
  MASTER_USE_GTID=slave_pos;
START SLAVE;
SQL

sleep 3
echo "--- état de la réplication"
mariadb -e "SHOW SLAVE STATUS\G" | grep -E \
  "Master_Host|Master_User|Using_Gtid|Gtid_IO_Pos|Slave_IO_Running|Slave_SQL_Running|Seconds_Behind_Master|Last_IO_Error|Last_SQL_Error|Master_Log_File|Read_Master_Log_Pos|Exec_Master_Log_Pos"
