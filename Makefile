PROJECT := ExpenseTracker.xcodeproj
SCHEME := ExpenseTracker
BUNDLE_ID := com.theluckiestsoul.expensetracker
DERIVED_DATA := .build/DerivedData
SIMULATOR ?= iPhone 17 Pro
CONFIGURATION ?= Debug
XCODE_APP ?= $(firstword $(wildcard /Applications/Xcode*.app) $(wildcard $(HOME)/Applications/Xcode*.app))
SELECTED_DEVELOPER_DIR := $(shell xcode-select -p 2>/dev/null)
XCODE_DEVELOPER_DIR := $(strip $(if $(DEVELOPER_DIR),$(DEVELOPER_DIR),$(if $(findstring .app/Contents/Developer,$(SELECTED_DEVELOPER_DIR)),$(SELECTED_DEVELOPER_DIR),$(if $(XCODE_APP),$(XCODE_APP)/Contents/Developer))))
TOOL_PREFIX := $(if $(XCODE_DEVELOPER_DIR),DEVELOPER_DIR="$(XCODE_DEVELOPER_DIR)" )
XCRUN := $(TOOL_PREFIX)xcrun
XCODEBUILD := $(TOOL_PREFIX)xcodebuild
FULL_XCODE := $(shell $(XCODEBUILD) -version >/dev/null 2>&1 && echo yes)

.PHONY: help check test build release run smoke clean doctor

help:
	@echo "make check  - validate project, JSON, and Swift syntax"
	@echo "make test   - run portable domain tests"
	@echo "make build  - build for the iOS Simulator (requires full Xcode)"
	@echo "make run    - boot simulator, build, install, and launch"
	@echo "make release - compile the optimized Release configuration"
	@echo "make smoke  - launch and capture a simulator screenshot/log check"
	@echo "make clean  - remove local build output"
	@echo "make doctor - report local Apple tooling"

check:
	@plutil -lint $(PROJECT)/project.pbxproj
	@find ExpenseTracker -name Contents.json -print0 | xargs -0 -n1 jq empty
	@find ExpenseTracker -name '*.strings' -print0 | xargs -0 -n1 plutil -lint
	@swiftc -frontend -parse $$(find ExpenseTracker -name '*.swift' -print)
	@echo "Static checks passed"

test: check
	@mkdir -p .build/tests
	@swiftc ExpenseTracker/Support/DomainLogic.swift Tests/DomainLogicTests.swift -o .build/tests/domain-logic-tests
	@.build/tests/domain-logic-tests
	@if test "$(FULL_XCODE)" = "yes"; then $(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) -sdk iphonesimulator -destination 'platform=iOS Simulator,name=$(SIMULATOR)' -derivedDataPath $(DERIVED_DATA)-Tests CODE_SIGNING_ALLOWED=NO test; fi

build: check require-xcode
	@$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) -configuration $(CONFIGURATION) -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath $(DERIVED_DATA) CODE_SIGNING_ALLOWED=NO build

release: check require-xcode
	@$(XCODEBUILD) -project $(PROJECT) -scheme $(SCHEME) -configuration Release -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' -derivedDataPath $(DERIVED_DATA)-Release CODE_SIGNING_ALLOWED=NO build

run: build
	@DEVICE_ID=`$(XCRUN) simctl list devices available | awk -F '[()]' '/$(SIMULATOR)/ {print $$2; exit}'`; \
	test -n "$$DEVICE_ID" || { echo "Simulator '$(SIMULATOR)' not found. Set SIMULATOR='available name'."; exit 1; }; \
	$(XCRUN) simctl boot "$$DEVICE_ID" 2>/dev/null || true; \
	open -a Simulator; \
	$(XCRUN) simctl bootstatus "$$DEVICE_ID" -b; \
	APP=`find $(DERIVED_DATA)/Build/Products -path '*iphonesimulator/$(SCHEME).app' -print -quit`; \
	test -n "$$APP" || { echo "Built app was not found"; exit 1; }; \
	$(XCRUN) simctl install "$$DEVICE_ID" "$$APP"; \
	$(XCRUN) simctl launch "$$DEVICE_ID" $(BUNDLE_ID)

smoke: run
	@mkdir -p .build/smoke
	@DEVICE_ID=`$(XCRUN) simctl list devices booted | awk -F '[()]' '/$(SIMULATOR)/ {print $$2; exit}'`; \
	sleep 2; \
	$(XCRUN) simctl io "$$DEVICE_ID" screenshot .build/smoke/dashboard.png; \
	$(XCRUN) simctl spawn "$$DEVICE_ID" log show --style compact --last 1m --predicate 'process == "ExpenseTracker" AND (messageType == fault OR eventMessage CONTAINS[c] "fatal error" OR eventMessage CONTAINS[c] "uncaught exception")' | tail -n +2 > .build/smoke/errors.log; \
	test ! -s .build/smoke/errors.log || { echo "Runtime errors detected:"; cat .build/smoke/errors.log; exit 1; }; \
	echo "Simulator smoke test passed"

require-xcode:
	@if test "$(FULL_XCODE)" != "yes"; then \
		echo "A full Xcode installation is required; active developer directory: $(SELECTED_DEVELOPER_DIR)"; \
		echo "Install Xcode, then select it with:"; \
		echo "  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer"; \
		echo "For a nonstandard location, run:"; \
		echo "  make build DEVELOPER_DIR=/path/to/Xcode.app/Contents/Developer"; \
		exit 1; \
	fi

doctor:
	@echo "Swift: $$(swift --version | head -1)"
	@echo "Active developer directory: $(SELECTED_DEVELOPER_DIR)"
	@if test "$(FULL_XCODE)" = "yes"; then $(XCODEBUILD) -version; else echo "Xcode: unavailable (Command Line Tools alone cannot build iOS apps)"; fi

clean:
	@rm -rf .build
