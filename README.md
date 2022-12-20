# Tendermint hybrid network

PoC MANY hybrid network using Tendermint 0.34 and 0.35

## Requirements

- docker
- docker-compose
- jq
- bash
- GNU make
- coreutils
- Tendermint 0.34 compatible `many-framework` binaries
- Tendermint 0.35 compatible `many-framework` binaries
- (optional, tests) bats-core >= 1.7 

## Quick start

Place the Tendermint 0.34 and 0.35 compatible binaries in their respective `tmXX-bins` folder. E.g.

```bash
tmXX-bins
├── http_proxy
├── idstore-export
├── kvstore
├── ledger
├── many-abci
├── many-kvstore
└── many-ledger
```

Run 

```bash
# Use `make start-nodes-background` instead to start cluster detached from the terminal
$ make start-nodes
```

to run a hybrid 4 nodes cluster, where 2 nodes runs on TM 0.34 and 2 nodes runs on TM 0.35.

### Custom number of nodes

The number of nodes running on each TM version can be modified by setting the `NB_NODES_34` and `NB_NODES_35` variables.

E.g.
```bash
# Start a cluster with 2 TM 0.34 nodes and 6 TM 0.35 nodes
$ make NB_NODES_34=2 NB_NODES_35=6 start-nodes
```

## Resiliency tests

Resiliency tests can be run using

```bash
$ cd bats/tests
$ bats .
```

## Clean

Run the following to remove all generated files and docker containers

```bash
$ make clean
```

NOTE: This command will NOT remove the generated `hybrid/*` Docker image