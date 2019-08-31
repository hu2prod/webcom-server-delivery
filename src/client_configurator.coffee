module = @
_iced = require 'iced-coffee-script'
class @Webcom_plugin
  name : ''
  feature_hash : {}
  dependency_list : []
  code_gen : ()->throw new Error "unimplemented plugin"
  constructor:()->
    @feature_hash = {}
    @dependency_list = []
  
  
class @Webcom_plugin_registry
  plugin_hash : {}
  constructor:()->
    @plugin_hash = {}
  plugin_add : (plugin)->
    @plugin_hash[plugin.name] = plugin
    return
  

class @Webcom_bundle
  regisrty : null
  feature_hash : {}
  plugin_hash : {}
  _win_gen  : null
  constructor:(@regisrty)->
    @plugin_hash = {}
    @feature_hash = {}
    @feature_hash.subcomponent_list = []
    @feature_hash.heuristic_list = []
  
  plugin_add : (name)->
    return if @plugin_hash[name]
    if !plugin = @regisrty.plugin_hash[name]
      throw new Error "plugin '#{name}' not found"
    for sub in plugin.dependency_list
      @plugin_add sub
    
    @plugin_hash[name] = plugin
    plugin
  
  code_gen : ()->
    module.cs_compile @code_raw_gen()
  
  code_raw_gen : ()->
    ret = []
    for k,v of @plugin_hash
      bak = clone v.feature_hash
      obj_set v.feature_hash, @feature_hash
      ret.push v.code_gen()
      v.feature_hash = bak
    
    ret.join '\n'
  
  win_gen : ()->
    return @_win_gen if @_win_gen
    @_win_gen = eval """
      var window = {};
      #{@code_gen()}
      window
      """
    
@master_registry = new module.Webcom_plugin_registry
@cs_compile = (t)->_iced.compile t, bare:true, runtime:'inline'
