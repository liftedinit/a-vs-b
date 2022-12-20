GIT_ROOT="$BATS_TEST_DIRNAME/../../"

load '../test_helper/load'

function setup() {
    mkdir "$BATS_TEST_ROOTDIR"
    cd "$GIT_ROOT" || exit

    (
      make clean
    ) > /dev/null
}

function teardown() {
    (
      cd "$GIT_ROOT" || exit
      make stop-nodes
    ) 2> /dev/null
    cd "$GIT_ROOT/bats/tests" || exit
}

function ledger() {
    local pem="$1"
    local port="$2"
    shift 2
    run "$GIT_ROOT/tm35-bins/ledger" --pem "$pem" "http://localhost:${port}/" "$@"
}

function check_consistency() {
    local pem="$1"
    local expected_balance="$2"
    shift 2

    for port in "$@"; do
        ledger "$pem" "$port" balance
        assert_output --partial " $expected_balance MFX "
    done
}

@test "$SUITE: TM34 node can statesync" {
    for i in {2..4}
    do
        make NB_NODES_34=0 NB_NODES_35=4 NODE="${i}" start-single-node-background || {
          echo Could not start nodes... >&3
          exit 1
        }
    done

    # Give time to the servers to start.
    sleep 30
    timeout 60s bash <<EOT
        while ! many message --server http://localhost:8002 status; do
          sleep 1
        done >/dev/null
EOT

    check_consistency "$(pem 1)" 1000000000 8004 8002 8003
    ledger "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    check_consistency "$(pem 1)" 999999000 8004 8002 8003
    check_consistency "$(pem 2)" 1000 8004 8002 8003

    ledger "$(pem 1)" 8002 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8002 send "$(identity 2)" 1000 MFX
    check_consistency "$(pem 1)" 999997000 8004 8002 8003
    check_consistency "$(pem 2)" 3000 8004 8002 8003

    ledger "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8003 send "$(identity 2)" 1000 MFX
    check_consistency "$(pem 1)" 999994000 8004 8002 8003
    check_consistency "$(pem 2)" 6000 8004 8002 8003

    ledger "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    ledger "$(pem 1)" 8004 send "$(identity 2)" 1000 MFX
    check_consistency "$(pem 1)" 999990000 8004 8002 8003
    check_consistency "$(pem 2)" 10000 8004 8002 8003

    # Get the blockchain height and hash
    info=$(many_message --id=1 --port=8002 'blockchain.info' '{}')
    hash=$(echo ${info} | grep -Po "0: h'\K\w+")
    height=$(echo ${info} | grep -Po "1: \K\d+")

    # Create blocks for 2mins
    sleep 30

    make NB_NODES_34=0 \
         NB_NODES_35=4 \
         NODE="1" \
         STATESYNC_TRUSTED_HEIGHT=${height} \
         STATESYNC_TRUSTED_HASH=${hash} \
         enable_statesync_35

    make NB_NODES_34=0 \
         NB_NODES_35=4 \
         NODE="1" start-single-node-background || {
      echo Could not start nodes... >&3
      exit 1
    }

    # Give time to the servers to start.
    sleep 30
    timeout 60s bash <<EOT
        while ! many message --server http://localhost:8001 status; do
          sleep 1
        done >/dev/null
EOT
    sleep 30
    check_consistency "$(pem 1)" 999990000 8001 8002 8003 8004
    check_consistency "$(pem 2)" 10000 8001 8002 8003 8004
}
