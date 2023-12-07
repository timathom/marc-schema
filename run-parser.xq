xquery version "4.0";

import module namespace ms = "__marc-scraper__" at "src/marc-scraper.xqm";

(: Path to the output directory :)
declare variable $ms:DIR := "";

file:write($ms:DIR||"marc21_json_schema.json",
  <fn:array>{
    let $parsed := ms:parse-docs()
    for $p in $parsed
    let $db := $p/data(@db)
    return    
      <fn:map>{      
        <fn:map key="{$db}">{
          for $field in $p/*
          let $key := $field/data(@code)
          let $name := $field/data(title)
          let $fixed := if (exists($field/fixed)) {true()} else {false()}
          let $positions := <fn:array key="positions">{
            if ($field/positions/group)
            then
              for $group in $field/positions/group            
              let $code := $group/data(@code)
              return
                <fn:array key="{$code}">{
                  for $data in $group/data
                  let $name := $data/data(name)
                  let $start := xs:integer($data/start)
                  let $stop := xs:integer($data/stop)               
                  return (
                    <fn:map>
                      <fn:string key="label">{$name}</fn:string>                        
                      <fn:number key="start">{$start}</fn:number>  
                      <fn:number key="stop">{$stop}</fn:number>
                    </fn:map>                   
                  )
                }</fn:array>
            else if ($field/data/positions)
            then
              for $data in $field/data
              let $name := $data/data(name)           
              let $start := xs:integer($data/positions/start)
              let $stop := xs:integer($data/positions/stop)
              let $values :=
                <fn:map key="positions">{
                  for $entry in $data/values/entry[normalize-space(name)]                                        
                  return
                    <fn:string key="{$entry/data(code)}">{data($entry/data(name))}</fn:string>
                }</fn:map>
              return
                <fn:map>
                  <fn:string key="label">{$name}</fn:string>
                  <fn:number key="start">{$start}</fn:number>
                  <fn:number key="stop">{$stop}</fn:number>
                  {$values}                    
                </fn:map>                                      
          }</fn:array>
          let $repeatable := $field/data(repeat)
          let $indicators := <fn:map key="indicators">{
            if ($field/indicators/*)
            then (
              for $ind in $field/indicators/entry
              return
                <fn:map key="{$ind/@n}">
                  <fn:string key="label">{$ind/data(name)}</fn:string>                    
                  <fn:map key="codes">{
                    for $value in $ind/data
                    return
                      <fn:string key="{$value/key}">{$value/data(value)}</fn:string>
                  }</fn:map>
               </fn:map>
            )
            else ()
          }</fn:map>              
          let $subfields := <fn:map key="subfields">{             
            for $sf in $field/subfields[1]/subfield[normalize-space(data/key)]/data
            let $name := $sf/data(name)
            let $repeat := $sf/data(repeat)
            let $static := $sf/data(static)        
            return
              <fn:map key="{$sf/key}">
                <fn:string key="label">{$name}</fn:string>
                <fn:boolean key="repeatable">{
                  if (exists($repeat)) {$repeat} else {false()}
                }</fn:boolean>
                <fn:boolean key="static">{
                  if (exists($static)) {$static} else {false()}
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
          return         
            <fn:map key="{$key}">
              <fn:boolean key="fixed">{$fixed}</fn:boolean>
              <fn:string key="label">{$name}</fn:string>
              {if ($positions/*) {$positions}}
              {if ($indicators/*) {$indicators}}
              {if ($subfields/*) {$subfields}}
              <fn:boolean key="repeatable">{$repeatable}</fn:boolean>
            </fn:map>
          }</fn:map>            
        }</fn:map>
  }</fn:array>, 
  map {
    "method": "json", "escape-solidus": "no", "json": map {
      "format": "basic", "indent": "yes"
    }
  }
)
