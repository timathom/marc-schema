xquery version "3.1";

(:~ 
 : This module fetches and parses MARC 21 Bibliographic Format to convert it to a standard schema
 : 
 : Module name: MARC Scraper Library Module
 : Module version: 0.0.1
 : Date: June 29-October 20, 2023
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
declare variable $ms:MFHD-GROUPS := array {
  map {"url": "https://www.loc.gov/marc/holdings/hd853855.html", "range": [853, 854, 855]},
  map {"url": "https://www.loc.gov/marc/holdings/hd863865.html", "range": [863, 864, 865]},
  map {"url": "https://www.loc.gov/marc/holdings/hd866868.html", "range": [866, 867, 868]},
  map {"url": "https://www.loc.gov/marc/holdings/hd876878.html", "range": [876, 877, 878]}  
};
declare variable $ms:AUTH := "marc-authority-docs";
declare variable $ms:BIB := "marc-bibliographic-docs";
declare variable $ms:HOLD := "marc-holdings-docs";

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
       "https://www.loc.gov/marc/" || $format?name || "/" || $format?abbrev
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
     for $url in ($urls, $ms:MFHD-GROUPS?*)
     let $fetch :=
         http:send-request(<http:request method="get"/>, $url?url)
     let $status := $fetch[1]/data(@status)
     return (
       if ($status = "200")
       then <data code="{
         if ($url?field)
         then $url?field
         else ()
       }" range="{
         if (exists($url?range))
         then string-join($url?range, ", ")
         else ()
       }" status="200">{
         if (exists($url?range))
         then 
           for $r in $url?range?*
           return 
             <range>{$r}</range>           
         else ()
         ,
         $fetch[2]
       }</data>
       else <data code="{$url?field}" status="NA"/>
       ,
       prof:void(trace(string-join(($url?url, $status), ": ")))
     )       
   }, "data")
       
};

(:~ 
 : Parses data from HTML pages.
 :
 :
 :

 :)
declare function ms:parse-docs() {
   
  let $dbs := ("authority", "bibliographic", "holdings")
  for $db in $dbs
  let $data := db:get("marc-"||$db||"-docs")
  return (
    <data db="{$db}">{
      
      for $doc in $data/*/data[@status = "200"][normalize-space(@code)]
      let $h1 := string-join($doc//h1//text())    
      return element {$db} {
        attribute {"code"} {$doc/@code},
        
        ms:parse-title(normalize-space($h1)),
        ms:parse-repeat($h1)
        ,      
        if ($db = "holdings" and $doc/@code = (
          "853", 
          "854", 
          "855",
          "863", 
          "864", 
          "865", 
          "866",
          "867", 
          "868", 
          "876", 
          "877", 
          "878"
        ))
        then (
          let $code := $doc/data(@code)
          let $doc := db:text("marc-"||$db||"-docs", $code)/..[self::range]/parent::data        
          let $indicators := 
            $doc//table[.//text() contains text "Indicator" using case sensitive]        
          let $subfields := $doc//table[.//text() contains text "Subfield" using case sensitive]
          return (
            ms:parse-mfhd-group-indicators($code, $indicators)
            ,
            ms:parse-mfhd-group-subfields($code, $subfields)
          )
            
        )
        else
          (: Process fixed fields :)
          if (starts-with($doc/@code, "00") or $doc/@code = "leader")
          then 
            if ($doc/@code != "006")
            then (                  
              let $layout-1 := $doc//table[@class = "characterPositions"]
              let $layout-2 := $doc//table[tr/td/strong = "Character Positions"]
              return (
                <fixed>true</fixed>,
                if ((ms:parse-fixed-layout-1($layout-1) or ms:parse-fixed-layout-2($layout-2)))
                then (
                  ms:parse-fixed-layout-1($layout-1),
                  ms:parse-fixed-layout-2($layout-2)
                )
                else <positions/>            
              )
            )
            else if ($doc/@code = "006")
            then ms:parse-006($doc//table[1])
            else ()     
          else (
            (: Process data fields :)
            
            (: Process indicators :)
            let $indicators := 
              $doc//table[.//text() contains text "Indicator" using case sensitive]        
            let $subfields := $doc//table[.//text() contains text "Subfield" using case sensitive]
            return (
              ms:parse-indicators($indicators),
              ms:parse-subfields($subfields)
            )
          )
      }[normalize-space(@code)]
    }</data>
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
  
  for $entry in $layout-1/tr/td
  let $tokens := 
    if ($entry[@colspan = "2"])
    then tokenize($entry//strong, " - ") 
    else ()
  return ms:parse-fixed-data-layout-1($entry, $tokens) 
 
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
  return ms:parse-fixed-data-layout-2($entry)
    
};



(:~ 
 :
 :
 :
 :)
declare function ms:parse-fixed-data-layout-1(
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
  }</data>[normalize-space(name)] (: => trace() :)
    
};

(:~ 
 :
 :
 :
 :)
declare function ms:parse-fixed-data-layout-2(
  $entry as element()*
) as item()* {
  
  for tumbling window $w in $entry/strong/(self::*[not(. = "Character Positions")]|following-sibling::node())
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
      for $text in $w//self::text()[not(parent::strong)]
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

declare function ms:parse-indicators(
  $table as element(table)*
) as element()* {
  
  <indicators>{
    if ($table/@class = "indicators")
    then (                
      for $td at $p in $table//td
      return
        <entry n="{$p}">
          <name>{data($td/em)}</name>
          {
            for $value in $td/span
            let $tokens := tokenize($value, " - ")
            where every $t in $tokens satisfies normalize-space($t)
            return <data>
              <key>{normalize-space($tokens[1])}</key>
              <value>{normalize-space($tokens[2])}</value>
            </data>
          }
        </entry>                      
    )
    else (
      for $td at $p in $table//td
      return
        <entry n="{$p}">            
          {
            for $value in $td/node()
            return
              if ($value/self::em[normalize-space()])
              then <name>{data($value/self::em)}</name>
              else if ($value/self::text())
              then 
                let $tokens := tokenize($value, " - ")
                where every $t in $tokens satisfies normalize-space($t)
                return <data>
                  <key>{normalize-space($tokens[1])}</key>
                  <value>{normalize-space($tokens[2])}</value>
                </data>                
          }
        </entry>
    )
  }</indicators>
};

declare function ms:parse-mfhd-group-indicators(
  $code as xs:string,
  $table as element(table)*
) as element()* {
    
  <indicators>{    
    for $td at $p in $table//td
    return      
      <entry n="{$p}">{
        let $ind-name := $td/em[1]
        let $ind-vals := 
          for $val in $td//text()[parent::td]
          return 
            if ($val/following-sibling::*[1][self::em] and contains($val/following-sibling::*[1][self::em], $code))
            then $val
            else if (not($val/following-sibling::*[1][self::em]))
            then $val
            else ()
        return (
          <name>{normalize-space($ind-name)}</name>
          ,
          for $text in $ind-vals/self::text()
          let $tokens := tokenize($text, " - ")
          where every $t in $tokens satisfies normalize-space($t)
          return <data>
            <key>{normalize-space($tokens[1])}</key>
            <value>{normalize-space($tokens[2])}</value>
          </data> 
        )
        
      }</entry>
  }</indicators>
};

declare function ms:parse-mfhd-group-subfields(
  $code as xs:string,
  $table as element(table)*
) as element()* {
    
  <subfields>{    
    for $td at $p in $table//td[*[1][self::em]]
    for $sf in $td//text()[parent::td and (
        (following-sibling::*[1][self::em] and contains(following-sibling::*[1][self::em], $code))
          or
        not(following-sibling::*[1][self::em])
      )
    ] 
    return     
       <subfield>{
          let $repeat := 
            if (contains(normalize-space($sf),  " (R"))
            then <repeat>true</repeat> 
            else <repeat>false</repeat>  
          let $static :=              
            <static>false</static>
          let $tokens := normalize-space($sf) => tokenize(" - ") 
          let $key := 
            normalize-space(substring-after($tokens[1], "$")) 
          let $value := (
            if (contains(normalize-space($tokens[2]), " ("))
            then substring-before(normalize-space($tokens[2]), " (") 
            else normalize-space($tokens[2]) 
          )
          return <data>
            <key>{$key}</key>
            <name>{$value}</name>
            {$repeat}
            {$static}
            {
              if ($static/data() = "true")
              then <static-values>{
                for $text in $td/br/following-sibling::text()[1]
                let $norm := normalize-space($text)
                let $tokens := tokenize($norm, " - ") 
                return <data>
                  <key>{substring-after($tokens[1], "/")}</key>
                  <name>{normalize-space($tokens[2])}</name> 
                </data>
              }</static-values>
              else ()  
            }            
          </data>
        }</subfield>             
  }</subfields>
};

declare function ms:parse-subfields(
  $table as element(table)*
) as element()* {
  
  for $t in $table
  return
    <subfields>{
      if ($t/@class = "subfields")
      then (                
        for $td at $p in $table//td[ul[@class = "nomark"]]/ul/li
        return <subfield>{
          let $repeat := 
            if (contains(normalize-space($td), "(R)"))
            then <repeat>true</repeat>
            else <repeat>false</repeat>  
          let $static := 
            if ($td/br) 
            then <static>true</static>
            else <static>false</static>
          let $tokens := normalize-space($td/text()[1]) => tokenize(" - ")
          let $key := 
            normalize-space(substring-after($tokens[1], "$"))
          let $value := 
            if (contains(normalize-space($tokens[2]), " ("))
            then substring-before(normalize-space($tokens[2]), " (")
            else normalize-space($tokens[2])          
          return <data>
            <key>{$key}</key>
            <name>{$value}</name>
            {$repeat}
            {$static}
            {
              if ($static/data() = "true")
              then <static-values>{
                for $text in $td/br/following-sibling::text()[1]
                let $norm := normalize-space($text)
                let $tokens := tokenize($norm, " - ")
                return <data>
                  <key>{substring-after($tokens[1], "/")}</key>
                  <name>{normalize-space($tokens[2])}</name>
                </data>
              }</static-values>
              else ()  
            }
            
          </data>
        }</subfield>       
      )
      else (
       for $text at $p in $table//tr[3]/td/br/preceding-sibling::text()[1]
        return <subfield>{
          let $repeat := 
            if (contains(normalize-space($text), "(R)"))
            then <repeat>true</repeat>
            else <repeat>false</repeat>  
         
          let $tokens := normalize-space($text) => tokenize(" - ")
          let $key := 
            normalize-space(substring-after($tokens[1], "$"))
          let $value := normalize-space(substring-before($tokens[2], " ("))
          return <data>
            <key>{$key}</key>
            <name>{$value}</name>
            {$repeat}
           
            
          </data>
        }</subfield>       
      )
  }</subfields>
};