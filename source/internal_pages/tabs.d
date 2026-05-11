module internal_pages.tabs;

import internal_pages.common;

string generateTabsPage()
{
    string html = getCommonHtmlStart("Tabs");

    html ~= "<div id=\"tabList\"><div class=\"section\"><p class=\"empty\">Loading tabs...</p></div></div>";

    html ~= "<script>\n"
        ~ "function bridge(obj){window.webkit.messageHandlers.websurferBridge.postMessage(JSON.stringify(obj));}\n"
        ~ "bridge({action:'getTabList'});\n"
        ~ "window._renderTabs = function(tabs) {\n"
        ~ "  var c = document.getElementById('tabList'); c.innerHTML = '';\n"
        ~ "  if (!tabs.length) { c.innerHTML = '<div class=\"section\"><p class=\"empty\">No tabs open.</p></div>'; return; }\n"
        ~ "  tabs.forEach(function(t, i) {\n"
        ~ "    var d = document.createElement('div'); d.className = 'row';\n"
        ~ "    d.innerHTML = '<div class=\"row-info\">' + '<div class=\"row-title\">' + (t.title||'New Tab') + '</div>'"
        ~ "      + '<div class=\"row-sub\">' + (t.uri||'') + '</div></div>'"
        ~ "      + '<button class=\"btn btn-accent\" onclick=\"bridge({action:\\'switchTab\\',index:' + i + '})\">Switch</button>'"
        ~ "      + '<button class=\"btn btn-danger\" onclick=\"bridge({action:\\'closeTab\\',index:' + i + '})\">✕</button>';\n"
        ~ "    c.appendChild(d);\n"
        ~ "  });\n"
        ~ "};\n"
        ~ "</script>\n";

    html ~= getCommonHtmlEnd();
    return html;
}
