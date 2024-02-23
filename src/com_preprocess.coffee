module = @
require "fy"
require "fy/codegen"
com_lang = require "com-lang"
{tag_hash, tag_list} = require "html-tag-collection"

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
      code_before = ""
      # protection from empty file
      code_after = code or """
        {
          render : ()->
            div()
        }
        """
    
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
  
  # https://developer.mozilla.org/ru/docs/Web/Events
  # https://ru.reactjs.org/docs/events.html
  # не все события перенесены, только самые важные и используемые, переносить по мере надобности
  _react_attr_map = {
    class         : "className"
    # form
    on_change     : "onChange"
    on_input      : "onInput"
    on_invalid    : "onInvalid"
    on_reset      : "onReset"
    on_submit     : "onSubmit"
    
    on_error      : "onError"
    on_load       : "onLoad"
    
    # keyboard
    on_key_down   : "onKeyDown"
    on_key_press  : "onKeyPress"
    on_key_up     : "onKeyUp"
    
      
    # clipboard c (почти не используемые)
    on_copy       : "onCopy"
    on_cut        : "onCut"
    on_paste      : "onPaste"
    
    # onCompositionEnd onCompositionStart onCompositionUpdate
    # я считаю не используемые вообще
    
    # mouse
    on_click      : "onClick"
    on_dblclick   : "onDoubleClick"
    on_context_menu : "onContextMenu"
    on_wheel      : "onWheel"
    on_mouse_move : "onMouseMove"
    on_mouse_down : "onMouseDown"
    on_mouse_up   : "onMouseUp"
    on_mouse_out  : "onMouseOut"
    on_mouse_over : "onMouseOver"
    # only for parent, not children
    on_move_enter : "onMouseEnter"
    on_move_leave : "onMouseLeave"
    
    # drag'n'drop (почти не используемые)
    on_drag       : "onDrag"
    on_drag_end   : "onDragEnd"
    on_drag_enter : "onDragEnter"
    on_drag_exit  : "onDragExit"
    on_drag_leave : "onDragLeave"
    on_drag_over  : "onDragOver"
    on_drag_start : "onDragStart"
    on_drop       : "onDrop"
    
    # для ввода пером
    # onPointerDown onPointerMove onPointerUp onPointerCancel onGotPointerCapture
    # onLostPointerCapture onPointerEnter onPointerLeave onPointerOver onPointerOut
    # я считаю не используемые вообще
    
    # touch
    on_touch_cancel : "onTouchCancel"
    on_touch_end    : "onTouchEnd"
    on_touch_move   : "onTouchMove"
    on_touch_start  : "onTouchStart"
    
    
    # focus
    on_focus      : "onFocus"
    on_blur       : "onBlur"
    
    
    # special
    on_select     : "onSelect"
    on_scroll     : "onScroll"
    # onTransitionEnd
    # onToggle
    
    # media
    # onAbort onCanPlay onCanPlayThrough onDurationChange onEmptied onEncrypted
    # onEnded onError onLoadedData onLoadedMetadata onLoadStart onPause onPlay
    # onPlaying onProgress onRateChange onSeeked onSeeking onStalled onSuspend
    # onTimeUpdate onVolumeChange onWaiting
    # я считаю используемые очень-очень редко
    
    # animation
    # onAnimationStart onAnimationEnd onAnimationIteration
    # непонятно. Вроде должны быть используемые, но мне ни разу не пригодились
    
    
    # alias
    on_hover      : "onMouseOver"
  }
  
  """
  _react_key_map = {
    mount       : "componentWillMount"
    mount_done  : "componentDidMount"
    unmount     : "componentWillUnmount"
    unmount_done: "componentDidUnmount"
    props_change: "componentWillReceiveProps"
  }
  _react_attr_map = #{JSON.stringify _react_attr_map, null, 2}
  window.CKR = 
    __node_buffer : []
    prop : (t)->
      for lookup_list in CKR.__node_buffer
        lookup_list.remove t
      return t
    list : (t)->
      CKR.__node_buffer.uappend t
    item : (fn, arg...)->
      CKR.__node_buffer.last().upush fn arg...
    react_key_map : (name, t)->
      ret = {
        name
        displayName: name
      }
      if t.state
        if typeof t.state != "function"
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
    #   perr "WARNING something bad is happening. You trying to rewrite already defined window property "+name+". It can break app"
    window[name] = ()->
      children = []
      attrs    = {}
      for arg in arguments
        continue if !arg?
        if arg.$$typeof? # React element
          children.push arg
        else if Array.isArray arg
          children.uappend arg
        else if typeof arg == "object"
          for k,v of arg
            attrs[_react_attr_map[k] or k] = v
        else if typeof arg == "function"
          CKR.__node_buffer.push []
          t = arg()
          children.uappend CKR.__node_buffer.pop()
          if Array.isArray t
            children.uappend t
          else
            children.upush t
        else if typeof arg == "string"
          children.push arg
        else if typeof arg == "number"
          children.push arg.toString()
      
      # host patch (for extensions)
      if window.host_patch and name in ["img", "video"]
        if attrs.src[0] == "/"
          attrs.src = window.host_patch + attrs.src
      
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
  window.define_com = (name, react_class)->
    if window[name]?
      if !window.hotreplace
        perr "WARNING something bad is happening. You trying to rewrite already defined window property "+name+". It can break app"
    window[name] = ()->
      children = []
      attrs    = {}
      for arg in arguments
        continue if !arg?
        if arg.$$typeof? # React element
          children.push arg
        else if Array.isArray arg
          children.uappend arg
        else if typeof arg == "object"
          for k,v of arg
            attrs[k] = v # NOTE NO mapping
        else if typeof arg == "function"
          CKR.__node_buffer.push []
          t = arg()
          children.uappend CKR.__node_buffer.pop()
          if Array.isArray t
            children.uappend t
          else
            children.upush t
        else if typeof arg == "string"
          children.push arg
        else if typeof arg == "number"
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
  """#"
