module internal_pages.history;

import internal_pages.common;

string generateHistoryPage()
{
    import storage.history;

    string html = getCommonHtmlStart("History");

    html ~= "<div class=\"action-bar\">"
        ~ "<button class=\"btn btn-danger\" onclick=\"bridge({action:'clearHistory'})\">Clear All</button>"
        ~ "</div>";

    auto hist = loadHistory();
    if (hist.length == 0)
    {
        html ~= "<div class=\"section\"><p class=\"empty\">No history yet.</p></div>";
    }
    else
    {
        foreach (item; hist)
        {
            html ~= "<div class=\"row\">"
                ~ "<div class=\"row-info\">"
                ~ "<div class=\"row-title\">" ~ escapeHtml(
                    item.title) ~ "</div>"
                ~ "<div class=\"row-sub\">" ~ escapeHtml(
                    item.uri) ~ "</div>"
                ~ "</div>"
                ~ "<div class=\"row-meta\">" ~ formatTimestamp(
                    item.timestamp) ~ "</div>"
                ~ "<a href=\"" ~ escapeHtml(
                    item.uri) ~ "\" class=\"btn btn-accent\">Open</a>"
                ~ "<button class=\"btn btn-danger\" onclick=\"bridge({action:'deleteHistory',uri:'" ~ escapeJs(
                    item.uri) ~ "'})\">✕</button>"
                ~ "</div>";
        }
    }

    html ~= bridgeScript() ~ getCommonHtmlEnd();
    return html;
}
