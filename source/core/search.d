module core.search;

import core.utils : parseDdgSuggestions;
import std.net.curl : get;
import std.uri : encode;
import std.string;

struct Suggestion
{
    string iconName;
    string title;
    string uri;
}

interface SearchProvider
{
    Suggestion[] fetchSuggestions(string query);
}

class DuckDuckGoProvider : SearchProvider
{
    Suggestion[] fetchSuggestions(string query)
    {
        string url = "https://duckduckgo.com/ac/?q=" ~ encode(query) ~ "&type=list";
        string response = cast(string) get(url);
        string[] raw = parseDdgSuggestions(response);
        Suggestion[] res;
        foreach (r; raw)
            res ~= Suggestion("edit-find-symbolic", r, null);
        return res;
    }
}

class CompositeSearchProvider : SearchProvider
{
    DuckDuckGoProvider ddg;

    this()
    {
        ddg = new DuckDuckGoProvider();
    }

    Suggestion[] fetchSuggestions(string query)
    {
        import storage.bookmarks : loadBookmarks;
        import storage.history : loadHistory;

        Suggestion[] results;
        string lowerQuery = query.toLower();

        auto bms = loadBookmarks();
        foreach (bm; bms)
        {
            if (bm.title.toLower().indexOf(lowerQuery) != -1 || bm.uri.toLower()
                .indexOf(lowerQuery) != -1)
            {
                results ~= Suggestion("starred-symbolic", bm.title, bm.uri);
                if (results.length >= 3)
                    break;
            }
        }

        auto hist = loadHistory();
        int hCount = 0;
        foreach (h; hist)
        {
            if (h.title.toLower().indexOf(lowerQuery) != -1 || h.uri.toLower()
                .indexOf(lowerQuery) != -1)
            {
                results ~= Suggestion("document-open-recent-symbolic", h.title, h.uri);
                hCount++;
                if (hCount >= 3)
                    break;
            }
        }

        auto remote = ddg.fetchSuggestions(query);
        foreach (r; remote)
        {
            results ~= r;
            if (results.length >= 10)
                break;
        }

        return results;
    }
}
