module core.utils;

import std.string;

bool looksLikeUrl(string text)
{
    if (text.indexOf("://") != -1)
        return true;
    if (text.indexOf("about:") == 0 || text.indexOf("websurfer:") == 0)
        return true;
    if (text.indexOf("localhost") != -1)
        return true;
    if (text.indexOf(" ") == -1 && text.indexOf(".") != -1)
        return true;
    return false;
}

string[] parseDdgSuggestions(string json)
{
    string[] results;
    try
    {
        auto firstBracket = json.indexOf("[");
        if (firstBracket == -1)
            return results;
        auto secondBracket = json.indexOf("[", firstBracket + 1);
        if (secondBracket == -1)
            return results;
        auto closeBracket = json.lastIndexOf("]");
        if (closeBracket <= secondBracket)
            return results;

        string inner = json[secondBracket + 1 .. closeBracket];

        bool inString = false;
        bool escaped = false;
        string current;
        foreach (ch; inner)
        {
            if (escaped)
            {
                current ~= ch;
                escaped = false;
            }
            else if (ch == '\\')
            {
                escaped = true;
            }
            else if (ch == '"')
            {
                if (inString)
                {
                    results ~= current;
                    current = "";
                    inString = false;
                }
                else
                {
                    inString = true;
                }
            }
            else if (inString)
            {
                current ~= ch;
            }
        }
    }
    catch (Exception e)
    {
    }

    if (results.length > 8)
        results = results[0 .. 8];
    return results;
}
