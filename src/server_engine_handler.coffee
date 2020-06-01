module = @
com_preprocess = require "./com_preprocess"

@_engine_cache = {}

@style    = /^(css|styl|stylus|less|sass)$/
@template = /^(html?|jade)$/
@script   = /^(js|coffee|iced)$/
@image    = /(png|jpe?g|gif|bmp|ico)$/
@font     = /(ttf|otf|woff|woff2)$/

image_regex = /^png|jpe?g|gif|bmp|ico$/
coffee_opt =
  # runtime : "inline"
  runtime : "none" # runtime in bundle

path_to_com_name = (com_name)->
  com_name = com_name.replace(/\.com\.coffee$/, "")
  # allow folder name == file name -> no dupe v2
  chunk_list = com_name.split "/"
  for chunk, idx in chunk_list
    continue if chunk == ""
    continue if !next = chunk_list[idx+1]
    continue if 0 != next.indexOf chunk
    chunk_list[idx+1] = next.substr chunk.length+1
  com_name = chunk_list.filter((t)->t).join "/"
  
  # category directories
  com_name = "/"+com_name
  loop
    old_com_name = com_name
    com_name = com_name.replace(/\/_[^\/]*\//, "/")
    break if old_com_name == com_name
  
  com_name = com_name.replace(/\//g, "_")
  
  # index files
  com_name = com_name.replace(/_index/g, "")
  com_name = com_name.replace(/index_/g, "")
  
  # replace _ prefix
  com_name = com_name.replace(/^_/, "")
  # replace multiple __ anywhere
  com_name = com_name.replace(/_+/g, "_")
  
  com_name = com_name[0].toUpperCase()+com_name.substr(1).toLowerCase() # Capitalize + lower case other
  return com_name
@eval = (engine_name, code, opt={})->
  if !engine = module._engine_cache[engine_name]
    switch engine_name
      # # ###################################################################################################
      # #    html
      # # ###################################################################################################
      # when "html"
      #   parser = require "webcom-server-template-parser"
      #   engine = (code, opt)->parser.parse code.toString(), opt
      # when "jade"
      #   mod = require "jade"
      #   parser = require "webcom-server-template-parser"
      #   engine = (code, opt)->parser.parse mod.compile(code.toString())(), opt
      # ###################################################################################################
      #    css
      # ###################################################################################################
      when "css"
        engine = (code, opt)->code.toString()
      when "stylus", "styl"
        mod = require "stylus"
        engine = (code, opt)->mod.render code.toString()
      # LATER less|sass
      # ###################################################################################################
      #    js
      # ###################################################################################################
      when "js"
        engine = (code, opt)->code.toString()
      when "min.js"
        engine = (code, opt)->code.toString()
      when "iced"
        mod = require "iced-coffee-script"
        engine = (code, opt)->
          return code if opt.keep_coffee
          mod.compile code.toString(), coffee_opt
      # честный
      # when "coffee"
        # mod = require "coffee-script"
        # engine = (code, opt)->mod.compile code.toString()
      # мы не хотим еще одну зависимость
      when "coffee"
        mod = require "iced-coffee-script"
        engine = (code, opt)->
          return code if opt.keep_coffee
          mod.compile code.toString(), coffee_opt
      when "com.coffee"
        mod = require "iced-coffee-script"
        engine = (code, opt)->
          code = code.toString()
          com_name = opt.url_path
          
          
          opt = clone opt
          opt.name = path_to_com_name opt.url_path
          
          code = com_preprocess.preprocess_react(code, opt)
          
          return code if opt.keep_coffee
          try
            return mod.compile code, coffee_opt
          catch e
            p code
            perr e
            throw new Error "can't compile"
      # ###################################################################################################
      #    images
      # ###################################################################################################
      else
        if module.image.test engine_name
          engine = (code, opt)->code
        if module.font.test engine_name
          engine = (code, opt)->code
        if !engine
          engine = (code, opt)->code
          perr "unknown engine #{engine_name}"
    module._engine_cache[engine_name] = engine
  engine code, opt

mime  = require "mime"
@canonical = (engine_name)->
  engine_name = engine_name.split(".").last() # normalize if filename
  return "image" if module.image.test engine_name
  return "css"   if module.style.test engine_name
  return "js"    if module.script.test engine_name
  return "html"  if module.template.test engine_name
  null

@mime = (engine_name)->
  canonical = module.canonical engine_name
  mime.getType if canonical == "image" or !canonical then engine_name else canonical
