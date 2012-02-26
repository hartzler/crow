# util.coffee
#   requires jquery
#
# General utility functions and classes.  Will be required most everywhere,
# so be very intentional what you put here.

dump("*** util.js *** Loading...\n")

Util = {}
window.Util = Util

# basic log4x like class
class Logger
  $ = jQuery
  @levels: {error:0 ,warn:1 ,info:2 ,debug:3}
  @level_names: ['error','warn','info','debug']

  constructor: (@context, level, @callbacks, @dump=true) ->
    @current_level = Logger.levels[level]
  level: (level) ->
    if(level in [0..3])
      @current_level = level
  log: (level,message) ->
    if level <= @current_level
      date = new Date()
      text = @stringify(message)
      dump "#{date.toISOString()} #{Logger.level_names[level]} [#{@context}] #{text}\n" if @dump
      @callbacks.log date,level,@context,text if @callbacks?.log?
  error: (message,e=null) ->
    @log 0,"#{message}#{if e? then " error=#{e.toString()} stack: #{e.stack}" else ''}"
  warn: (message) ->
    @log 1,message
  info: (message) ->
    @log 2,message
  debug: (message) ->
    @log 3,message

  stringify: (s) ->
    switch $.type(s)
      when "object" then  s.toSource()
      when "undefined", "null" then null
      else s

Util.logger = logger = new Logger('Crow::Util','debug') # someobody has to set a callback to see any logs out of this
Util.Logger = Logger

# common ui helper
clone_template = (id) ->
  div = $(id).clone()
  div.attr('id',null)
  div.removeClass('template')
  div.show()
  div

Util.clone_template = clone_template

# simple pub/sub
class PubSub
  constructor: ->
    @events = {}
  on: (name,f)=>
    @events[name] or= jQuery.Callbacks()
    @events[name].add(f)
  pub: (name,args...)=>
    @events[name].fire.apply(null,args) if @events[name]
  chain: (pubsub, name)=>
    @events[name] = pubsub.events[name] or= jQuery.Callbacks()
Util.PubSub = PubSub

Util.h = (str) ->
  String(str)
    .replace(/&/g, '&amp;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')

Util.dom_to_string = (e) ->
  return '' unless e

  if e.nodeType is 3
    Util.h(e.textContent)
  else if e.nodeType is 1
    "<#{e.nodeName} #{(" #{att.name}=\"#{Util.h(att.value)}\"" for att in e.attributes).join('')}>" +
    (if e.hasChildNodes()
      ("#{Util.dom_to_string(child)}" for child in e.childNodes).join('')
    else
      '') +
    "</#{e.nodeName}>"
  else
    '' # screw other node types for now

class API
  constructor: (options)->
    @call_prefix = options.call_prefix or ""
    @listen_prefix = options.listen_prefix or ""
    @window = options.window or window
    @logger = options.logger or logger
  
  prefix: (prefix,name)->
    "#{prefix}:#{name}"

  on: (handlers) ->
    for name, handler of handlers
      name = @prefix(@listen_prefix,name)
      @window.addEventListener name, @_listener(name,handler), false

  _listener: (name, handler)->
    @logger.debug("API: registering listener for #{name}...")
    (e)=>
      try
        data = e.target.getUserData("crow-request")
        @logger.debug("api received: #{name} -> #{data.toSource()}")
        @window.document.documentElement.removeChild(e.target)
        handler(data)
      catch e
        @logger.error("API: error in listener for #{name}",e)

  call: (name,data,callback)->
    name = @prefix(@call_prefix,name)
    @logger.debug("API: call: #{name} -> #{data.toSource()}")
    doc = @window.document
    request = doc.createTextNode('')
    request.setUserData("crow-request",data,null)
    doc.documentElement.appendChild(request)
    sender = doc.createEvent("HTMLEvents")
    sender.initEvent(name, true, false)
    request.dispatchEvent(sender)
    @logger.debug "dispatched event #{sender} to #{request}"

Util.API=API

# exports
window.Util = Util

