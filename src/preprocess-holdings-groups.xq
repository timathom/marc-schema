xquery version "3.1";

import module namespace ms = "__marc-scraper__" at "marc-scraper.xqm";

(: let $docs := db:get("marc-holdings-docs")//data[range]
return db:create("mfhd-test", <data>{$docs}</data>, "data") :)


let $codes := (
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
)
let $doc := db:text("mfhd-test", "863")/..[self::range]/parent::data        
let $indicators := 
  $doc//table[.//text() contains text "Indicator" using case sensitive]        
let $subfields := $doc//table[.//text() contains text "Subfield" using case sensitive]
return (
  (: for $text in $indicators//td/text()
  where normalize-space($text)  
  return (
    if ($text[normalize-space()]/following-sibling::*[1][self::em])
    then 
      let $codes := 
        analyze-string($text[normalize-space()]/following-sibling::*[1][self::em], "[0-9]{1,3}")
      let $matches :=
        for $match in $codes//fn:match
        return 
          <range>{data($match)}</range>        
      return
        if ($codes//fn:match)
        then replace node $text with <data>{
          $matches[normalize-space()], <content>{$text}</content>
        }</data>  
        else () 
    else replace node $text with <data>{
      $doc/range
      ,
      <content>{normalize-space($text)}</content>
    }</data>
    ,
    delete node $text[normalize-space()]/following-sibling::*[1][self::em]
  )
  ,
  for $text in $subfields//td/text()
  where normalize-space($text)  
  return (
    if ($text[normalize-space()]/following-sibling::*[1][self::em])
    then 
      let $codes := 
        analyze-string($text[normalize-space()]/following-sibling::*[1][self::em], "[0-9]{1,3}")
      return 
        let $matches :=
          for $match in $codes//fn:match
          return 
            <range>{data($match)}</range>        
        return
          if ($codes//fn:match)
          then replace node $text with <data>{
            $matches[normalize-space()], <content>{$text}</content>
          }</data>  
          else ()      
    else replace node $text with <data>{
      for $r in distinct-values($doc/range)
      return <range>{$r}</range>
      ,
      <content>{normalize-space($text)}</content>
    }</data>
    ,
    delete node $text[normalize-space()]/following-sibling::*[1][self::em]
  ) :)$doc
)