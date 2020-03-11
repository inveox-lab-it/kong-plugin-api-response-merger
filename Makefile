install:
	./.ci/install.sh
test:
	./.ci/kong-pongo/pongo.sh run ./spec
