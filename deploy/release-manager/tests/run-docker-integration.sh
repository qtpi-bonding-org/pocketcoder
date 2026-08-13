#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
module_root=$(CDPATH= cd -- "$script_dir/.." && pwd)
repo_root=$(CDPATH= cd -- "$module_root/../.." && pwd)
fixture_image=pocketcoder-release-integration-fixture:local
runner_image=docker@sha256:27a51d5ab1cd38d9eeaba7b415b8c07bc10c31e1cf1ec8d78f6413fcfab3f44f
temporary=$(mktemp -d)
runner_name=pocketcoder-release-integration-$$

cleanup() {
  rm -rf "$temporary"
}
trap cleanup EXIT

install -d "$temporary/rootfs/app"
CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go -C "$repo_root/server/pocketbase" build -trimpath \
  -o "$temporary/rootfs/app/pocketbase-fixture" \
  "$module_root/testdata/pocketbase-fixture/main.go"
COPYFILE_DISABLE=1 tar --no-xattrs -C "$temporary/rootfs" -cf - . | docker import \
  --change 'WORKDIR /app' \
  --change 'ENTRYPOINT ["/app/pocketbase-fixture"]' \
  --change 'CMD ["serve","--http=0.0.0.0:8090"]' \
  - "$fixture_image" >/dev/null

CGO_ENABLED=0 GOOS=linux GOARCH=amd64 \
  go -C "$module_root" test -c -tags=integration \
  -o "$temporary/release-integration.test" ./internal/transaction

docker run --rm \
  --name "$runner_name" \
  --add-host host.docker.internal:host-gateway \
  --env POCKETCODER_DOCKER_INTEGRATION=1 \
  --env POCKETCODER_RELEASE_FIXTURE_IMAGE="$fixture_image" \
  --env POCKETCODER_TEST_DOCKER_HOST=host.docker.internal \
  --volume /var/run/docker.sock:/var/run/docker.sock \
  --volume /var/lib/docker/volumes:/var/lib/docker/volumes \
  --volume "$temporary/release-integration.test:/release-integration.test:ro" \
  --entrypoint /release-integration.test \
  "$runner_image" -test.v
