NB_NODES_34 := 2
NB_NODES_35 := 2

35_MIN := $(shell echo $$(( $(NB_NODES_34) + 1 )))
35_MAX := $(shell echo $$(( $(NB_NODES_34) + $(NB_NODES_35) )))

NODES_34 := $(addsuffix .done,$(addprefix genfiles/node34_,$(shell seq 1 ${NB_NODES_34})))
NODES_35 := $(addsuffix .done,$(addprefix genfiles/node35_,$(shell seq ${35_MIN} ${35_MAX})))
DOCKER := docker run --user $$(id -u) --rm
TM_34 := tendermint/tendermint:v0.34.24
TM_35 := tendermint/tendermint:v0.35.4
OUTPUT_DIR = ${PWD}/genfiles
TM_34_ROOT := ${OUTPUT_DIR}/node34
TM_35_ROOT := ${OUTPUT_DIR}/node35
VALIDATOR_COMMAND = jq '{ address: .address, pub_key: .pub_key }' "${ROOT}_$*/tendermint/config/priv_validator_key.json" | jq ".name = \"tendermint-$*\" | .power = \"1000\"" > $@

SHELL := bash

# Initialize Tendermint configuration and keys
# Copy the ledger staging file
define TM_INIT =
	mkdir -p "${ROOT}_$*/tendermint"
	mkdir -p "${ROOT}_$*/persistent-ledger"
	$(DOCKER) -v ${ROOT}_$*/tendermint:/tendermint ${TM} init validator
	$(DOCKER) -v ${ROOT}_$*/:/export alpine/openssl genpkey -algorithm Ed25519 -out /export/ledger.pem
	$(DOCKER) -v ${ROOT}_$*/:/export alpine/openssl genpkey -algorithm Ed25519 -out /export/abci.pem
	cp ledger_state.json5 ${ROOT}_$*/
endef

# Retrieve the Tendermint node ID
define TM_NODE_ID =
	id=$$($(DOCKER) -v ${ROOT}_$*/tendermint:/tendermint ${TM} show-node-id) ;\
	echo "$${id}@tendermint-$*:26656" > $@
endef

# Generate and copy the final genesis file
define TM_GENESIS =
	jq --slurpfile v ${OUTPUT_DIR}/node.validators '.validators = $$v | .chain_id = "many-e2e-dev" | .genesis_time = "2022-12-19T00:00:00.000000000Z"' "${ROOT}_$*/tendermint/config/genesis.json" > ${OUTPUT_DIR}/genesis_${NODE_TYPE}_$*.json
	cp ${OUTPUT_DIR}/genesis_${NODE_TYPE}_$*.json ${ROOT}_$*/tendermint/config/genesis.json
endef

# Build the ledger and ABCI docker images
define DOCKER_BUILD =
	mkdir -p ${OUTPUT_DIR}
	docker build . -f dockerfiles/Dockerfile.many-abci-${TM_VERSION} -t hybrid/many-abci-${TM_VERSION}
	docker build . -f dockerfiles/Dockerfile.many-ledger-${TM_VERSION} -t hybrid/many-ledger-${TM_VERSION}
	touch $@
endef

.PHONY: clean
clean:
	make stop-nodes
	rm -rf genfiles

genfiles/build34: TM_VERSION := 34
genfiles/build34:
	$(DOCKER_BUILD)

genfiles/build35: TM_VERSION := 35
genfiles/build35:
	$(DOCKER_BUILD)

# Extract TM 34 validator
genfiles/node34_%.validator: ROOT := ${TM_34_ROOT}
genfiles/node34_%.validator: genfiles/node34_%.init
	$(VALIDATOR_COMMAND)

# Initialize TM 34 node configuration, persitent storage and keys
genfiles/node34_%.init: ROOT := ${TM_34_ROOT}
genfiles/node34_%.init: TM := ${TM_34}
genfiles/node34_%.init:
	$(TM_INIT)

# Retrieve TM 34 node ID
genfiles/node34_%.nodeid: ROOT := ${TM_34_ROOT}
genfiles/node34_%.nodeid: TM := ${TM_34}
genfiles/node34_%.nodeid: genfiles/node34_%.init
	$(TM_NODE_ID)

# Generate TM 34 node configuration and genesis files
$(NODES_34): ROOT := ${TM_34_ROOT}
$(NODES_34): TM := ${TM_34}
$(NODES_34): NODE_TYPE := node34
$(NODES_34): UPDATE_CMD = ${PWD}/update_toml_key.sh ${ROOT}_$*/tendermint/config/config.toml
$(NODES_34): genfiles/node34_%.done: genfiles/node.validators genfiles/node_%.config
	$(UPDATE_CMD) '' proxy_app "\"tcp:\/\/abci-$*:26658\/\""
	$(UPDATE_CMD) '' moniker "\"many-tendermint-$*\""
	$(UPDATE_CMD) consensus timeout_commit "\"2s\""
	$(UPDATE_CMD) consensus timeout_precommit "\"2s\""
	$(UPDATE_CMD) p2p persistent_peers "\"$$(cat ${OUTPUT_DIR}/node_$*.config)\""
	$(UPDATE_CMD) p2p max_packet_msg_payload_size "1400"
	$(UPDATE_CMD) p2p pex "false"
	$(TM_GENESIS)
	touch $@

# Concatenate all node IDs but self
# The value from this target will be used to set the `p2p persistent peers` configuration file entry
genfiles/node_%.config: $(NODES_34:%done=%nodeid) $(NODES_35:%done=%nodeid)
	shopt -s extglob; \
 	eval 'paste -d "," ${OUTPUT_DIR}/node*_!($*).nodeid > $@'

# Concatenate all node validators
genfiles/node.validators: $(NODES_34:%done=%validator) $(NODES_35:%done=%validator)
	cat ${OUTPUT_DIR}/*.validator | jq -c > ${OUTPUT_DIR}/node.validators

# Extract TM 35 validator
genfiles/node35_%.validator: ROOT := ${TM_35_ROOT}
genfiles/node35_%.validator: genfiles/node35_%.init
	$(VALIDATOR_COMMAND)

# Initialize TM 35 node configuration, persitent storage and keys
genfiles/node35_%.init: ROOT := ${TM_35_ROOT}
genfiles/node35_%.init: TM := ${TM_35}
genfiles/node35_%.init:
	$(TM_INIT)

# Retrieve TM 35 node ID
genfiles/node35_%.nodeid: ROOT := ${TM_35_ROOT}
genfiles/node35_%.nodeid: TM := ${TM_35}
genfiles/node35_%.nodeid: genfiles/node35_%.init
	$(TM_NODE_ID)

# Generate TM 35 node configuration and genesis files
$(NODES_35): ROOT := ${TM_35_ROOT}
$(NODES_35): TM := ${TM_35}
$(NODES_35): NODE_TYPE := node35
$(NODES_35): UPDATE_CMD = ${PWD}/update_toml_key.sh ${ROOT}_$*/tendermint/config/config.toml
$(NODES_35): genfiles/node35_%.done: genfiles/node.validators genfiles/node_%.config
	$(UPDATE_CMD) '' proxy-app "\"tcp:\/\/abci-$*:26658\/\""
	$(UPDATE_CMD) '' moniker "\"many-tendermint-$*\""
	$(UPDATE_CMD) consensus timeout-commit "\"2s\""
	$(UPDATE_CMD) consensus timeout-precommit "\"2s\""
	$(UPDATE_CMD) p2p persistent-peers "\"$$(cat ${OUTPUT_DIR}/node_$*.config)\""
	$(UPDATE_CMD) p2p pex "false"
	$(TM_GENESIS)
	touch $@

# Generate the docker compose file
genfiles/docker_compose.json: $(NODES_34) $(NODES_35)
	docker pull bitnami/jsonnet
	docker run --user $$(id -u):$$(id -g) --rm -v "${PWD}:/volume:ro" -v "${OUTPUT_DIR}:/genfiles" bitnami/jsonnet \
		/volume/docker-compose.jsonnet \
		--tla-code nb_nodes_34=$(NB_NODES_34) \
		--tla-code nb_nodes_35=$(NB_NODES_35) \
		--tla-code user=$$(id -u) \
		-o /$@

.PHONY: start-nodes
start-nodes: genfiles/build34 genfiles/build35 genfiles/docker_compose.json
	docker-compose -f ${OUTPUT_DIR}/docker_compose.json -p e2e-ledger up

.PHONY: start-nodes-background
start-nodes-background: genfiles/build34 genfiles/build35 genfiles/docker_compose.json
	docker-compose -f ${OUTPUT_DIR}/docker_compose.json -p e2e-ledger up --detach

.PHONY: stop-nodes
stop-nodes:
	docker-compose -f ${OUTPUT_DIR}/docker_compose.json -p e2e-ledger down

.PHONY: stop-single-node
stop-single-node:
	docker-compose -f ${OUTPUT_DIR}/docker_compose.json -p e2e-ledger stop tendermint-$(NODE)
	docker-compose -f ${OUTPUT_DIR}/docker_compose.json -p e2e-ledger stop abci-$(NODE)
	docker-compose -f ${OUTPUT_DIR}/docker_compose.json -p e2e-ledger stop ledger-$(NODE)

.PHONY: start-single-node-background
start-single-node-background: genfiles/build34 genfiles/build35 genfiles/docker_compose.json
	docker-compose -f ${OUTPUT_DIR}/docker_compose.json -p e2e-ledger up --detach tendermint-$(NODE)
	docker-compose -f ${OUTPUT_DIR}/docker_compose.json -p e2e-ledger up --detach abci-$(NODE)
	docker-compose -f ${OUTPUT_DIR}/docker_compose.json -p e2e-ledger up --detach ledger-$(NODE)
