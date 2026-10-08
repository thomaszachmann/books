baoup() {
  bao server -dev -dev-root-token-id=root > ~/bao-lab/dev.log 2>&1 &
  export BAO_ADDR=http://127.0.0.1:8200 BAO_TOKEN=root
  until bao status >/dev/null 2>&1; do sleep 0.5; done
  echo "OpenBao bereit (PID $!)"
}
