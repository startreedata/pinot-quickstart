base: create tables import

schema:
	docker run \
		-v ${PWD}/table/pinot/movie.sample.json:/sample.json \
		-v ${PWD}/table:/table \
		apachepinot/pinot:latest JsonToPinotSchema \
		-jsonFile /sample.json \
		-pinotSchemaName="movie" \
		-outputDir="/table" \
		-dimensions=""

create:
	#docker compose build --no-cache
	docker compose build
	docker compose up -d
	@echo "Waiting for Pinot Controller to be ready..."
	@while true; do \
		STATUS_CODE=$$(curl -s -o /dev/null -w '%{http_code}' \
			'http://localhost:9000/health'); \
		if [ "$$STATUS_CODE" -eq 200 ]; then \
			break; \
		fi; \
		sleep 2; \
		echo "Waiting for Pinot Controller..."; \
	done
	@echo "🍷 Pinot Controller is ready."

	@echo "Waiting for Pinot Broker to be ready..."
	@while true; do \
		STATUS_CODE=$$(curl -s -o /dev/null -w '%{http_code}' \
			'http://localhost:8099/health'); \
		if [ "$$STATUS_CODE" -eq 200 ]; then \
			break; \
		fi; \
		sleep 1; \
		echo "Waiting for Pinot Broker..."; \
	done
	@echo "🍷 Pinot Broker is ready to receive queries."
	
	@echo "🪲 Waiting for Kafka to be ready..."
	@while ! nc -z localhost 9092; do \
		sleep 1; \
		echo "Waiting for Kafka..."; \
	done
	@echo "🪲 Kafka is ready."

topic:
	docker exec kafka kafka-topics.sh \
		--bootstrap-server localhost:9092 \
		--create \
		--topic movie_ratings

tables:
	docker exec pinot-controller ./bin/pinot-admin.sh \
		AddTable \
		-tableConfigFile /tmp/pinot/table/movies.table.json \
		-schemaFile /tmp/pinot/table/movies.schema.json \
		-exec

	sleep 5

	docker exec pinot-controller ./bin/pinot-admin.sh \
		AddTable \
		-tableConfigFile /tmp/pinot/table/ratings.table.json \
		-schemaFile /tmp/pinot/table/ratings.schema.json \
		-exec
import:
	docker exec pinot-controller ./bin/pinot-admin.sh \
		LaunchDataIngestionJob \
		-jobSpecFile /tmp/pinot/table/jobspec.yaml

validate:
	@echo "\n🍷 Getting cluster info..."
	@curl -sX GET http://localhost:9000/cluster/info -H 'accept: application/json' | jq .

	@echo "\n🍷 Getting Schemas..."
	@SCHEMAS=$$(curl -sX 'GET' \
      'http://localhost:9000/schemas' \
      -H 'accept: application/json' | jq .); \
	if echo "$$SCHEMAS" | grep -q "movie_ratings"; then \
		echo "Schema 'movie_ratings' found."; \
	else \
		echo "Schema 'movie_ratings' not found."; \
		exit 1; \
	fi; \
	if echo "$$SCHEMAS" | grep -q "movies"; then \
		echo "Schema 'movies' found."; \
	else \
		echo "Schema 'movies' not found."; \
		exit 1; \
	fi

destroy:
	docker compose down -v

