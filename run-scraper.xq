xquery version "4.0";

import module namespace ms = "__marc-scraper__" at "src/marc-scraper.xqm";

let $maps := array {
  map { "name": "bibliographic", "abbrev": "bd"},
  map { "name": "authority", "abbrev": "ad"},
  map { "name": "holdings", "abbrev": "hd"}
}
for $map in $maps?*
return
  ms:fetch-marc-html($map)
