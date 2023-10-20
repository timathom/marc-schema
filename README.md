# marc-schema


An extension of @thisismattmiller's [marc-json-schema](https://github.com/thisismattmiller/marc-json-schema) project.

In addition to the MARC Bibliographic Format, the Authority and Holdings Formats are represented as well.

## Dependencies
BaseX 10.8 (currently in beta; see [latest developer snapshot](https://files.basex.org/releases/latest/))

## Installation
See the [BaseX wiki](http://docs.basex.org/wiki/Main_Page) for detailed documentation about installing and using BaseX.

* Once BaseX has been downloaded, launch the BaseX GUI.
* `run-scraper.xq` will fetch the HTML pages for the MARC standards documentation and save them in a BaseX database. 
* `run-parser.xq` will generate the JSON file and write it to a local directory.