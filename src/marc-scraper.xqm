xquery version "3.1";

(:~ 
 : This module fetches and parses MARC 21 Bibliographic Format to convert it to a standard schema
 : 
 : Module name: MARC Scraper Library Module
 : Module version: 0.0.1
 : Date: June 29, 2023
 : License: Apache-2.0
 : XQuery specification: 3.1
 : Module overview: Based on the marc-json-schema repo by @thisismattmiller
 : Dependencies: BaseX 
 : @author @timathom[@indieweb.social]
 : @version 0.0.1
 :
:)

module namespace ms = "__marc-scraper__";

declare namespace errs = "__errs__";
declare namespace madsrdf = "http://www.loc.gov/mads/rdf/v1#";
declare namespace marc = "http://www.loc.gov/MARC21/slim";
declare namespace rdf = "http://www.w3.org/1999/02/22-rdf-syntax-ns#";

declare variable $ms:SCHEMA := map {};
declare variable $ms:FIXED := array {
  "leader", "001", "003", "005", "006", "007a", "007c", "007d", "007f", "007g", "007h", "007k", "007m", "007o", "007q", "007r", "007s", "007t", "007v", "007z", "008a", "008b", "008c", "008p", "008m", "008s", "008v", "008x"
};

(:~ 
 :  Fetches LC MARC documentation HTML page and parses it 
 :  
 : 
 : @param $format Map with two keys ("name" and "abbrev") indicating 
 : the MARC 21 format to be processed
 : @return Create DB with MARC docs
 : @error
 :
 :)
 declare 
   %updating
 function ms:fetch-marc-html(
   $format as map(*)
 ) {
   
   db:create("marc-" || $format?name || "-docs", element { $format?abbrev } {
     let $base := 
       "http://www.loc.gov/marc/" || $format?name || "/" || $format?abbrev
     let $urls := (
       for $tag in (10 to 1000) ! format-number(., "000")
       return map { 
         "field": $tag, "url": $base || $tag || ".html" 
       }
       ,
       for $code in $ms:FIXED?*
       return map { 
         "field": $code, "url": $base || $code || ".html" 
       }
     )
     for $url in $urls
     let $fetch :=
         http:send-request(<http:request method="get"/>, $url?url)
     return (
       if ($fetch[1]/@status = "200")
       then <data code="{$url?field}" status="200">{$fetch[2]}</data>
       else <data code="{$url?field}" status="NA"/>
       ,
       prof:void(trace($url))
     )       
   }, "data")
       
};

