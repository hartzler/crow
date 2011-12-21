# util.coffee
#   requires jquery
#
# General utility functions and classes.  Will be required most everywhere,
# so be very intentional what you put here.

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
  error: (message) ->
    @log 0,message
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

# exports
window.Util = Util

