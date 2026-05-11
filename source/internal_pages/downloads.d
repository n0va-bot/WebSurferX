module internal_pages.downloads;

import internal_pages.common;

string generateDownloadsPage()
{
    string html = getCommonHtmlStart("Downloads");

    html ~= "<div class=\"action-bar\">"
        ~ "<button class=\"btn btn-accent\" onclick=\"bridge({action:'openDownloads'})\">Open Folder</button>"
        ~ "</div>";

    html ~= "<div class=\"section\">"
        ~ "<h3>Active Downloads</h3>"
        ~ "<div id=\"activeDownloads\"><p class=\"empty\">Loading...</p></div>"
        ~ "</div>";

    import std.file : dirEntries, SpanMode, DirEntry, exists;
    import std.path : expandTilde, baseName;
    import std.algorithm : sort;
    import std.datetime.systime : SysTime;
    import std.array : array;

    string dlPath = expandTilde("~/Downloads");

    if (!exists(dlPath))
    {
        html ~= "<div class=\"section\"><p class=\"empty\">~/Downloads folder does not exist.</p></div>";
    }
    else
    {
        try
        {
            DirEntry[] files;
            foreach (DirEntry e; dirEntries(dlPath, SpanMode.shallow))
            {
                if (e.isFile)
                    files ~= e;
            }

            files.sort!((a, b) => a.timeLastModified > b.timeLastModified);

            if (files.length == 0)
            {
                html ~= "<div class=\"section\"><p class=\"empty\">Downloads folder is empty.</p></div>";
            }
            else
            {
                foreach (i, f; files)
                {
                    if (i >= 50)
                        break;
                    string name = baseName(f.name);
                    string sizeStr = formatSize(f.size);
                    string timeStr = formatTimestamp(f.timeLastModified.toISOExtString());

                    html ~= "<div class=\"row\">"
                        ~ "<div class=\"row-info\">"
                        ~ "<div class=\"row-title\">" ~ escapeHtml(
                            name) ~ "</div>"
                        ~ "<div class=\"row-sub\">" ~ sizeStr ~ "</div>"
                        ~ "</div>"
                        ~ "<div class=\"row-meta\">" ~ timeStr ~ "</div>"
                        ~ "<button class=\"btn btn-accent\" onclick=\"bridge({action:'openFile',path:'" ~ escapeJs(
                            f.name) ~ "'})\">Open</button>"
                        ~ "</div>";
                }
            }
        }
        catch (Exception e)
        {
            html ~= "<div class=\"section\"><p class=\"empty\">Failed to read downloads folder.</p></div>";
        }
    }

    html ~= "<script>\n"
        ~ "window._renderActiveDownloads = function(dl) {\n"
        ~ "  var c = document.getElementById('activeDownloads'); c.innerHTML = '';\n"
        ~ "  if (!dl || !dl.length) { c.innerHTML = '<p class=\"empty\">No active downloads.</p>'; return; }\n"
        ~ "  dl.forEach(function(d) {\n"
        ~ "    var pct = Math.round((d.progress || 0) * 100);\n"
        ~ "    var div = document.createElement('div'); div.className = 'row';\n"
        ~ "    div.innerHTML = '<div class=\"row-info\">' + '<div class=\"row-title\">' + (d.filename||'Unknown') + '</div>'"
        ~ "      + '<div class=\"row-sub\">' + (d.url||'') + '</div></div>'"
        ~ "      + '<div class=\"row-meta\">' + pct + '%</div>';\n"
        ~ "    c.appendChild(div);\n"
        ~ "  });\n"
        ~ "};\n"
        ~ "setTimeout(function() { bridge({action:'getActiveDownloads'}); }, 100);\n"
        ~ "</script>\n";

    html ~= bridgeScript() ~ getCommonHtmlEnd();
    return html;
}
