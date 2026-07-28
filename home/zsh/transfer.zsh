# Encrypted point-to-point data transfer through a public relay host.
skyhook() {
  local host="kevingisi.com"
  local port="8675"
  local password
  password=$(openssl rand -base64 24)

  >&2 echo "On the sending machine, append the following: "
  >&2 echo " | openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:'$password' > /dev/tcp/$host/$port"
  >&2 echo ""

  ssh $host "trap 'kill 0' EXIT; exec nc -l -p '$port' -q 1" | openssl enc -d -aes-256-cbc -salt -pbkdf2 -pass pass:"$password"
}

skydive() {
  local host="kevingisi.com"
  local port="8675"
  local password
  password=$(openssl rand -base64 24)

  >&2 echo "On the receiving machine, run the following: "
  >&2 echo "cat < /dev/tcp/$host/$port | openssl enc -d -aes-256-cbc -salt -pbkdf2 -pass pass:'$password'"
  >&2 echo ""

  openssl enc -aes-256-cbc -salt -pbkdf2 -pass pass:"$password" | ssh $host "trap 'kill 0' EXIT; exec nc -l -p '$port' -q 1"
}
