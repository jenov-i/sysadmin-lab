#!/bin/bash
# Résumé compact pour la capture console : sources et suivi chrony.
set -uo pipefail

echo "chrony — sources et état du suivi"
echo "service : $(systemctl is-enabled chrony) / $(systemctl is-active chrony)"
echo
echo "--- sources ---"
chronyc -n sources
echo
echo "--- suivi ---"
chronyc tracking | grep -E "Reference ID|Stratum|System time|Last offset|RMS offset|Frequency|Residual freq|Skew|Root delay|Update interval"
echo
echo "--- réglage noyau appliqué par chrony ---"
chronyc tracking | grep -E "Leap status"
echo "PPS : $(cat /sys/class/pps/pps0/assert 2>/dev/null || echo 'aucun PPS dans la VM')"
