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
	docker compose build --no-cache
	docker compose up -d
	sleep 20

topic:
	docker exec kafka kafka-topics.sh \
		--bootstrap-server localhost:9092 \
		--create \
		--topic movie_ratings

tables:
	@echo "Waiting for Pinot Controller to be ready..."
	@while ! curl -sX GET http://localhost:9000/cluster/info -H 'accept: application/json'; do \
    		sleep 1; \
    		echo "Waiting for Pinot Controller..."; \
    	done
	@echo "🍷 Pinot Controller is ready."
    
	@echo "Waiting for Kafka to be ready..."
	@while ! nc -z localhost 9092; do \
		sleep 1; \
		echo "Waiting for Kafka..."; \
	done
	@echo "Kafka is ready."

	docker exec pinot-controller ./bin/pinot-admin.sh \
		AddTable \
		-tableConfigFile /tmp/pinot/table/ratings.table.json \
		-schemaFile /tmp/pinot/table/ratings.schema.json \
		-exec
	sleep 10

	docker exec pinot-controller ./bin/pinot-admin.sh \
		AddTable \
		-tableConfigFile /tmp/pinot/table/movies.table.json \
		-schemaFile /tmp/pinot/table/movies.schema.json \
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

