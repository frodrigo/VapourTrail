extent=7.40701675415039,43.7229786663231,7.4437522888183585,43.7541091221655
static_url=https://frodrigo.github.io/VapourTrail/web/tiles

all: up

up:
	docker-compose up web

up-d:
	docker-compose up -d web

down:
	docker-compose down

help:
	@echo VapourTrail https://github.com/Jungle-Bus/VapourTrail

docker-postgres:
	docker-compose restart postgres

docker-t-rex:
	docker-compose restart t-rex

docker-web:
	docker-compose restart web

docker-importer:
	docker-compose run --rm importer
	chmod a+rw docker/trex_cache
	docker-compose restart t-rex

docker/imposm/import/monaco.osm.pbf:
	wget http://download.geofabrik.de/europe/monaco-latest.osm.pbf --no-verbose -O $@

#to get the bbox :  osmconvert --out-statistics docker/imposm/import/monaco.osm.pbf | egrep 'lon |lat ' | cut -d ' ' -f 3 | tr '\n' ' ' | sed -E "s/([^ ]+) ([^ ]+) ([^ ]+) ([^ ]+)/\1,\3,\2,\4/"
test-monaco: docker/imposm/import/monaco.osm.pbf docker-importer
	make generate-tiles bbox=7.40701675415039,43.7229786663231,7.4437522888183585,43.7541091221655

test: test-monaco

generate-tiles:
	./scripts/generate_all_tiles.sh

prepare-static:
	./scripts/prepare_static.sh

dump-tiles:
	@echo ""
	@echo "Use extent: $(extent)"
	@echo "Use URL: $(static_url)"
	@echo ""
	mkdir -p settings/mvtcache
	rm -fr settings/mvtcache/*
	chmod a+rw settings/mvtcache
	echo -e "[cache.file] ##DUMP\nbase = \"/srv/mvtcache\" ##DUMP\nbaseurl = \"$(static_url)\" ##DUMP" >> settings/trex.toml
	docker-compose run --rm --entrypoint 't_rex generate --config /config/config.toml --extent $(extent) --maxzoom 16' t-rex
	grep -v '##DUMP' settings/trex.toml > settings/trex.toml_ && mv settings/trex.toml_ settings/trex.toml
	rm -fr web/tiles && cp -r settings/mvtcache/ web/tiles
	find web/tiles -name "*.pbf" -size `du -b web/tiles/vapour_trail/0/0/0.pbf | cut -f 1`c -delete
	find web/tiles -type d -empty -delete
	find web/tiles -name "*.pbf" -exec mv {} {}.gz \;
	find web/tiles -name "*.pbf.gz" -exec gzip -d {} \;
	sed -i -e 's="url": "http://0.0.0.0:6767/vapour_trail.json"="url": "$(static_url)/vapour_trail.json"=' web/vapour-style.json
