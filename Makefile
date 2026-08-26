.PHONY: build clean

build::
	swift build -c release --arch arm64
	cp -f .build/release/wechattweak ./wechattweak

clean::
	rm -rf .build
	rm -f wechattweak
