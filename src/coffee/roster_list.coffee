class RosterList
  constructor: ()->
    @contacts_by_jid = {}
    @logger = new Util.Logger("Crow::RosterList", 'debug')
  contacts_by_state: ()->
    states = {}
    for jid,contact of @contacts_by_state
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
    presence or= {show: "chat", status: null}
    if @contacts_by_jid[jid.jid]?
      return @contacts_by_jid[jid.jid]
    contact = new window.Friend(jid,presence,is_room,account,vcard)
    @contacts_by_jid[jid.jid] = contact
    contact

window.roster = new RosterList

