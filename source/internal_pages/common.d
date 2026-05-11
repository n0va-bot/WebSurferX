module internal_pages.common;

string pageCSS()
{
    return "* { margin:0; padding:0; box-sizing:border-box; }\n"
        ~ "body { min-height:100vh; display:flex; flex-direction:column; align-items:center;"
        ~ " background:#1a1a1a; font-family:monospace; color:#e0e0e0; padding:40px 20px; }\n"
        ~ "a { color:#888; text-decoration:none; }\n"
        ~ "a:hover { color:#e0e0e0; }\n"
        ~ ".page { width:100%; max-width:700px; }\n"
        ~ ".page-header { display:flex; align-items:center; margin-bottom:20px; }\n"
        ~ ".page-header h1 { font-size:20px; font-weight:normal; letter-spacing:2px; flex:1; }\n"
        ~ ".section { border:1px solid #333; background:#222; padding:15px; margin-bottom:12px; }\n"
        ~ ".section h3 { font-size:14px; color:#aaa; margin-bottom:8px; }\n"
        ~ ".section p.desc { font-size:12px; color:#666; margin-bottom:10px; }\n"
        ~ ".row { display:flex; align-items:center; gap:12px; padding:10px; border:1px solid #333;"
        ~ " background:#222; margin-bottom:4px; }\n"
        ~ ".row-info { flex:1; min-width:0; overflow:hidden; }\n"
        ~ ".row-title { font-size:13px; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }\n"
        ~ ".row-sub { font-size:11px; color:#888; white-space:nowrap; overflow:hidden; text-overflow:ellipsis; }\n"
        ~ ".row-meta { font-size:11px; color:#666; flex-shrink:0; text-align:right; }\n"
        ~ ".btn { padding:6px 14px; font-size:12px; font-family:monospace;"
        ~ " border:1px solid #333; background:#222; color:#e0e0e0; cursor:pointer; }\n"
        ~ ".btn:hover { background:#333; }\n"
        ~ ".btn-danger { border-color:#ff4444; color:#ff4444; }\n"
        ~ ".btn-danger:hover { background:rgba(255,68,68,0.1); }\n"
        ~ ".btn-accent { border-color:#00A4DC; color:#00A4DC; }\n"
        ~ ".btn-accent:hover { background:rgba(0,164,220,0.15); }\n"
        ~ ".empty { padding:20px; text-align:center; color:#555; font-size:13px; }\n"
        ~ "input[type=text] { width:100%; padding:8px; background:#0a0a0a; border:1px solid #333;"
        ~ " color:#e0e0e0; font-family:monospace; font-size:13px; outline:none; margin-bottom:8px; }\n"
        ~ "input[type=text]:focus { border-color:#00A4DC; }\n"
        ~ "ul { list-style:none; }\n"
        ~ ".toggle-row { display:flex; align-items:center; justify-content:space-between; padding:10px 0; }\n"
        ~ ".toggle-row .label { flex:1; }\n"
        ~ ".toggle-row .label .title { font-size:13px; }\n"
        ~ ".toggle-row .label .desc { font-size:11px; color:#666; margin-top:2px; }\n"
        ~ ".switch { position:relative; width:40px; height:20px; flex-shrink:0; }\n"
        ~ ".switch input { opacity:0; width:0; height:0; }\n"
        ~ ".slider { position:absolute; cursor:pointer; inset:0; background:#333;"
        ~ " transition:.2s; }\n"
        ~ ".slider:before { content:''; position:absolute; height:14px; width:14px;"
        ~ " left:3px; bottom:3px; background:#888; transition:.2s; }\n"
        ~ "input:checked + .slider { background:#00A4DC; }\n"
        ~ "input:checked + .slider:before { transform:translateX(20px); background:#fff; }\n"
        ~ ".action-bar { display:flex; gap:8px; margin-bottom:15px; }\n"
        ~ ".edit-overlay { display:none; position:fixed; inset:0; background:rgba(0,0,0,0.7);"
        ~ " z-index:100; justify-content:center; align-items:center; }\n"
        ~ ".edit-overlay.visible { display:flex; }\n"
        ~ ".edit-box { background:#111; border:1px solid #333; padding:20px; width:400px; max-width:90%; }\n"
        ~ ".edit-box h3 { color:#00A4DC; margin-bottom:15px; font-size:14px; }\n"
        ~ ".edit-box .btn { margin-top:10px; margin-right:6px; }\n";
}

string getCommonHtmlStart(string title)
{
    return "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n<title>" ~ title
        ~ "</title>\n<style>\n" ~ pageCSS()
        ~ "</style>\n</head>\n<body>\n"
        ~ "<div class=\"page\">\n"
        ~ "<div class=\"page-header\"><h1>" ~ title ~ "</h1></div>\n";
}

string getCommonHtmlEnd()
{
    return "</div>\n</body>\n</html>";
}

string bridgeScript()
{
    return "<script>function bridge(obj){window.webkit.messageHandlers.websurferBridge.postMessage(JSON.stringify(obj));}</script>\n";
}

string escapeHtml(string s)
{
    import std.array : replace;

    if (s is null)
        return "";
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
        .replace("\"", "&quot;");
}

string escapeJs(string s)
{
    import std.array : replace;

    if (s is null)
        return "";
    return s.replace("\\", "\\\\").replace("'", "\\'").replace("\"", "\\\"");
}

string formatTimestamp(string ts)
{
    if (ts.length < 10)
        return ts;
    return ts[0 .. 10];
}

string formatSize(ulong bytes)
{
    import std.format : format;

    if (bytes < 1024)
        return format("%d B", bytes);
    if (bytes < 1024 * 1024)
        return format("%.1f KB", cast(double) bytes / 1024.0);
    if (bytes < 1024 * 1024 * 1024)
        return format("%.1f MB", cast(double) bytes / (1024.0 * 1024.0));
    return format("%.2f GB", cast(double) bytes / (1024.0 * 1024.0 * 1024.0));
}
