#!/bin/sh

pid=0

# SIGTERM handler
sigterm_handler() {
  if [ $pid -ne 0 ]; then
    kill -SIGTERM "$pid"
    wait "$pid"
  fi
  stop
  exit 143; # 128 + 15 -- SIGTERM
}

# Setup trap for SIGTERM signal
# Kill last process and call sigterm_handler
trap 'kill ${!}; sigterm_handler' SIGTERM

# Path to fence lock file.
if [ -z ${FENCE_LOCK_FILE+x} ]; then
  FENCE_LOCK_FILE='/var/lib/postgresql/data/fence_lock'
fi

# FENCE_VARIABLE should contain a variable expression that
# uniquely identifies this instance of Postgres. Default
# is $HOSTNAME.
if [ -z ${FENCE_VARIABLE+x} ]; then
  FENCE_VARIABLE='$HOSTNAME'
fi

# Evaluates the variable
FENCE_VALUE=$(eval "echo $FENCE_VARIABLE")

function start {
  if [[ -f "$FENCE_LOCK_FILE" ]]; then
    if [[ $(cat "$FENCE_LOCK_FILE") != "$FENCE_VALUE" ]]; then
      echo "Lock already exists from another instance. Exiting."
      exit 1
    else
      echo "Lock already exists for this node."
    fi
  else
    echo "Creating fence lock file."
    echo "$FENCE_VALUE" > "$FENCE_LOCK_FILE"
  fi
}

function stop {
  if [[ -f "$FENCE_LOCK_FILE" ]]; then
    if [[ $(cat "$FENCE_LOCK_FILE") != "$FENCE_VALUE" ]]; then
      echo "Lock is from another instance. Will not remove."
      exit 1
    else
      echo "Removing fence lock file."
      rm "$FENCE_LOCK_FILE"
    fi
  else
    echo "No lock file found to remove."
  fi
}

start
/usr/local/bin/postgres "$@" &
pid="$!"

# wait forever
while true
do
  tail -f /dev/null & wait ${!}
done
