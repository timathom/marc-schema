xquery version "3.1";

import module namespace ms = "__marc-scraper__" at "marc-scraper.xqm";

declare variable $ms:MFHD-GROUPS-2 := array {
  map {"url": "https://www.loc.gov/marc/holdings/hd853855.html", "range": [853, 854, 855]},
  map {"url": "https://www.loc.gov/marc/holdings/hd863865.html", "range": [863, 864, 865]},
  map {"url": "https://www.loc.gov/marc/holdings/hd866868.html", "range": [866, 867, 868]},
  map {"url": "https://www.loc.gov/marc/holdings/hd876878.html", "range": [876, 877, 878]}  
};

let $parsed := ms:parse-docs()
return $parsed//static[. = "true"]/../../../..