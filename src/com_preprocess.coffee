module = @
require 'fy'
require 'fy/codegen'
com_lang = require 'com-lang'
{tag_hash, tag_list} = require 'html-tag-collection'

@preprocess_react = (code, opt)->
  unless opt.no_com_lang
    code = com_lang.preprocess(code, opt)
  
  # NOTE missing children
  instance_code = """
    define_com #{JSON.stringify opt.name}, conf
    """
  
  if opt.HACK_remove_module_exports
    if reg_ret = /^([\s\S]*)module.exports\s*=([\s\S]*)$/.exec code
      [_skip, code_before, code_after] = reg_ret
    else
      code_before = ''
      code_after = code
    
    code = """
      com_name = #{JSON.stringify opt.name}
      #{code_before}
      conf = React.createClass CKR.react_key_map com_name, #{code_after}
      #{instance_code}
      """
  else
    code = """
      com_name = #{JSON.stringify opt.name}
      window.module ?= {}
      #{code}
      conf = React.createClass CKR.react_key_map com_name, module.exports
      #{instance_code}
      """
  
  code

@react_runtime = ()->
  ret = []
  for tag in tag_list
    ret.push """
      define_tag #{JSON.stringify tag}
      """
  """
  _react_key_map = {
    mount       : 'componentWillMount'
    mount_done  : 'componentDidMount'
    unmount     : 'componentWillUnmount'
    unmount_done: 'componentDidUnmount'
    props_change: 'componentWillReceiveProps'
  }
  _react_attr_map = {
    class         : 'className'
    on_change     : 'onChange'
    on_click      : 'onClick'
    on_wheel      : 'onWheel'
    on_mouse_move : 'onMouseMove'
    on_mouse_down : 'onMouseDown'
    on_mouse_out  : 'onMouseOut'
    on_move_over  : 'onMouseOver'
    on_hover      : 'onMouseOver'
  }
  window.CKR = 
    __node_buffer : []
    prop : (t)->
      for lookup_list in CKR.__node_buffer
        lookup_list.remove t
      return t
    list : (t)->
      CKR.__node_buffer.uappend t
    react_key_map : (name, t)->
      ret = {
        name
        displayName: name
      }
      if t.state
        if typeof t.state != 'function'
          old_state = t.state
          t.state = ()->clone old_state
        t.getInitialState = t.state
        delete t.state
      for k,v of t
        if k2 = _react_key_map[k]
          ret[k2] = v
        ret[k] = v
      ret.set_state = ()->@setState arguments...
      ret.force_update = ()->@forceUpdate arguments...
      ret
  define_tag = (name)->
    # temp disable Т.к. ломает только fy.p
    # if window[name]?
    #   perr 'WARNING something bad is happening. You trying to rewrite already defined window property '+name+'. It can break app'
    window[name] = ()->
      children = []
      attrs    = {}
      for arg in arguments
        continue if !arg?
        if arg.$$typeof? # React element
          children.push arg
        else if Array.isArray arg
          children.uappend arg
        else if typeof arg == 'object'
          for k,v of arg
            attrs[_react_attr_map[k] or k] = v
        else if typeof arg == 'function'
          CKR.__node_buffer.push []
          t = arg()
          children.uappend CKR.__node_buffer.pop()
          if Array.isArray t
            children.uappend t
          else
            children.upush t
        else if typeof arg == 'string'
          children.push arg
        else if typeof arg == 'number'
          children.push arg.toString()
      
      ret = if children.length
        React.createElement(name, attrs, children...)
      else
        React.createElement(name, attrs)
      if last = CKR.__node_buffer.last()
        for buf in CKR.__node_buffer
          buf.remove ret
          for v in children
            buf.remove v
        last.push ret
      ret
    return
  define_com = (name, react_class)->
    if window[name]?
      if !window.hotreplace
        perr 'WARNING something bad is happening. You trying to rewrite already defined window property '+name+'. It can break app'
    window[name] = ()->
      children = []
      attrs    = {}
      for arg in arguments
        continue if !arg?
        if arg.$$typeof? # React element
          children.push arg
        else if Array.isArray arg
          children.uappend arg
        else if typeof arg == 'object'
          for k,v of arg
            attrs[k] = v # NOTE NO mapping
        else if typeof arg == 'function'
          CKR.__node_buffer.push []
          t = arg()
          children.uappend CKR.__node_buffer.pop()
          if Array.isArray t
            children.uappend t
          else
            children.upush t
        else if typeof arg == 'string'
          children.push arg
        else if typeof arg == 'number'
          children.push arg.toString()
      
      ret = if children.length
        React.createElement(react_class, attrs, children...)
      else
        React.createElement(react_class, attrs)
      if last = CKR.__node_buffer.last()
        for buf in CKR.__node_buffer
          buf.remove ret
          for v in children
            buf.remove v
        last.push ret
      ret
    return
  #{join_list ret}
  """