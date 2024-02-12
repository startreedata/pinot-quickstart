
schema:
	docker run \
		-v ${PWD}/table/pinot/movie.sample.json:/sample.json \
		-v ${PWD}/table:/table \
		apachepinot/pinot:latest JsonToPinotSchema \
		-jsonFile /sample.json \
		-pinotSchemaName="movie" \
		-outputDir="/table" \
		-dimensions=""

topic:
	-docker exec -it kafka kafka-topics.sh \
		--bootstrap-server localhost:9092 \
		--create \
		--topic movie_ratings

tables:
	docker exec -it pinot-controller ./bin/pinot-admin.sh \
		AddTable \
		-tableConfigFile /tmp/pinot/table/ratings.table.json \
		-schemaFile /tmp/pinot/table/ratings.schema.json \
		-exec

	docker exec -it pinot-controller ./bin/pinot-admin.sh \
		AddTable \
		-tableConfigFile /tmp/pinot/table/movies.table.json \
		-schemaFile /tmp/pinot/table/movies.schema.json \
		-exec

	sleep 10


import:
	docker exec -it pinot-controller ./bin/pinot-admin.sh \
		LaunchDataIngestionJob \
		-jobSpecFile /tmp/pinot/table/jobspec.yaml


all: topic tables import
