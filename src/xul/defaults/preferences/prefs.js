pref("toolkit.defaultChromeURI", "chrome://crow/content/main.xul");

// Allow dump() calls to work.
pref("browser.dom.window.dump.enabled", true);

// Enable JS strict mode.
pref("javascript.options.strict", true);
 
pref("nglayout.debug.disable_xul_cache", true);
pref("javascript.options.showInConsole", true);
pref("extensions.logging.enabled", true);
pref("nglayout.debug.disable_xul_fastload", true);
pref("dom.report_all_js_exceptions", true);
pref("browser.xul.error_pages.enabled", true);
// from http://hg.mozilla.org/mozilla-central/file/1dd81c324ac7/build/automation.py.in#l372 got this from https://github.com/mozilla/addon-sdk/commit/d916a4ce92168d16d36c193b61b7a4ddc2678ae1
pref("extensions.enabledScopes", 5);
pref("extensions.getAddons.cache.enabled", false);
pref("extensions.installDistroAddons", false);
pref("extensions.testpilot.runStudies", false);
pref("dom.storage.enabled",true);

// crap from http://hg.mozilla.org/mozilla-central/file/1dd81c324ac7/build/automation.py.in#l372
pref("dom.allow_scripts_to_close_windows", false)
//prevents slow script window
pref("dom.max_script_run_time", 0);
// we dont need this
pref('urlclassifier.updateinterval' , 172800);
pref("app.update.enabled", false);
pref("dom.w3c_touch_events.enabled", true);
pref("extensions.blocklist.url", "chrome://crow/content/blocklist.xml");

