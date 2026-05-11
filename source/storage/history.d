module storage.history;

import std.file;
import std.json;
import std.datetime;
import storage.paths;
import core.thread : Thread;

struct HistoryEntry
{
    string title;
    string uri;
    string timestamp;
}

private HistoryEntry[] cachedHistory;
private bool historyLoaded = false;

HistoryEntry[] loadHistory()
{
    if (historyLoaded)
        return cachedHistory;

    string path = historyPath();
    if (!exists(path))
    {
        historyLoaded = true;
        return [];
    }

    try
    {
        string data = readText(path);
        auto json = parseJSON(data);
        HistoryEntry[] result;
        foreach (item; json.array)
        {
            result ~= HistoryEntry(
                item["title"].str,
                item["uri"].str,
                item["timestamp"].str
            );
        }
        cachedHistory = result;
        historyLoaded = true;
        return result;
    }
    catch (Exception e)
    {
        historyLoaded = true;
        return [];
    }
}

private void saveHistoryAsync(HistoryEntry[] entries)
{
    HistoryEntry[] entriesCopy = entries.dup;

    new Thread({
        try
        {
            JSONValue[] arr;
            foreach (e; entriesCopy)
            {
                JSONValue obj = JSONValue(string[string].init);
                obj["title"] = e.title;
                obj["uri"] = e.uri;
                obj["timestamp"] = e.timestamp;
                arr ~= obj;
            }
            string json = JSONValue(arr).toPrettyString();
            std.file.write(historyPath(), json);
        }
        catch (Exception e)
        {
        }
    }).start();
}

void clearHistory()
{
    cachedHistory.length = 0;
    try
    {
        if (exists(historyPath()))
            std.file.remove(historyPath());
    }
    catch (Exception e)
    {
    }
}

void deleteHistoryEntry(string uri)
{
    auto entries = loadHistory();
    HistoryEntry[] filtered;
    foreach (e; entries)
    {
        if (e.uri != uri)
            filtered ~= e;
    }
    cachedHistory = filtered;
    saveHistoryAsync(filtered);
}

void addHistory(string title, string uri)
{
    if (uri is null || uri.length == 0)
        return;
    if (uri == "about:blank" || (uri.length >= 10 && uri[0 .. 10] == "websurfer:"))
        return;
    if (uri.length >= 14 && uri[0 .. 14] == "data:text/html")
        return;

    auto entries = loadHistory();
    string ts = Clock.currTime().toISOExtString();

    if (entries.length > 0 && entries[0].uri == uri)
    {
        entries[0].timestamp = ts;
        if (title.length > 0 && title != uri)
        {
            entries[0].title = title;
        }
    }
    else
    {
        entries = HistoryEntry(title, uri, ts) ~ entries;
    }

    if (entries.length > 500)
        entries = entries[0 .. 500];

    cachedHistory = entries;
    saveHistoryAsync(entries);
}
