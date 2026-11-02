.PHONY: build run clean install snapshot

build:
	./scripts/build-app.sh

run: build
	open build/Tic.app

install: build
	cp -R build/Tic.app /Applications/
	open /Applications/Tic.app

snapshot: build
	TIC_RENDER_SNAPSHOTS=1 TIC_DEMO=1 build/Tic.app/Contents/MacOS/Tic

clean:
	rm -rf .build build
	rm -f /tmp/tic-*.png
