# marc-schema


An extension of the [marc-json-schema](https://github.com/thisismattmiller/marc-json-schema) project by [@thisismattmiller](https://github.com/thisismattmiller).

In addition to the MARC Bibliographic Format, the Authority and Holdings Formats are now represented as well.

Contributions and bug reports are welcome!

## Dependencies
* This project is an XQuery port of the original Python code.
* The BaseX XML database and query processor was used (v10.8, currently in beta; see [latest developer snapshot](https://files.basex.org/releases/latest/)).

## Installation
For detailed documentation about installing and using BaseX, see the [BaseX wiki](http://docs.basex.org/wiki/Main_Page).

* Once BaseX has been downloaded, launch the BaseX GUI.
* `run-scraper.xq` will fetch the HTML pages for the MARC standards documentation and save them in a BaseX database. 
* `run-parser.xq` will generate the JSON file and write it to a local directory.
* From the BaseX installation directory, the queries can be run in a single command:
  ```
  bin/basex -c "RUN marc-schema/run-scraper.xq; RUN marc-schema/run-parser.xq"
  ```
* Optionally, the value of a directory path can be passed on the command line to the `ms:DIR` variable:
  ```
  bin/basex -Q marc-schema/run-scraper.xq -b ms:DIR="/Users/Abc/Desktop/" -Q marc-schema/run-parser.xq
  ```
  
