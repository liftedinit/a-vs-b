GIT_ROOT="$BATS_TEST_DIRNAME/../../"

load '../test_helper/load'

function setup() {
    mkdir "$BATS_TEST_ROOTDIR"
    cd "$GIT_ROOT" || exit

    (
      make clean
        for i in {2..4}
        do
            make NB_NODES_34=2 NB_NODES_35=2 NODE="${i}" start-single-node-background || {
              echo Could not start nodes... >&3
              exit 1
            }
        done
    ) > /dev/null

    # Give time to the servers to start.
    sleep 30
    timeout 30s bash <<EOT
    while ! many message --server http://localhost:8002 status; do
      sleep 1
    done >/dev/null
EOT
}

function teardown() {
    (
      cd "$GIT_ROOT" || exit 1
      make stop-nodes
    ) 2> /dev/null
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

@test "$SUITE: Bootstrap TM34 node with poor man's TM34 snapshot" {

    # Create some transactions BEFORE the snapshot
    check_consistency "$(pem 1)" 1000000000 8002 8003 8004
    ledger "$(pem 1)" 8002 send "$(identity 2)" 1000 MFX
    sleep 4 # One consensus round.
    check_consistency "$(pem 1)" 999999000 8002 8003 8004
    check_consistency "$(pem 2)" 1000 8002 8003 8004

    ledger "$(pem 1)" 8002 send "$(identity 2)" 2000 MFX
    sleep 4 # One consensus round.
    check_consistency "$(pem 1)" 999997000 8002 8003 8004
    check_consistency "$(pem 2)" 3000 8002 8003 8004

    ledger "$(pem 1)" 8003 send "$(identity 2)" 3000 MFX
    sleep 4 # One consensus round.
    check_consistency "$(pem 1)" 999994000 8002 8003 8004
    check_consistency "$(pem 2)" 6000 8002 8003 8004

    ledger "$(pem 1)" 8004 send "$(identity 2)" 4000 MFX
    sleep 4 # One consensus round.
    check_consistency "$(pem 1)" 999990000 8002 8003 8004
    check_consistency "$(pem 2)" 10000 8002 8003 8004

    sleep 4

    # Create the snapshot on a block WITHOUT any transaction
    # Important for RC7 because of https://github.com/liftedinit/many-framework/issues/289
    make NB_NODES_34=2 NB_NODES_35=2 NODE="2" create_snapshot

    sleep 4

    # Create some transactions AFTER the snapshot
    # The new node should catch those up using the regular fastsync mechanism
    ledger "$(pem 1)" 8004 send "$(identity 2)" 10000 MFX
    check_consistency "$(pem 1)" 999980000 8002 8003 8004
    check_consistency "$(pem 2)" 20000 8002 8003 8004

    ledger "$(pem 1)" 8003 send "$(identity 2)" 10000 MFX
    check_consistency "$(pem 1)" 999970000 8002 8003 8004
    check_consistency "$(pem 2)" 30000 8002 8003 8004

    sleep 4

    # Copy the snapshot to the new node and boot it up
    make NB_NODES_34=2 NB_NODES_35=2 FROM=2 TO=1 copy_snapshot
    make NB_NODES_34=2 NB_NODES_35=2 NODE="1" start-single-node-background || {
          echo Could not start nodes... >&3
          exit 1
        }

      # Give time to the servers to start.
    sleep 30
    timeout 30s bash <<EOT
    while ! many message --server http://localhost:8001 status; do
      sleep 1
    done >/dev/null
EOT

    check_consistency "$(pem 1)" 999970000 8001 8002 8003 8004
    check_consistency "$(pem 2)" 30000 8001 8002 8003 8004
}
