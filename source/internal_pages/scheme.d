module internal_pages.scheme;

import webkit.web_context;
import webkit.urischeme_request;
import webkit.types;
import gio.memory_input_stream;
import glib.bytes;
import std.string;

import internal_pages.start : generateStartPage, generateErrorPage;
import internal_pages.history : generateHistoryPage;
import internal_pages.bookmarks : generateBookmarksPage;
import internal_pages.downloads : generateDownloadsPage;
import internal_pages.settings : generateSettingsPage;
import internal_pages.tabs : generateTabsPage;

void registerWebsurferScheme()
{
    auto ctx = WebContext.getDefault();
    ctx.registerUriScheme("websurfer", delegate void(URISchemeRequest req) {
        string path = req.getPath();
        string html;

        if (path == "start" || path == "/")
            html = generateStartPage();
        else if (path == "history")
            html = generateHistoryPage();
        else if (path == "downloads")
            html = generateDownloadsPage();
        else if (path == "settings")
            html = generateSettingsPage();
        else if (path == "bookmarks")
            html = generateBookmarksPage();
        else if (path == "tabs")
            html = generateTabsPage();
        else
            html = generateErrorPage("Page Not Found", "The internal page websurfer:" ~ path ~ " does not exist.");

        import glib.bytes : Bytes;

        auto b = new Bytes(cast(ubyte[]) html);
        auto stream = MemoryInputStream.newFromBytes(b);
        req.finish(stream, html.length, "text/html");
    });
}
