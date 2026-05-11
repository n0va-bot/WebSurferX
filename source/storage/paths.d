module storage.paths;

import std.file;
import std.path;
import std.process;

string dataDir()
{
    string home = environment.get("HOME", "/tmp");
    string dir = buildPath(home, ".config", "websurfery");
    if (!exists(dir))
        mkdirRecurse(dir);
    return dir;
}

string bookmarksPath()
{
    return buildPath(dataDir(), "bookmarks.json");
}

string historyPath()
{
    return buildPath(dataDir(), "history.json");
}

string sessionPath()
{
    return buildPath(dataDir(), "session.json");
}
