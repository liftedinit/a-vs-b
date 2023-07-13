# Hybrid network

PoC MANY hybrid network

A hybrid network can consist of

- Different Tendermint versions
- Different `many-rs` versions
- Both

Tendermint 0.34 and 0.35 configuration files are supported.

## Requirements

- docker
- docker-compose
- jq
- bash
- GNU make
- coreutils
- (optional, tests) bats-core >= 1.7

## Quick start

Place the binaries in their respective `X-bins` folder. E.g.

```bash
X-bins
├── (optional) abci_migrations.json
├── (optional) ledger_migrations.json
├── many
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

to run a hybrid 4 nodes cluster, where the default is to run 4 nodes on TM 0.34

### Custom number of nodes

The number of nodes running can be modified by setting the `NB_NODES_A` and `NB_NODES_B` variables.

E.g.
```bash
# Start a cluster with 2 `A` nodes and 6 `B` nodes
$ make NB_NODES_A=2 NB_NODES_B=6 start-nodes
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
