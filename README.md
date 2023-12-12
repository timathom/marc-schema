# marc-schema

An extension of the [marc-json-schema](https://github.com/thisismattmiller/marc-json-schema) project by [@thisismattmiller](https://github.com/thisismattmiller). This project is an XQuery port of the original Python code.

In addition to the MARC Bibliographic Format, the Authority and Holdings Formats are now represented as well.

Contributions and bug reports are welcome!

## Dependencies
Requires the BaseX XML database and query processor and optional `make` for automatic execution via command line.

## Installation and usage
Download and install BaseX either GUI or command line (see the [BaseX wiki](http://docs.basex.org/wiki/) for detailled information):

### GUI
The GUI is more conveniant for manual execution:

1. Launch the BaseX GUI
2. `run-scraper.xq` will fetch the HTML pages for the MARC standards documentation and save them in a BaseX database. 
3. `run-parser.xq` will generate the JSON file and write it to a local directory.

### command line
The `Makefile` in this repository includes rules to automatically download BaseX JAR-File and execute fetching and transformation. To update the JSON schema run:

    make -B

From the BaseX installation directory, the queries can be run in a single command (given this repository is located in subdirectory `marc-schema`):

    bin/basex -c "RUN marc-schema/run-scraper.xq; RUN marc-schema/run-parser.xq"

Optionally, the value of a directory path can be passed on the command line to the `ms:DIR` variable:

    bin/basex -Q marc-schema/run-scraper.xq -b ms:DIR="/Users/Abc/Desktop/" -Q marc-schema/run-parser.xq

To use the BaseX JAR-File replace `bin/basex` with `java -cp BaseX.jar org.basex.BaseX`.
