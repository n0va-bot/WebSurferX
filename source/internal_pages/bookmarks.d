module internal_pages.bookmarks;

import internal_pages.common;
import std.conv : to;

string generateBookmarksPage()
{
    import storage.bookmarks;

    string html = getCommonHtmlStart("Bookmarks");

    auto bms = loadBookmarks();
    if (bms.length == 0)
    {
        html ~= "<div class=\"section\"><p class=\"empty\">No bookmarks yet.</p></div>";
    }
    else
    {
        foreach (i, item; bms)
        {
            string idx = to!string(i);
            html ~= "<div class=\"row\" id=\"bm-" ~ idx ~ "\">"
                ~ "<div class=\"row-info\">"
                ~ "<div class=\"row-title\">" ~ escapeHtml(
                    item.title) ~ "</div>"
                ~ "<div class=\"row-sub\">" ~ escapeHtml(
                    item.uri) ~ "</div>"
                ~ "</div>"
                ~ "<a href=\"" ~ escapeHtml(
                    item.uri) ~ "\" class=\"btn btn-accent\">Open</a>"
                ~ "<button class=\"btn\" onclick=\"openEdit('" ~ escapeJs(
                    item.uri) ~ "','" ~ escapeJs(item.title) ~ "')\">Edit</button>"
                ~ "<button class=\"btn btn-danger\" onclick=\"bridge({action:'deleteBookmark',uri:'" ~ escapeJs(
                    item.uri) ~ "'})\">✕</button>"
                ~ "</div>";
        }
    }

    html ~= "<div class=\"edit-overlay\" id=\"editOverlay\">"
        ~ "<div class=\"edit-box\">"
        ~ "<h3>Edit Bookmark</h3>"
        ~ "<input type=\"text\" id=\"editTitle\" placeholder=\"Title\">"
        ~ "<input type=\"text\" id=\"editUrl\" placeholder=\"URL\" readonly>"
        ~ "<button class=\"btn btn-accent\" onclick=\"saveEdit()\">Save</button>"
        ~ "<button class=\"btn\" onclick=\"closeEdit()\">Cancel</button>"
        ~ "</div></div>";

    html ~= "<script>\n"
        ~ "function bridge(obj){window.webkit.messageHandlers.websurferBridge.postMessage(JSON.stringify(obj));}\n"
        ~ "var editUri='';\n"
        ~ "function openEdit(uri,title){editUri=uri;document.getElementById('editTitle').value=title;"
        ~ "document.getElementById('editUrl').value=uri;document.getElementById('editOverlay').classList.add('visible');}\n"
        ~ "function closeEdit(){document.getElementById('editOverlay').classList.remove('visible');}\n"
        ~ "function saveEdit(){var t=document.getElementById('editTitle').value;"
        ~ "bridge({action:'editBookmark',uri:editUri,newTitle:t});closeEdit();}\n"
        ~ "</script>\n";

    html ~= getCommonHtmlEnd();
    return html;
}
