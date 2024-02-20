# marc-schema

An extension of the [marc-json-schema](https://github.com/thisismattmiller/marc-json-schema) project by [@thisismattmiller](https://github.com/thisismattmiller). This project is an XQuery port of the original Python code.

In addition to the MARC Bibliographic Format, the Authority and Holdings Formats are now represented as well.

Schema files are generated in [Avram schema format](https://format.gbv.de/schema/avram/specification):

- `marc21_authority_schema.json`
- `marc21_bibliographic_schema.json`
- `marc21_holdings_schema.json`

Contributions and bug reports are welcome!

## Dependencies
* BaseX XML database and query processor
* `jq` command-line tool for JSON normalization
* Optional `make` for automatic execution via Unix command line

## Installation
* Download and install BaseX either GUI or command line (see the [BaseX wiki](http://docs.basex.org/wiki/) for detailed information).
* Install `jq` ([jq](https://jqlang.github.io/jq/)) using a package manager such as `apt` or `homebrew` (depending on your environment).

To install BaseX into subdirectory `basex` from the command line:

	wget -N https://files.basex.org/releases/BaseX.zip
	unzip BaseX.zip

## Usage

### GUI
The GUI is more convenient for manual execution:

1. Launch the BaseX GUI
2. `run-scraper.xq` will fetch the HTML pages for the MARC standards documentation and save them in a BaseX database.
3. `run-parser.xq` will generate the JSON file and write it to a local directory.

### Command line
Given BaseX is installed in subdirectory `basex`, the queries can be run in a single command:

    ./basex/bin/basex -c "RUN run-scraper.xq; RUN run-parser.xq"

Optionally, the value of a directory path can be passed on the command line to the `ms:DIR` variable:

    ./basex/bin/basex -Q run-scraper.xq -b ms:DIR="/Users/Abc/Desktop/" -Q run-parser.xq

Installation, scraping and parsing can also be run automatically by calling `make`:

    make -B

## Contributors

- Tim Thompson (port and extension in XQuery)
- Matt Miller (original Python code)
- Jakob Voß (adjustments to comply with Avram specification) 

