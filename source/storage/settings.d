module storage.settings;

import std.file;
import std.json;
import std.path;
import storage.paths;

bool forceDarkMode = false;
bool enableAdblock = true;

string settingsPath()
{
    return buildPath(dataDir(), "settings.json");
}

void loadSettings()
{
    string path = settingsPath();
    if (!exists(path))
        return;

    try
    {
        string data = readText(path);
        auto json = parseJSON(data);
        if ("forceDarkMode" in json)
            forceDarkMode = json["forceDarkMode"].boolean;
        if ("enableAdblock" in json)
            enableAdblock = json["enableAdblock"].boolean;
    }
    catch (Exception e)
    {
    }
}

void saveSettings()
{
    try
    {
        JSONValue obj = JSONValue(string[string].init);
        obj["forceDarkMode"] = JSONValue(forceDarkMode);
        obj["enableAdblock"] = JSONValue(enableAdblock);
        std.file.write(settingsPath(), obj.toPrettyString());
    }
    catch (Exception e)
    {
    }
}
