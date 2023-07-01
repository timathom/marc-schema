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
 :  Fetches LC MARC documentation HTML pages and stores them in a database 
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

(:~ 
 : Parses data from fixed field pages.
 :
 :
 :

 :)
declare function ms:parse-docs() {
   
  let $dbs := ("authority", "bibliographic", "holdings")
  for $db in $dbs
  let $data := db:get("marc-"||$db||"-docs")
  return (
    for $doc in $data/*/data[@status = "200"]
    let $h1 := string-join($doc//h1//text())    
    return element {$db} {
      attribute {"code"} {$doc/@code},
      
      (: Process fixed fields :)
      if (starts-with($doc/@code, "00") or $doc/@code = "leader")
      then 
        if ($doc/@code != "006")
        then (        
          (: ms:parse-title($h1),
          ms:parse-repeat($h1)
          , :)
          let $layout-1 := $doc//table[@class = "characterPositions"]
          let $layout-2 := $doc//table[tr/td/strong = "Character Positions"]
          return (
            (: ms:parse-fixed-layout-1($layout-1),
            ms:parse-fixed-layout-2($layout-2) :)
          )
        )
        else if ($doc/@code = "006")
        then ms:parse-006($doc//table[1])
        else ()     
      else (
        (: Process data fields :)
        (: ms:parse-title($h1),
        ms:parse-repeat($h1) :)
        
      )
    }
   
  )
   
};

(:~ 
 :
 :
 :
 :)
declare function ms:parse-title(
  $h1 as xs:string
) as element(title) {
  
  <title>{
    if (starts-with($h1, "Leader"))
    then "Leader"
    else substring-after($h1, "- ") => substring-before(" (")
  }</title>
    
};

(:~ 
 :
 :
 :
 :)
declare function ms:parse-repeat(
  $h1 as xs:string
) as item()* {
  
  <repeat>{
    if (contains($h1, "(R)"))
    then true()
    else false()  
  }</repeat>
  
};

(:~ 
 :
 :
 :
 :)
declare function ms:parse-fixed-layout-1(
  $layout-1 as element(table)*
) as item()* {
  
  for $entry in $layout-1/tr/td[@colspan = "2"]
  let $tokens := tokenize($entry/span/strong, " - ")
  return ms:parse-data-layout-1($entry, $tokens) 
 
};

(:~ 
 :
 :
 :
 :)
declare function ms:parse-fixed-layout-2(
  $layout-2 as element()*
) as item()* {
  
  for $entry in $layout-2/tr/td[@width = "45%"]
  return ms:parse-data-layout-2($entry)
    
};



(:~ 
 :
 :
 :
 :)
declare function ms:parse-data-layout-1(
  $entry as element()*,
  $tokens as xs:string*
) as item()* {
  
  let $name := <name>{normalize-space($tokens[2])}</name>
  let $positions := <positions>{
    if (contains($tokens[1], "-"))
    then (
     <start>{substring-before($tokens[1], "-")}</start>,
     <stop>{substring-after($tokens[1], "-")}</stop> 
    )
    else (
      $tokens[1] ! (<start>{.}</start>, <stop>{.}</stop>)      
    )
  }</positions>
  return <data>{
    $name, $positions, <values>{
      if ($entry/../following-sibling::*[1][self::tr][td/dl])
      then 
        let $values := $entry/../following-sibling::*[1][self::tr]/td/dl/dd
        for $value in $values
        let $tokens := tokenize($value, " - ")
        return (
          <entry>
            <code>{$tokens[1]}</code>
            <name>{normalize-space($tokens[2])}</name> 
          </entry>         
        )
      else ()
    }</values>
  }</data>
    
};

(:~ 
 :
 :
 :
 :)
declare function ms:parse-data-layout-2(
  $entry as element()*
) as item()* {
  
  for tumbling window $w in $entry/strong/following-sibling::node()
    start $s when true()
    end $e next $n when $n/self::strong
  where normalize-space(string-join($w))
  let $head :=    
    let $tokens := 
      tokenize($w/self::strong, " - ")    
    let $name := <name>{normalize-space($tokens[2])}</name>
    let $positions := <positions>{
      if (contains($tokens[1], "-"))
      then (
       <start>{substring-before($tokens[1], "-")}</start>,
       <stop>{substring-after($tokens[1], "-")}</stop> 
      )
      else (
        $tokens[1] ! (<start>{.}</start>, <stop>{.}</stop>)      
      )
    }</positions>
    return ($name, $positions)
  return <data>{
    $head, 
    <values>{     
      for $text in $w//self::text()
      let $lines := tokenize($text, "\n")
      for $line in $lines
      let $tokens := tokenize($line, " - ")
      where normalize-space(string-join($tokens))
      return (
        <entry>
          <code>{normalize-space($tokens[1])}</code>
          <name>{normalize-space($tokens[2])}</name>
        </entry>
      )
    }</values>
  }</data>
    
};

(:~ 
 :
 :
 :
 :)
declare function ms:parse-006(
  $table as element(table)*
) as item()* {
  
 let $name := 
   <name>Fixed-Length Data Elements-Additional Material Characteristics</name>
 let $title-map-006 := map {
    "Books": "008b",
    "Computer files/Electronic resources": "008c",
    "Music": "008m",
    "Continuing resources": "008s",
    "Visual materials": "008v",
    "Maps": "008p",
    "Mixed materials": "008x"
 }
  let $positions := <positions>{
    for $td in $table/tr/(td[@width = "45%"]/p|td[@width = "45%"][not(p)])
    for tumbling window $w in $td/(em|text())
      start $s when $s/self::em
      end $e next $n when $n/self::em
    return 
      <group code="{$title-map-006?(normalize-space($w/self::em))}">{
        ms:parse-006-groups($w)        
      }</group>      
  }</positions>
  return $positions

};


declare function ms:parse-006-groups(
  $nodes as node()*
) as item()* {
  
  for $text in $nodes//self::text()[not(parent::em)]
  return 
  let $lines := tokenize($text, "\n")
  for $line in $lines
  let $tokens := tokenize($line, " - ")
  where normalize-space(string-join($tokens))
  return 
    <data>{
      <name>{normalize-space($tokens[2])}</name>
      ,
      if (contains($tokens[1], "-"))
      then (
       <start>{
         normalize-space(substring-before($tokens[1], "-"))
       }</start>,
       <stop>{normalize-space(substring-after($tokens[1], "-"))}</stop> 
      )
      else (
        $tokens[1] ! (
          <start>{normalize-space(.)}</start>, 
          <stop>{normalize-space(.)}</stop>
        )      
      )
    }</data>
  
};