.PHONY: build run test clean

build:
	@mkdir -p bin
	swiftc -O -o bin/coding_earphone src/main.swift
	@echo "Build completed: bin/coding_earphone"

run: build
	./bin/coding_earphone

test:
	@mkdir -p tools/v0_1_verifier
	swiftc -O -o tools/v0_1_verifier/poster tools/v0_1_verifier/media_key_poster.swift
	swiftc -O -o tools/v0_1_verifier/monitor tools/v0_1_verifier/monitor.swift
	python3 tools/v0_1_verifier/full_h6_verification.py

clean:
	rm -rf bin/ tools/v0_1_verifier/poster tools/v0_1_verifier/monitor
