
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

	sleep 10

import:
	docker exec pinot-controller ./bin/pinot-admin.sh \
		LaunchDataIngestionJob \
		-jobSpecFile /tmp/pinot/table/jobspec.yaml

validate:
	@echo "\n🍷 Getting cluster info..."

	@curl -sX 'GET' \
      'http://localhost:9000/cluster/info' \
      -H 'accept: application/json'
	
	@echo "\n🍷 Getting Schemas..."     
	@curl -sX 'GET' \
      'http://localhost:9000/schemas' \
      -H 'accept: application/json'

destroy:
	docker compose down -v

base: create tables import
