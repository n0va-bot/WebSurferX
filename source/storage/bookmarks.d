module storage.bookmarks;

import std.file;
import std.json;
import storage.paths;
import core.thread : Thread;

struct Bookmark
{
    string title;
    string uri;
}

private Bookmark[] cachedBookmarks;
private bool bookmarksLoaded = false;

Bookmark[] loadBookmarks()
{
    if (bookmarksLoaded)
        return cachedBookmarks;

    string path = bookmarksPath();
    if (!exists(path))
    {
        bookmarksLoaded = true;
        return [];
    }

    try
    {
        string data = readText(path);
        auto json = parseJSON(data);
        Bookmark[] result;
        foreach (item; json.array)
        {
            result ~= Bookmark(
                item["title"].str,
                item["uri"].str
            );
        }
        cachedBookmarks = result;
        bookmarksLoaded = true;
        return result;
    }
    catch (Exception e)
    {
        bookmarksLoaded = true;
        return [];
    }
}

private void saveBookmarksAsync(Bookmark[] bookmarks)
{
    Bookmark[] bookmarksCopy = bookmarks.dup;

    new Thread({
        try
        {
            JSONValue[] arr;
            foreach (b; bookmarksCopy)
            {
                JSONValue obj = JSONValue(string[string].init);
                obj["title"] = b.title;
                obj["uri"] = b.uri;
                arr ~= obj;
            }
            string json = JSONValue(arr).toPrettyString();
            std.file.write(bookmarksPath(), json);
        }
        catch (Exception e)
        {
        }
    }).start();
}

void addBookmark(string title, string uri)
{
    auto bookmarks = loadBookmarks();
    foreach (b; bookmarks)
    {
        if (b.uri == uri)
            return;
    }
    bookmarks ~= Bookmark(title, uri);
    cachedBookmarks = bookmarks;
    saveBookmarksAsync(bookmarks);
}

void editBookmark(string uri, string newTitle)
{
    auto bookmarks = loadBookmarks();
    foreach (ref b; bookmarks)
    {
        if (b.uri == uri)
        {
            b.title = newTitle;
            break;
        }
    }
    cachedBookmarks = bookmarks;
    saveBookmarksAsync(bookmarks);
}

void removeBookmark(string uri)
{
    auto bookmarks = loadBookmarks();
    Bookmark[] filtered;
    foreach (b; bookmarks)
    {
        if (b.uri != uri)
            filtered ~= b;
    }
    cachedBookmarks = filtered;
    saveBookmarksAsync(filtered);
}
