# marc-schema


An extension of the [marc-json-schema](https://github.com/thisismattmiller/marc-json-schema) project by [@thisismattmiller](https://github.com/thisismattmiller).

In addition to the MARC Bibliographic Format, the Authority and Holdings Formats are now represented as well.

## Dependencies
* This project is an XQuery port of the original Python code.
* The BaseX XML database and query processor (v10.8) was used (currently in beta; see [latest developer snapshot](https://files.basex.org/releases/latest/)).

## Installation
For detailed documentation about installing and using BaseX, see the [BaseX wiki](http://docs.basex.org/wiki/Main_Page).

* Once BaseX has been downloaded, launch the BaseX GUI.
* `run-scraper.xq` will fetch the HTML pages for the MARC standards documentation and save them in a BaseX database. 
* `run-parser.xq` will generate the JSON file and write it to a local directory.
