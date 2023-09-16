fix:
	fvm dart fix --apply lib

build-runner-watch watch:
	# flutter pub run build_runner build -d -v
	fvm flutter pub run build_runner watch -d -v

apk:
	flutter build apk
	open build/app/outputs/flutter-apk

setup-nocodb:
	./scripts/setup-nocodb-with-pg-sakila-db.sh

show-NC_DB:
	grep NC_DB nocodb/docker-compose/pg/docker-compose.yml | awk '{print $$2}'


remove-generated-files:
	find . | grep -e 'freezed\.dart' -e '\.g\.dart' | xargs -I {} rm {}

# open-swagger-definition:
# 	code nocodb/scripts/sdk/swagger.json

cloc:
	cloc . --vcs=git --include-ext=dart,yaml lib

run-web:
	CHROME_EXECUTABLE="./scripts/google-chrome-unsafe.sh" fvm flutter run -d chrome