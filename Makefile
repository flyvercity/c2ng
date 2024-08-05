# Environment

src := $(wildcard \
	c2ng/common/*.py \
	c2ng/service/backend/*.py \
	c2ng/service/backend/net_providers/*.py \
	c2ng/service/did/*.py \
	c2ng/uss-sim/src/*.py \
	c2ng/uas-sim/src/*.py \
)

deps-check:
	which python3
	which pip3
	pip3 --require-virtualenv install -r requirements.dev.txt -q
	which git
	which docker
	which docker-compose

.deps-check-docs:
	which darglint
	which pdflatex
	which lazydocs
	which pandoc
	touch $@

# Core and simulators

build-core: 
	docker build ${C2NG_DOCKER_BUILD_ARGS} -t c2ng:latest -f docker/core/Dockerfile .

build-uss-sim:
	docker build ${C2NG_DOCKER_BUILD_ARGS} -t c2ng-uss-sim:latest -f docker/uss_sim/Dockerfile .

build-uas-sim:
	docker build ${C2NG_DOCKER_BUILD_ARGS} -t c2ng-uas-sim:latest -f docker/uas_sim/Dockerfile .

build: deps-check build-core build-uss-sim build-uas-sim

docker/core/config/c2ng/private.pem:
	./cli.sh cryptokeys

prerun: docker/core/config/c2ng/private.pem

# Decentralized Identities Support

did_files := $(addprefix docker/core/config/did/, \
	issuer.pem \
	issuer.did \
	sim-drone-id.pem \
	sim-drone-id.did \
	sim-drone-id.jwt \
)

$(did_files):
	./scripts/did-init.sh

did: $(did_files)

# Integrated start

up: build prerun did
	./scripts/ctrl-core.sh up -d
	./scripts/ctrl-sims.sh stop
	./scripts/ctrl-sims.sh create

start: up
	./cli.sh keycloak

# Tests

build-unit-tests:
	docker build ${C2NG_DOCKER_BUILD_ARGS} -t c2ng-unit-tests:latest -f test/docker/Dockerfile .

test: build-unit-tests
	./scripts/test-unit.sh

# API specification

generate: docbuild
	./cli.sh genapi

darglint: $(src)
	darglint -s google -z full $(src)

