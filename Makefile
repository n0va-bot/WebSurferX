NSS_DIR=/usr

.PHONY: all build clean run sync_client

all: build

sync_client:
	@echo "Building Rust sync_client..."
	@cd sync_client && NSS_DIR="$(NSS_DIR)" cargo build
	@echo "sync_client built successfully."

build: sync_client
	@echo "Building WebSurferX..."
	dub build
	@echo "WebSurferX built successfully."

run: build
	./websurferx

clean:
	@cd sync_client && cargo clean
	dub clean
	rm -f websurferx
