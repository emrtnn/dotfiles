// LibreWolf prefs needed by the Caelus theme.
// Goes in the profile folder, next to chrome/ (see ~/dotfiles/README.md).

// Load chrome/userChrome.css and chrome/userContent.css.
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
// Browser Toolbox (Ctrl+Shift+Alt+I) off: while open it runs a debugging
// server on localhost. Set both to true to inspect or live-edit the UI CSS.
// Kept as false rather than removed: removing a pref from user.js leaves
// its last value in prefs.js, so false is what turns it off everywhere.
user_pref("devtools.chrome.enabled", false);
user_pref("devtools.debugger.remote-enabled", false);
