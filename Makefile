marc21_json_schema.json: BaseX.jar
	java -cp BaseX.jar org.basex.BaseX -c "RUN run-scraper.xq; RUN run-parser.xq"

BaseX.jar:
	wget -N https://files.basex.org/releases/BaseX.jar
