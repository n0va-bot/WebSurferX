module storage.session;

import std.file;
import std.json;
import storage.paths;

string[] loadSession()
{
    string path = sessionPath();
    if (!exists(path))
        return [];

    try
    {
        string data = readText(path);
        auto json = parseJSON(data);
        string[] uris;
        foreach (item; json.array)
        {
            if (item.type == JSONType.string)
                uris ~= item.str;
        }
        return uris;
    }
    catch (Exception e)
    {
        return [];
    }
}

void saveSession(string[] uris)
{
    try
    {
        JSONValue[] arr;
        foreach (u; uris)
        {
            arr ~= JSONValue(u);
        }
        string json = JSONValue(arr).toPrettyString();
        std.file.write(sessionPath(), json);
    }
    catch (Exception e)
    {
    }
}
