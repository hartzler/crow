class RosterList
  constructor: ()->
    @contacts_by_jid = {}
    @logger = new Util.Logger("Crow::RosterList", 'debug')
  contacts_by_state: ()->
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

  find_or_create: (jid,presence,is_room,account,vcard={}) ->
    presence or= {show: "unavailable", status: null}
    if @contacts_by_jid[jid.jid]?
      @contacts_by_jid[jid.jid].presence = presence
      return @contacts_by_jid[jid.jid]
    contact = new window.Friend(jid,presence,is_room,account,vcard)
    @contacts_by_jid[jid.jid] = contact
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
