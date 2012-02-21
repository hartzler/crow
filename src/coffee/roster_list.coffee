class RosterList
  constructor: ()->
    @contacts_by_jid = {}
    @contacts_safe_jid_to_jid = {}
    @logger = new Util.Logger("Crow::RosterList", 'debug')
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
  find_or_create: (jid,presence,is_room,account,vcard={}) ->
    presence or= {show: "unavailable", status: null}
    @logger.debug "Looking for jid: #{jid.jid}"
    if @contacts_by_jid[jid.jid]?
      @contacts_by_jid[jid.jid].presence = presence 
      @contacts_by_jid[jid.jid].vcard = vcard if vcard
      return @contacts_by_jid[jid.jid]
    contact = new window.Friend(jid,presence,is_room,account,vcard)
    @contacts_by_jid[jid.jid] = contact
    @contacts_safe_jid_to_jid[contact.safeid()]=jid.jid
    contact
  load_roster: (account,roster)->
    try
      for item in roster.getChildren('query')[0].children
        jid = item.attributes["jid"]
        subscription = item.attributes["subscription"]
        name = item.attributes["name"]
        groups = (group.innerXML() for group in item.children)
        @find_or_create {jid:jid},null,false,account.name
    catch e
      @logger.error("error load_roster")
      @logger.error(e)

window.roster = new RosterList
