dump("*** roster_list.js *** Loading...\n")

logger = new Util.Logger("Crow::RosterList", 'debug')

Components.utils.import("resource://gre/modules/Services.jsm")
Components.utils.import("resource://gre/modules/FileUtils.jsm")

class Friend
  constructor: (@jid,@presence,@is_room,@account,@vcard={}) ->
    @presence or= {show: "chat", status: null}
    @last_vcard_request_time = null
  safeid: => @jid.jid.replace(/[^a-zA-Z 0-9]+/g,'')
  email: -> @jid.jid
  display: -> if @vcard.fullname then @vcard.fullname else @jid.jid
  name: -> if @vcard and @vcard.fullname then @vcard.fullname else null
  resource: -> @jid.resource
  node: -> @jid.node
  status: -> @presence.status
  show: -> @presence.show || "chat"
  has_icon: =>
    if @vcard.icon && @vcard.icon.type && @vcard.icon.binval
      true
    else
      false
  icon_uri: (dfault) =>
    if @vcard.icon && @vcard.icon.type && @vcard.icon.binval
      "data:#{@vcard.icon.type};base64,#{@vcard.icon.binval}"
    else
      # other stuff, not handled yet...
      dfault
  toString: ->"<Friend jid=#{@jid.jid}>"
  toModel: ->
    jid: @jid,vcard:@vcard,presence:{},is_room:@is_room,account:@account, last_vcard_request_time:@last_vcard_request_time

file = FileUtils.getFile("ProfD", ["roster.sqlite"])
dbConn = Services.storage.openDatabase(file)
try
  dbConn.executeSimpleSQL("select roster_json from rosters limit 1;")
catch e
  try
    dbConn.executeSimpleSQL("CREATE  TABLE rosters (roster_json text not null) ")
  catch e
    logger.error e
class RosterList
  constructor: ()->
    @contacts_by_jid = {}
    @contacts_safe_jid_to_jid = {}
    @logger = logger
  load_from_prefs: ()->
    try
      stmt = dbConn.createStatement("select roster_json from rosters limit 1;")
      while(stmt.step())
        contacts = stmt.row.roster_json
    catch e
      @logger.error(e)
    contacts or= "[]"
    try
      contacts = JSON.parse(contacts)
    catch e
      contacts = []
    try
      @loading = true
      for contact in contacts
        @logger.info("DBload:#{contact.jid.jid}")
        @find_or_create(contact.jid,null,contact.is_room,contact.account,contact.vcard)
    finally
      @loading = false
  save_to_prefs: ()->
    return if @loading
    string = JSON.stringify(@toModel())
    try
      dbConn.executeSimpleSQL("delete from rosters")
    catch e
      @logger.error("DONT PANIC: i think its ok if we cant delete the rosters at first")
    dbConn.executeSimpleSQL("insert into rosters (roster_json) values ('#{string.replace(/'/g,"\\'")}')")

  toModel: ->
    (contact.toModel() for contact in @friend_list())

  friends_by_state: ()->
    states = {}
    for jid,contact of @contacts_by_jid
      states[contact.status] or= {}
      states[contact.status][jid]=contact
    states
  friend_list: ()->
    (contact for jid,contact of @contacts_by_jid)
  updateState: (jid,state)->
    @contacts_by_jid[jid].state(state)
  add_friend: (jid,friend)->
    @contacts_by_jid[jid] = friend
  find: (jid)->
    @contacts_by_jid[jid]
  find_by_safe_id: (safe_id)->
    @contacts_by_jid[@contacts_safe_jid_to_jid[safe_id]]
  find_or_create: (jid,presence,is_room,account,vcard) ->
    presence or= {show: "unavailable", status: null}
    @logger.debug "Looking for jid: #{jid.jid}"
    if @contacts_by_jid[jid.jid]?
      @logger.debug "Cached object"
      contact = @contacts_by_jid[jid.jid]
      contact.presence = presence
      contact.vcard = vcard if vcard
      @save_to_prefs()
      return contact
    contact = new Friend(jid,presence,is_room,account,vcard)
    @contacts_by_jid[jid.jid] = contact
    @contacts_safe_jid_to_jid[contact.safeid()]=jid.jid
    @save_to_prefs()
    contact
  load_roster: (account,roster)->
    try
      for item in roster.getChildren('query')[0].children
        jid = item.attributes["jid"]
        subscription = item.attributes["subscription"]
        name = item.attributes["name"]
        groups = (group.innerXML() for group in item.children)
        n = new XMLNode(null, null, "iq", "iq", null)
        n.attributes["id"]="roster_1"
        n.attributes["type"]="get"
        n.attributes["to"]= jid
        c=new XMLNode(null, null, "vCard", "vCard")
        c.attributes["xmlns"] = $NS.vcard
        Stanza._addChildren(n,c)
        friend = @find_or_create {jid:jid},null,false,account.name
        if not friend.vcard or jQuery.isEmptyObject(friend.vcard)
          account.session.sendStanza n
        friend

    catch e
      @logger.error("error load_roster")
      @logger.error(e)

# exports
window.RosterList = RosterList
