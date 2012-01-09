document.onreadystatechange = ()->
  document.getElementById('txt').focus()if(document.readyState == "complete") 
  
window.humanize_time = ()->
  now = new Date() 
  now_utc = new Date(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate(),  now.getUTCHours(), now.getUTCMinutes(), now.getUTCSeconds())
  $('.time').humaneDates(now)

humanize_time_timeout = window.setInterval(window.humanize_time,30000)
