xquery version "4.0";

(:~ 
 : This module fetches and parses HTML documentation for the MARC 21 Authority, 
 : Bibliographic, and Holdings Formats and converts it to a standard schema
 : 
 : Module name: MARC Scraper Library Module
 : Module version: 0.1.0
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
       void(trace(string-join(($url?url, $status), ": ")))
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
                              [not(ms:is-appendix-field(.))]
      let $h1 := string-join($doc//h1//text())
      return element {$db} {
        attribute {"code"} {$doc/@code},
        
        ms:parse-title(normalize-space($h1)),
        ms:parse-repeat($h1)
        ,
        (: Retired designators, for every field shape -- data, fixed and MFHD
         : group alike, since Leader and 007 carry a history section too. :)
        ms:parse-obsolete($doc)
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
 : Is this field local or obsolete rather than part of the format?
 :
 : LC keeps the page for a retired field online indefinitely, and the page still
 : carries a full subfield and indicator table, so nothing in the field's own
 : description says it has been withdrawn.  The breadcrumb does: a current field
 : is filed under its group (046 under 01X-09X), while a retired or
 : United-States-local one is filed under Appendix H, Local Data Elements.  For
 : bibliographic that separates 261, 262, 400, 410, 411 and 440 from the rest,
 : which is the same set a cataloguer would name.
 :
 : Do not trust the breadcrumb's other links: 440 is also filed under Community
 : Information 01X-08X, which is a different format altogether.  Matching the
 : appendix rather than the group tolerates that.
 :
 : The leader has no breadcrumb, so it is never excluded by this test.
 :
 : @param $doc The stored page
 : @return True if the page files the field under an appendix
 :)
declare function ms:is-appendix-field(
  $doc as element(data)
) as xs:boolean {

  some $a in $doc//div[@class = "head-nav"]//a
  satisfies matches($a/@href, "apndx[a-z]*\.html$")

};

(:~
 : Reports the fields ms:is-appendix-field excludes, so the exclusion is visible
 : rather than a silent shrinking of the format.
 :)
declare function ms:excluded-fields() {

  for $db in ("authority", "bibliographic", "holdings")
  return
    <data db="{$db}">{
      for $doc in db:get("marc-" || $db || "-docs")/*/data[@status = "200"]
                    [normalize-space(@code)][ms:is-appendix-field(.)]
      return
        <field code="{$doc/@code}">{
          ms:parse-title(normalize-space(string-join($doc//h1//text()))),
          <filed-under>{
            string-join(
              distinct-values(
                for $a in $doc//div[@class = "head-nav"]//a[ends-with(@href, ".html")]
                return replace($a/data(@href), "^.*/", "")
              ), " "
            )
          }</filed-under>
        }</field>
    }</data>

};

(:~
 : Splits a cell into the runs of content separated by <br/>.
 :
 : LC's pages are inconsistent about whether a code or subfield line is bare
 : text, wrapped in <span>, or wrapped in <span class="changed"> because it
 : changed in the current update.  Grouping on <br/> and taking the string value
 : of each run reads all three the same way.
 :
 : @param $cell The td to split
 : @param $skip Nodes to leave out of the runs (the <em> holding the name)
 : @return One normalized string per run, empty runs dropped
 :)
declare function ms:split-on-br(
  $cell as element()*,
  $skip as node()*
) as xs:string* {

  for tumbling window $w in $cell/node()[not(. intersect $skip)]
    start $s when true()
    end $e next $n when $n/self::br
  let $line := normalize-space(string-join($w))
  where $line
  return $line

};

(:~
 : Splits a cell into <br/>-delimited runs, keeping every node.
 :)
declare function ms:split-on-br(
  $cell as element()*
) as xs:string* {

  ms:split-on-br($cell, ())

};

(:~
 : Drops the trailing "(R)" / "(NR)" repeatability marker from a label.
 :
 : The closing paren is optional because LC's pages do not always close it --
 : 018$a reads "Copyright article-fee code (NR".  Only "R" and "NR" are matched,
 : so a label that genuinely ends in parentheses, such as 041$r "... (non-textual)",
 : is left alone.
 :)
declare function ms:strip-repeat-marker(
  $label as xs:string
) as xs:string {

  normalize-space(replace($label, "\s*\((N?R)\)?\s*$", ""))

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
      (: Codes are usually wrapped in <span>, but not always: on 046 and 588 LC
       : leaves the first indicator's codes as bare text between <br/>s, and 588
       : carries a stray </span> on top of that.  Reading only $td/span dropped
       : both fields' first indicator entirely.  Split on <br/> instead, which
       : covers wrapped and bare codes alike. :)
      for $td at $p in $table//td
      return
        <entry n="{$p}">
          <name>{normalize-space(string-join($td/em[1]))}</name>
          {
            for $line in ms:split-on-br($td, $td/em)
            where matches($line, "^\S+\s+-\s+\S")
            return <data>
              <key>{normalize-space(substring-before($line, " - "))}</key>
              <value>{normalize-space(substring-after($line, " - "))}</value>
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
          (: Read the whole list item up to its first <br/>, not just its first
           : text node.  LC wraps anything changed in the current update in
           : <span class="changed">, which splits the label off the text node and
           : left 540$f keyed "f -" with an empty label.  Everything before the
           : first <br/> keeps the static-value lists out of the label. :)
          let $head := normalize-space(string-join($td/node()[not(preceding-sibling::br)]))
          let $key :=
            normalize-space(substring-after(substring-before($head, " - "), "$"))
          let $value := ms:strip-repeat-marker(substring-after($head, " - "))
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
        (: Older LC markup: subfields are bare text separated by <br/>, with no
         : list structure.  Walking br/preceding-sibling::text() silently drops
         : the last entry in each cell, because nothing follows it -- that is how
         : 017$i, 222$b, 242$n and 542$k went missing.  Take every <br/>-delimited
         : run instead, so a trailing entry counts like any other. :)
        for $line in $table//tr[3]/td ! ms:split-on-br(.)
        where matches($line, "^\$\S+\s+-\s+\S")
        return <subfield>{
          let $repeat :=
            if (contains($line, "(R)"))
            then <repeat>true</repeat>
            else <repeat>false</repeat>
          let $key :=
            normalize-space(substring-after(substring-before($line, " - "), "$"))
          let $value := ms:strip-repeat-marker(substring-after($line, " - "))
          return <data>
            <key>{$key}</key>
            <name>{$value}</name>
            {$repeat}
          </data>
        }</subfield>
      )
  }</subfields>
};


(:~
 : What this field used to define, and stopped.
 :
 : LC keeps retired content designators in a "Content Designator History"
 : section rather than in the subfield and indicator tables, so a withdrawn
 : element is simply absent from everything else this module reads.  That makes
 : it indistinguishable, from the schema alone, from an element LC never
 : documented -- and the two need opposite treatment in a conversion, since an
 : obsolete subfield needs no support and an undocumented one may.
 :
 : Three properties of the section that each produced a wrong answer first:
 :
 : * A code can be retired and later REISSUED with a different meaning.  856 $l
 :   was "Logon" (obsolete 2020) and is now "Standardized information governing
 :   access".  This function reports what the history says; deciding whether a
 :   code is obsolete *now* means checking it is also absent from the current
 :   subfield table, which the caller can do because both are in scope.
 : * The indicator POSITION is contextual.  A line reads "0 - United States
 :   [OBSOLETE]" and never names its indicator, so it has to come from the
 :   nearest preceding "Indicator N" heading.  Reading it from the line yields
 :   nothing at all.
 : * Leader and 007 byte values appear here too, in a third shape that is
 :   neither subfield nor indicator.  They are kept as <history> rather than
 :   discarded, so a later pass can classify them without a re-scrape.
 :)
declare function ms:parse-obsolete(
  $doc as element()
) as element(obsolete) {

  <obsolete>{
    for $e in $doc//*[contains(., "OBSOLETE")][not(.//*[contains(., "OBSOLETE")])]
    let $s := normalize-space(string($e))
    let $ctx := (
      for $n in $e/preceding::*[
                  matches(normalize-space(string(.)), "^Indicator\s*[12]\b")][
                  not(.//*[matches(normalize-space(string(.)), "^Indicator\s*[12]\b")])]
      return normalize-space(string($n))
    )[last()]
    let $year :=
      if (matches($s, "\[OBSOLETE,\s*[0-9][0-9][0-9][0-9]"))
      then replace($s, "^.*\[OBSOLETE,\s*([0-9][0-9][0-9][0-9]).*$", "$1")
      else ""
    let $label := normalize-space(replace($s, "^.*?\s+-\s+(.*?)\s*\[OBSOLETE.*$", "$1"))
    return
      if (matches($s, "^\$[a-z0-9]\s+-\s+"))
      then <subfield code="{substring($s, 2, 1)}" year="{$year}">{$label}</subfield>
      else if (matches($s, "^Indicator\s*[12]\s+-\s+"))
      then <indicator n="{replace($s, '^Indicator\s*([12]).*$', '$1')}"
                      year="{$year}">{$label}</indicator>
      else if (matches($s, "^[0-9#]\s+-\s+"))
      then <indicator-value
              n="{if (matches($ctx, '^Indicator\s*[12]'))
                  then replace($ctx, '^Indicator\s*([12]).*$', '$1') else '?'}"
              code="{if (substring($s, 1, 1) = '#') then ' ' else substring($s, 1, 1)}"
              year="{$year}">{$label}</indicator-value>
      else <history year="{$year}">{$s}</history>
  }</obsolete>

};
