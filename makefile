fresh:
	@echo "Cleaning project..."
	flutter clean
	@echo "Removing iOS Pods and Podfile.lock..."
	rm -rf ios/Pods ios/Podfile.lock
	@echo "Fetching Flutter dependencies..."
	flutter pub get
	@echo "Project fully cleaned and refreshed!"

build-runner:
	@echo "Running build_runner..."
	dart run build_runner build --delete-conflicting-outputs
	@echo "Code generation complete!"

lint:
	@echo "Running analyzer..."
	dart analyze
	@echo "Analyze complete!"

format-code: fix-lint
	@echo "Running formatting..."
	dart format .
	@echo "Formatting complete!"

fix-lint:
	@echo "Running lint fixes..."
	dart fix --apply
	@echo "Lint fixes complete!"

build-apk: fresh build-runner format-code
	@echo "Building APK..."
	flutter build apk --release
	@echo "APK build complete!"

preview:
	@echo "Widget previews..."
	flutter widget-preview start --web-server
	@echo "Preview complete!"