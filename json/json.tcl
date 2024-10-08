
package require json
package require json::write

source $::env(TRAILS_HOME)/misc/util.tcl


namespace eval ::trails::json {

  namespace export \
    tcl2json \
    json2dict \
    model_to_json \
    model_list_to_json \
    dict_to_json \
    list_to_json \
    json_to_dict

  proc model_to_json {model args} {
    set json [$model to_json]
    dict with json {
      tcl2json $data -tpl $tpl
    }    
  }

  proc model_list_to_json {models args} {
    set items [lmap it $models {$it to_json_data}]

    if {[llength $models] == 0} {
      return {[]}
    }

    set tpl [[lindex $models 0] to_json_tpl]

    tcl2json $items -tpl $tpl -list
  }

  proc dict_to_json {value args} {
    tcl2json $value {*}$args
  }

  proc list_to_json {value args} {
    tcl2json $value {*}$args -list
  }

  proc json_to_dict {} {
    json2dict $text
  }

  # tepl is a dict
  proc tcl2json {value args} {
    # Guess the type of the value; deep *UNSUPPORTED* magic!

    set tpl {}
    set type {}

    foreach {k v} $args {
      switch -regexp -- $k {
        -tpl {
          set tpl $v
        }
        -type {
          set type $v
        }
      }      
    }
    
    if {$type == ""} {
      regexp {^value is a (.*?) with a refcount} \
        [::tcl::unsupported::representation $value] -> type

      if {[string match "pure*" $type]} {
        regexp {^value is a pure (.*?) with a refcount} \
          [::tcl::unsupported::representation $value] -> type
      }
    }  

    switch -regexp -- $type {
      dict {

        set mapResult {}

        if {[llength $tpl] > 0} {
          dict for {k v} $value {
            set type ""

            if {[dict exists $tpl $k]} {
              set type [dict get $tpl $k] 
            } 

            if {[llength $type] > 1} {
              set typ [lindex $type 0]
              dict set mapResult $k [tcl2json $v -type $typ -tpl [lindex $type 1]]
            } else {
              dict set mapResult $k [tcl2json $v -type $type]
            }
          }          
        } else {
          set mapResult [dict map {k v} $value {tcl2json $v}]
        }

        return [json::write object {*}$mapResult]
      }
      list {
        set args {}
        if {[llength $tpl] == 1} {
          set args [list -type $tpl]
        } else {
          set args [list -type dict -tpl $tpl]
        }

        return [json::write array {*}[lmap v $value {tcl2json $v {*}$args}]]
      }
      int|double {
        return [expr {$value}]
      }
      boolean|bool {
        return [expr {$value ? true : false}]
      }
      booleanString {
        return [json::write string $value]
      }
      string|str {
        return [json::write string $value]
      }
      default {
        if {$value eq "null"} {
        # Tcl has *no* null value at all; empty strings are semantically
        # different and absent variables aren't values. So cheat!
          return $value
        } elseif {$value eq {[]}} {
          return [json::write array [list]]
        } elseif {[string is integer -strict $value]} {
          return [expr {$value}]
        } elseif {[string is double -strict $value]} {
          return [expr {$value}]
        } elseif {[string is boolean -strict $value]} {
          return [expr {$value ? true : false}]
        } elseif {[string is true -strict $value]} {
          return true
        } elseif {[string is false -strict $value]} {
          return false
        }
        return [json::write string $value]
      }
    }
  }

  proc json2dict {text}  {
    return [json::json2dict $text]
  }
}

