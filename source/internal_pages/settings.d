module internal_pages.settings;

import internal_pages.common;

string generateSettingsPage()
{
    import storage.settings;

    string html = getCommonHtmlStart("Settings");

    html ~= "<div class=\"section\">"
        ~ "<div class=\"toggle-row\">"
        ~ "<div class=\"label\">"
        ~ "<div class=\"title\">Adblock (uBlock Origin)</div>"
        ~ "<div class=\"desc\">Block ads and trackers using uBO filter lists compiled to native WebKit bytecode.</div>"
        ~ "</div>"
        ~ "<label class=\"switch\"><input type=\"checkbox\" id=\"adblockToggle\"" ~ (enableAdblock ? " checked" : "") ~ " onchange=\"bridge({action:'toggleAdblock'})\">"
        ~ "<span class=\"slider\"></span></label>"
        ~ "</div></div>";

    html ~= bridgeScript() ~ getCommonHtmlEnd();
    return html;
}
