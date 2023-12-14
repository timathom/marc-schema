.PHONY: marc21_json_schema.json # always assumed to be out of date

marc21_json_schema.json: basex
	./basex/bin/basex -c "RUN run-scraper.xq; RUN run-parser.xq"

basex:
	wget -N https://files.basex.org/releases/BaseX.zip
	unzip BaseX.zip
