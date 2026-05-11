module internal_pages.start;

import internal_pages.common;

string generateStartPage()
{
    string html = "<!DOCTYPE html>\n<html>\n<head>\n<meta charset=\"utf-8\">\n<title>New Tab</title>\n<style>\n"
        ~ pageCSS()
        ~ "body { justify-content:center; }\n"
        ~ ".page { text-align:center; }\n"
        ~ ".page h1 { font-size:24px; letter-spacing:2px; margin-bottom:20px; }\n"
        ~ "form { display:flex; flex-direction:column; gap:10px; width:100%; max-width:500px;"
        ~ " margin:0 auto; position:relative; }\n"
        ~ ".suggestions { position:absolute; top:100%; left:0; right:0; background:#0a0a0a;"
        ~ " border:1px solid #333; border-top:none; display:none; z-index:10; max-height:300px; overflow-y:auto; }\n"
        ~ ".suggestions.visible { display:block; }\n"
        ~ ".suggestions div { padding:8px 12px; font-size:14px; cursor:pointer; color:#e0e0e0; font-family:monospace; }\n"
        ~ ".suggestions div:hover, .suggestions div.selected { background:#222; }\n"
        ~ "</style>\n</head>\n<body>\n<div class=\"page\">\n"
        ~ "<h1>WebSurferY</h1>\n"
        ~ "<form action=\"https://duckduckgo.com/\" method=\"get\" id=\"sf\" autocomplete=\"off\">\n"
        ~ "<input type=\"text\" name=\"q\" id=\"q\" placeholder=\"Search the web...\" autofocus>\n"
        ~ "<div class=\"suggestions\" id=\"suggestions\"></div>\n"
        ~ "</form>\n"
        ~ "<script>\n"
        ~ "var q=document.getElementById('q'),box=document.getElementById('suggestions'),debounce=null,selected=-1;\n"
        ~ "q.addEventListener('input',function(){clearTimeout(debounce);var v=q.value.trim();"
        ~ "if(v.length<2){hide();return;}debounce=setTimeout(function(){fetchSuggestions(v);},200);});\n"
        ~ "q.addEventListener('keydown',function(e){var items=box.querySelectorAll('div');"
        ~ "if(!items.length)return;if(e.key==='ArrowDown'){e.preventDefault();selected=Math.min(selected+1,items.length-1);update(items);}"
        ~ "else if(e.key==='ArrowUp'){e.preventDefault();selected=Math.max(selected-1,-1);update(items);}"
        ~ "else if(e.key==='Enter'&&selected>=0){e.preventDefault();q.value=items[selected].textContent;hide();document.getElementById('sf').submit();}});\n"
        ~ "q.addEventListener('blur',function(){setTimeout(hide,150);});\n"
        ~ "function update(items){for(var i=0;i<items.length;i++)items[i].className=(i===selected)?'selected':'';}\n"
        ~ "function hide(){box.className='suggestions';selected=-1;}\n"
        ~ "function fetchSuggestions(query){fetch('https://duckduckgo.com/ac/?q='+encodeURIComponent(query)+'&type=list')"
        ~ ".then(function(r){return r.json();}).then(function(data){if(data&&data.length>1&&Array.isArray(data[1])){show(data[1]);}else{hide();}})"
        ~ ".catch(function(){hide();});}\n"
        ~ "function show(items){box.innerHTML='';selected=-1;if(!items||!items.length){hide();return;}"
        ~ "for(var i=0;i<Math.min(items.length,8);i++){var d=document.createElement('div');d.textContent=items[i];"
        ~ "d.addEventListener('mousedown',function(e){e.preventDefault();q.value=this.textContent;hide();"
        ~ "document.getElementById('sf').submit();});box.appendChild(d);}box.className='suggestions visible';}\n"
        ~ "</script>\n</div>\n</body>\n</html>";
    return html;
}

string generateErrorPage(string title, string msg)
{
    string html = getCommonHtmlStart("Error");
    html ~= "<div class=\"section\" style=\"text-align:center;\">"
        ~ "<p style=\"font-size:64px; color:#333; letter-spacing:4px; margin-bottom:10px;\">" ~ escapeHtml(
            title) ~ "</p>"
        ~ "<p>" ~ escapeHtml(msg) ~ "</p>"
        ~ "</div>";
    html ~= getCommonHtmlEnd();
    return html;
}
