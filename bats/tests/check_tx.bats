GIT_ROOT="$BATS_TEST_DIRNAME/../../"

load '../test_helper/load'

function setup() {
    mkdir "$BATS_TEST_ROOTDIR"
    cd "$GIT_ROOT" || exit

    # Build custom Tendermint image containing the `iproute2` package
    docker build . --platform linux/x86_64 -f dockerfiles/Dockerfile.tendermint_iproute2_0.34.24 -t tendermint_iproute2:v0.34.24

    (
      make clean
      for i in {1..3}
      do
          make NB_NODES_A=2 \
               NB_NODES_B=2 \
               NODE="${i}" \
               TM_A=tendermint_iproute2:v0.34.24 \
               TM_B=tendermint_iproute2:v0.34.24 start-single-node-background || {
            echo Could not start nodes... >&3
            exit 1
          }
      done
    ) > /dev/null

    # Give time to the servers to start.
    sleep 30
    timeout 30s bash <<EOT
    while ! many message --server http://localhost:8003 status; do
      sleep 1
    done >/dev/null
EOT
}

function teardown() {
    (
      cd "$GIT_ROOT" || exit 1
      make stop-nodes
    ) 2> /dev/null
    cd "$GIT_ROOT/bats/tests" || exit 1
}

@test "$SUITE: Duplicate transactions on node reset" {
    local height
    local tx_id
    local tx_count

    # Add a 1s network delay to node 3 containers
    docker exec -u root e2e-ledger-tendermint-3-1 tc qdisc add dev eth0 root netem delay 1s
    docker exec -u root e2e-ledger-abci-3-1 tc qdisc add dev eth0 root netem delay 1s
    docker exec -u root e2e-ledger-ledger-3-1 tc qdisc add dev eth0 root netem delay 1s

    # Send a transaction
    ledger_a "$(pem 1)" 8001 send "$(identity 2)" 1000 MFX

    # Verify the transaction has been processed
    many_a "$(pem 1)" 8001 events.list '{}'
    assert_output --partial "0: 1"

    # Get current blockchain height
    height=$(many_a "$(pem 1)" 8001 blockchain.info '{}' | grep -Po '1: \d+' | cut -d " " -f 2)
    echo "# Height: $height"

    # Get the transaction id
    tx_id=$(many_a "$(pem 1)" 8001 blockchain.block '{0: {1: '"$height"'}}' | awk '/5: \[/,/\],/' | grep -Po "0: h'(.*)'," | sed -E "s/0: h'(.*)',/\1/")
    echo "# Tx id: $tx_id"

    # Cycle the nodes
    for i in {1..4};
    do
        make NODE=${i} stop-single-node;
        sleep 2;
        make NODE=${i} start-single-node-background;
    done

    # Check for duplicate transactions
    sleep 30
    tx_count=$(many_a "$(pem 1)" 8001 blockchain.list '{}' | grep -o $tx_id | wc -l)
    echo "# Tx count: $tx_count"
    assert_equal "$tx_count" "1"
}