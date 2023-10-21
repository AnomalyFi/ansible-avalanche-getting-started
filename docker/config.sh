#!/bin/bash

CHAIN_ID=${CHAIN_ID:-1.10.9}
SUBNET_ID=${SUBNET_ID:-29uVeLPJB1eQJkzRemU8g8wZDw5uJRqpab5U2mX9euieVwiEbL}


TMPDIR=/home/noah/code/nodekit-seq/tmp

for v in {1..5}; do
  sed -i 's/"track-subnets": ".*"/"track-subnets": "29uVeLPJB1eQJkzRemU8g8wZDw5uJRqpab5U2mX9euieVwiEbL"/' "data/conf/validator0$v/conf/node.json"
  cat <<EOF > data/conf/validator0$v/conf/$CHAIN_ID/config.json
  {
    "mempoolSize": 10000000,
    "mempoolPayerSize": 10000000,
    "mempoolExemptPayers":["token1rvzhmceq997zntgvravfagsks6w0ryud3rylh4cdvayry0dl97nsjzf3yp"],
    "parallelism": 5,
    "verifySignatures":true,
    "storeTransactions": false,
    "streamingBacklogSize": 10000000,
    "trackedPairs":["*"],
    "logLevel": "info",
    "continuousProfilerDir":"/home/noah/code/nodekit-seq/tmp/tokenvm-e2e-profiles/*",
    "stateSyncServerDelay": 0
  }
  EOF
  cat data/conf/validator0$v/conf/$CHAIN_ID/config.json

  cat <<EOF > data/conf/validator0$v/conf/subnets/$SUBNET_ID.json
  {
    "proposerMinBlockDelay": 0,
    "proposerNumHistoricalBlocks": 768
  }
  EOF
  cat data/conf/validator0$v/conf/subnets/$SUBNET_ID.json
done


docker-compose restart
