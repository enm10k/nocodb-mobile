run_integration_test rit:
	flutter run --dart-define-from-file=integration_test/.env -t integration_test/hello_test.dart

run_unit_test rut:
	flutter run --dart-define-from-file=test/.env -t test/provider_test.dart
	# dart test test/provider_test.dart

fix:
	dart fix --apply lib
	dart fix --apply integration_test
	dart format lib integration_test

gen:
	flutter pub run build_runner watch -d -v

clean:
	find . | grep -e 'freezed\.dart' -e '\.g\.dart' | xargs -I {} rm {}

apk:
	flutter build apk
	open build/app/outputs/flutter-apk

setup_nocodb:
	./scripts/setup-nocodb-with-pg-sakila-db.sh

show_nc_db:
	grep NC_DB _nocodb/docker-compose/pg/docker-compose.yml | awk '{print $$2}'

enable_db_log:
	cd _nocodb/docker-compose/pg && docker-compose exec root_db bash -c 'psql -U $$POSTGRES_USER -d $$POSTGRES_DB -c "ALTER SYSTEM SET log_statement = '\''all'\'';"'
	cd _nocodb/docker-compose/pg && docker-compose exec root_db bash -c 'psql -U $$POSTGRES_USER -d $$POSTGRES_DB -c "SELECT pg_reload_conf();"'

tail_db_log:
	cd _nocodb/docker-compose/pg && docker-compose logs -f root_db

# open_swagger_definition:
# 	code nocodb/scripts/sdk/swagger.json

cloc:
	cloc . --vcs=git --include-ext=dart,yaml lib

run_web:
	CHROME_EXECUTABLE="./scripts/google-chrome-unsafe.sh"  flutter run -d chrome
