install:
	./.ci/install.sh
tests:
	./.ci/kong-pongo/pongo.sh lint
	./.ci/kong-pongo/pongo.sh run ./spec
