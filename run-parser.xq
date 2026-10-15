xquery version "4.0";

import module namespace ms = "__marc-scraper__" at "src/marc-scraper.xqm";

(: Path to the output directory :)
declare variable $ms:DIR as xs:string external := "";

for $p in ms:parse-docs()
  let $db := $p/data(@db)
  return file:write-text($ms:DIR||"marc21_"||$db||"_schema.json",
    serialize(
      <fn:map>
        <fn:string key="title">MARC21 {$db} format</fn:string>
        <fn:string key="url">https://www.loc.gov/marc/{$db}/</fn:string>
        <fn:string key="language">en</fn:string>
        <fn:string key="family">marc</fn:string>
        <fn:map key="fields">{
          for $field in $p/*
          let $key := if ($field/data(@code) = "leader") then "LDR" else $field/data(@code)
          let $name := $field/data(title)
          let $positions := <fn:map key="positions">{
            if ($field/positions/group)
            then
              for $group in $field/positions/group            
              let $code := $group/data(@code)
              return
                <fn:array key="{$code}">{
                  for $data in $group/data
                  let $name := $data/data(name)
                  let $start := xs:integer($data/start)
                  let $end := xs:integer($data/stop)               
                  return (
                    <fn:map key="{$start}-{$end}">
                      <fn:string key="label">{$name}</fn:string>                        
                      <fn:number key="start">{$start}</fn:number>  
                      <fn:number key="end">{$end}</fn:number>
                    </fn:map>                   
                  )
                }</fn:array>
            else if ($field/data/positions)
            then
              for $data in $field/data
              let $name := $data/data(name)           
              let $start := xs:integer($data/positions/start)
              let $end := xs:integer($data/positions/stop)
              let $values :=
                <fn:map key="codes">{
                  for $entry in $data/values/entry[normalize-space(name)]                                     
                  let $code := if ($entry/data(code) = "#") then " " else $entry/data(code)
                  return
                    <fn:string key="{$code}">{data($entry/data(name))}</fn:string>
                }</fn:map>
              return
                <fn:map key="{$start}-{$end}">
                  <fn:string key="label">{$name}</fn:string>
                  <fn:number key="start">{$start}</fn:number>
                  <fn:number key="end">{$end}</fn:number>
                  {$values}                    
                </fn:map>                                      
          }</fn:map>
          let $repeatable := $field/data(repeat)
          let $indicators := <fn:map key="indicators">{
            if ($field/indicators/*)
            then (
              for $ind in $field/indicators/entry
              return
                <fn:map key="indicator{$ind/@n}">
                  <fn:string key="label">{$ind/data(name)}</fn:string>                    
                  <fn:map key="codes">{
                    for $value in $ind/data
                    let $code := if ($value/key = "#") then " " else $value/key
                    return
                      <fn:string key="{$code}">{$value/data(value)}</fn:string>
                  }</fn:map>
               </fn:map>
            )
            else ()
          }</fn:map>              
          let $subfields := <fn:map key="subfields">{             
            for $sf in $field/subfields[1]/subfield[normalize-space(data/key)]/data
            let $name := $sf/data(name)
            let $repeat := $sf/data(repeat)
            return
              <fn:map key="{$sf/key}">
                <fn:string key="label">{$name}</fn:string>
                <fn:boolean key="repeatable">{
                  if (exists($repeat)) {$repeat} else {false()}
                }</fn:boolean>
                {
                  if ($sf/static-values)
                  then <fn:map key="codes">{
                    for $sv at $p in $sf/static-values/data
                    let $key := 
                      if (normalize-space($sv/key))
                      then $sv/data(key)
                      else $p - 1               
                    let $name := $sv/data(name)
                    return <fn:map key="{$key}">
                      <fn:string key="label">{$name}</fn:string>
                      <fn:string key="code">{$key}</fn:string>
                    </fn:map>
                  }</fn:map>
                }
              </fn:map>             
            }</fn:map>         
          (: What LC used to define here.  `reissued` is the load-bearing flag:
           : a code in the history that is ALSO in the current subfield table
           : has been given a new meaning, not withdrawn -- 8 of 59 on the
           : bibliographic format, six of them on 856 alone.  Consumers asking
           : "may I ignore this?" must read `obsolete_now`, never mere presence. :)
          let $obsolete := <fn:map key="obsolete">{
            let $current := $field/subfields[1]/subfield/data/key/string()
            return (
              (: Arrays, not maps.  A code can be retired MORE THAN ONCE -- LC
               : lists a separate history line per format context, so 5 fields
               : carry two entries for the same code and a map collides on the
               : second.  The history is a log of events, not a lookup. :)
              <fn:array key="subfields">{
                for $o in $field/obsolete/subfield
                let $code := $o/data(@code)
                return <fn:map>
                  <fn:string key="code">{$code}</fn:string>
                  <fn:string key="label">{$o/string()}</fn:string>
                  <fn:string key="year">{$o/data(@year)}</fn:string>
                  <fn:boolean key="reissued">{$code = $current}</fn:boolean>
                  <fn:boolean key="obsolete_now">{not($code = $current)}</fn:boolean>
                </fn:map>
              }</fn:array>,
              <fn:array key="indicator_values">{
                for $o in $field/obsolete/indicator-value
                return <fn:map>
                  <fn:string key="indicator">{$o/data(@n)}</fn:string>
                  <fn:string key="value">{$o/data(@code)}</fn:string>
                  <fn:string key="label">{$o/string()}</fn:string>
                  <fn:string key="year">{$o/data(@year)}</fn:string>
                </fn:map>
              }</fn:array>,
              <fn:array key="indicators">{
                for $o in $field/obsolete/indicator
                return <fn:map>
                  <fn:string key="indicator">{$o/data(@n)}</fn:string>
                  <fn:string key="label">{$o/string()}</fn:string>
                  <fn:string key="year">{$o/data(@year)}</fn:string>
                </fn:map>
              }</fn:array>,
              <fn:array key="history">{
                for $o in $field/obsolete/history
                return <fn:map>
                  <fn:string key="text">{$o/string()}</fn:string>
                  <fn:string key="year">{$o/data(@year)}</fn:string>
                </fn:map>
              }</fn:array>
            )
          }</fn:map>
          return         
            <fn:map key="{$key}">
              <fn:string key="label">{$name}</fn:string>
              {if ($positions/*) {$positions}}
              {if ($indicators/*) {$indicators/*}}
              {if ($subfields/*) {$subfields}}
              {if ($field/obsolete/*) {$obsolete}}
              <fn:boolean key="repeatable">{$repeatable}</fn:boolean>
            </fn:map>
          }</fn:map>            
        </fn:map>
    , 
    map {
      "method": "json", "escape-solidus": "no", "json": map {
        "format": "basic", "indent": "yes"
      }
    }
  ) ! proc:execute("jq", ("-sS", ., "."))/output/text()
)
(: Record what the format-currency filter removed, so a shrinking field count is
 : traceable to LC retiring a field rather than to a scraping failure. :)
,
file:write-text($ms:DIR||"excluded_fields.json",
  serialize(
    <fn:map>{
      for $d in ms:excluded-fields()
      return
        <fn:map key="{$d/@db}">{
          for $f in $d/field
          return
            <fn:map key="{$f/@code}">
              <fn:string key="label">{$f/data(title)}</fn:string>
              <fn:string key="filed_under">{$f/data(filed-under)}</fn:string>
            </fn:map>
        }</fn:map>
    }</fn:map>,
    map {
      "method": "json", "escape-solidus": "no", "json": map {
        "format": "basic", "indent": "yes"
      }
    }
  ) ! proc:execute("jq", ("-sS", ., "."))/output/text()
)
