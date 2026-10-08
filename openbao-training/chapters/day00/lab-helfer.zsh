# --- OpenBao-Lab ---
alias bdev='bao server -dev -dev-root-token-id=root'
labenv() { export BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=root; }
alias bwho='bao token lookup -format=json | jq -c ".data | {display_name, policies, ttl}"'
