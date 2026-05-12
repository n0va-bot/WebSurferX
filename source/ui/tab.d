module ui.tab;

import gtk.widget;
import gtk.label;
import gdk.rgba;
import webkit.web_view;
import webkit.settings;
import webkit.urirequest;
import webkit.navigation_policy_decision;
import webkit.policy_decision;
import webkit.hit_test_result;
import webkit.navigation_action;
import webkit.context_menu;
import webkit.context_menu_item;
import webkit.types;
import gobject.param_spec;
import gobject.object;
import glib.error;
import std.json;

import ui.window;

class BrowserTab
{
    WebView view;
    Label tabLabel;
    bool isStartPage = false;

    void delegate(string) onStatusRequested;
    void delegate() onHideStatusRequested;
    void delegate() onTitleChangedEvent;
    void delegate() onHistoryRecordRequested;
    BrowserTab delegate(string, WebView) onNewTabRequested;
    void delegate() onCloseRequested;

    this(string uri, WebView relatedView = null)
    {

        if (relatedView !is null)
        {
            view = cast(WebView) WebView.builder().relatedView(relatedView).build();
        }
        else
        {
            view = new WebView();
        }
        tabLabel = new Label("New Tab");

        view.setBackgroundColor(RGBA(0, 0, 0, 0));

        view.connectNotify("title", &onTitleChanged);
        view.connectLoadChanged(&onLoadChanged);
        view.connectCreate(&onCreateView);
        view.connectDecidePolicy(&onDecidePolicy);
        view.connectClose(&onClose);
        view.connectMouseTargetChanged(&onMouseTargetChanged);
        view.connectContextMenu(&onContextMenu);
        view.connectLoadFailed(&onLoadFailed);

        setupWebsurferBridge();

        if (relatedView is null && uri.length > 0)
        {
            loadUri(uri);
        }

        applyDarkModeSetting();
        applyAdblockSetting();
    }

    void setupWebsurferBridge()
    {
        auto ucm = view.getUserContentManager();
        ucm.registerScriptMessageHandler("websurferBridge");

        import javascriptcore.value : Value;
        import webkit.user_content_manager : UserContentManager;

        ucm.connectScriptMessageReceived("websurferBridge", delegate void(Value v, UserContentManager m) {
            import std.stdio;
            import std.json;

            if (v.isString())
            {
                string jsonStr = v.toString_();
                try
                {
                    auto j = parseJSON(jsonStr);
                    if (j.type == JSONType.object && "action" in j)
                    {
                        string action = j["action"].str;
                        handleBridgeAction(action, j);
                    }
                }
                catch (Exception e)
                {
                    writeln("Bridge error: ", e.msg);
                }
            }
        });
    }

    private void handleBridgeAction(string action, std.json.JSONValue j)
    {
        import std.stdio;

        if (action == "clearHistory")
        {
            import storage.history : clearHistory;

            clearHistory();
            view.evaluateJavascript("location.reload()", null, null, null, null);
        }
        else if (action == "deleteHistory")
        {
            import storage.history : deleteHistoryEntry;

            if ("uri" in j)
            {
                deleteHistoryEntry(j["uri"].str);
                view.evaluateJavascript("location.reload()", null, null, null, null);
            }
        }
        else if (action == "deleteBookmark")
        {
            import storage.bookmarks : removeBookmark;

            if ("uri" in j)
            {
                removeBookmark(j["uri"].str);
                view.evaluateJavascript("location.reload()", null, null, null, null);
            }
        }
        else if (action == "editBookmark")
        {
            import storage.bookmarks : editBookmark;

            if ("uri" in j && "newTitle" in j)
            {
                editBookmark(j["uri"].str, j["newTitle"].str);
                view.evaluateJavascript("location.reload()", null, null, null, null);
            }
        }
        else if (action == "toggleAdblock")
        {
            import storage.settings : enableAdblock, saveSettings;

            enableAdblock = !enableAdblock;
            saveSettings();
        }
        else if (action == "toggleDarkMode")
        {
            import storage.settings : forceDarkMode, saveSettings;

            forceDarkMode = !forceDarkMode;
            saveSettings();
            import ui.window : BrowserWindow;

            auto win = cast(BrowserWindow) view.getRoot();
            if (win)
                win.applyDarkModeSetting();
        }
        else if (action == "openDownloads")
        {
            import std.process : spawnProcess;
            import std.path : expandTilde;

            try
            {
                spawnProcess(["xdg-open", expandTilde("~/Downloads")]);
            }
            catch (Exception e)
            {
            }
        }
        else if (action == "openFile")
        {
            import std.process : spawnProcess;

            if ("path" in j)
            {
                try
                {
                    spawnProcess(["xdg-open", j["path"].str]);
                }
                catch (Exception e)
                {
                }
            }
        }
        else if (action == "getTabList")
        {
            import ui.window : BrowserWindow;

            auto win = cast(BrowserWindow) view.getRoot();
            if (win)
            {
                import std.json : JSONValue;

                JSONValue[] arr;
                foreach (tab; win.tabs)
                {
                    JSONValue obj = JSONValue(string[string].init);
                    string t = tab.view.getTitle();
                    string u = tab.view.getUri();
                    obj["title"] = t !is null ? t : "New Tab";
                    obj["uri"] = u !is null ? u : "";
                    arr ~= obj;
                }
                string js = "if(window._renderTabs) window._renderTabs(" ~ JSONValue(arr)
                    .toString() ~ ");";
                view.evaluateJavascript(js, null, null, null, null);
            }
        }
        else if (action == "getActiveDownloads")
        {
            import ui.window : BrowserWindow;

            auto win = cast(BrowserWindow) view.getRoot();
            if (win && win.menuPopover && win.menuPopover.downloadsPage)
            {
                import std.json : JSONValue;

                JSONValue[] arr = win.menuPopover.downloadsPage.getDownloadsList();
                string js = "if(window._renderActiveDownloads) window._renderActiveDownloads(" ~ JSONValue(arr)
                    .toString() ~ ");";
                view.evaluateJavascript(js, null, null, null, null);
            }
        }
        else if (action == "switchTab")
        {
            import ui.window : BrowserWindow;

            auto win = cast(BrowserWindow) view.getRoot();
            if (win && "index" in j)
            {
                int idx = cast(int) j["index"].integer;
                if (idx >= 0 && idx < win.tabs.length)
                    win.notebook.setCurrentPage(idx);
            }
        }
        else if (action == "closeTab")
        {
            import ui.window : BrowserWindow;

            auto win = cast(BrowserWindow) view.getRoot();
            if (win && "index" in j)
            {
                int idx = cast(int) j["index"].integer;
                if (idx >= 0 && idx < win.tabs.length)
                {
                    win.closeTab(win.tabs[idx]);
                    view.evaluateJavascript("location.reload()", null, null, null, null);
                }
            }
        }
    }

    void applyDarkModeSetting()
    {
        import storage.settings : forceDarkMode;
        import webkit.user_style_sheet;
        import webkit.user_content_manager;
        import webkit.types;

        auto ucm = view.getUserContentManager();
        ucm.removeAllStyleSheets();

        if (forceDarkMode)
        {
            string css = "html { filter: invert(1) hue-rotate(180deg) !important; } img, video, iframe, canvas, picture"
                ~ "{ filter: invert(1) hue-rotate(180deg) !important; }";
            auto sheet = new UserStyleSheet(css, UserContentInjectedFrames.AllFrames,
                UserStyleLevel.Author, null, null);
            ucm.addStyleSheet(sheet);
        }
    }

    void applyAdblockSetting()
    {
        import storage.adblock : loadAdblockFilters, removeAdblockFilters;

        auto ucm = view.getUserContentManager();
        removeAdblockFilters(ucm);
        loadAdblockFilters(ucm);
    }

    void loadUri(string uri)
    {
        if (uri == "about:blank" || uri == "websurfer:start")
            view.loadUri("websurfer:start");
        else
            view.loadUri(uri);
    }

    void onTitleChanged(gobject.param_spec.ParamSpec pspec, gobject.object.ObjectWrap obj)
    {
        string title = view.getTitle();
        if (title.length > 0)
        {
            tabLabel.setLabel(title);
            if (onTitleChangedEvent)
                onTitleChangedEvent();
        }
    }

    void onLoadChanged(LoadEvent event, WebView v)
    {
        if (event == LoadEvent.Started)
        {
            if (onStatusRequested)
                onStatusRequested("Loading...");
        }
        else if (event == LoadEvent.Committed)
        {
            string uri = view.getUri();
            if (uri !is null && uri.length >= 14 && uri[0 .. 14] == "data:text/html")
            {
            }
            else
            {
                if (onStatusRequested)
                    onStatusRequested("Loading " ~ (uri !is null ? uri : ""));
            }
            if (onTitleChangedEvent)
                onTitleChangedEvent();
        }
        else if (event == LoadEvent.Finished)
        {
            if (onHideStatusRequested)
                onHideStatusRequested();
            if (onTitleChangedEvent)
                onTitleChangedEvent();
            if (isStartPage)
            {
                isStartPage = false;
                view.evaluateJavascript("document.getElementById('q').focus();");
            }
            else
            {
                if (onHistoryRecordRequested)
                    onHistoryRecordRequested();
            }
        }
    }

    bool onLoadFailed(LoadEvent loadEvent, string failingUri)
    {
        import std.array : replace;

        string safeUri = failingUri !is null ? failingUri : "unknown";

        import std.algorithm.searching : startsWith;

        if (safeUri.startsWith("https://accounts.firefox.com/oauth/success/a2270f727f45f648"))
            return true;

        string code;
        final switch (loadEvent)
        {
        case LoadEvent.Started:
            code = "Load Started";
            break;
        case LoadEvent.Redirected:
            code = "Redirect";
            break;
        case LoadEvent.Committed:
            code = "Committed";
            break;
        case LoadEvent.Finished:
            code = "Finished";
            break;
        }

        import internal_pages.start : generateErrorPage;

        string html = generateErrorPage("Page Load Error", "Failed to load " ~ safeUri ~ " (" ~ code ~ ")");
        view.loadHtml(html, failingUri);
        return true;
    }

    Widget onCreateView(NavigationAction action, WebView v)
    {
        if (onNewTabRequested)
        {
            auto newTab = onNewTabRequested("websurfer:start", v);
            return newTab.view;
        }
        return null;
    }

    bool onDecidePolicy(PolicyDecision decision, PolicyDecisionType type, WebView v)
    {
        import webkit.navigation_policy_decision : NavigationPolicyDecision;
        import webkit.response_policy_decision : ResponsePolicyDecision;

        if (type == PolicyDecisionType.NewWindowAction)
        {
            auto navDecision = cast(NavigationPolicyDecision) decision;
            if (navDecision)
            {
                auto req = navDecision.getNavigationAction().getRequest();
                if (req && req.getUri().length > 0 && onNewTabRequested)
                {
                    onNewTabRequested(req.getUri(), null);
                    decision.ignore();
                    return true;
                }
            }
        }
        else if (type == PolicyDecisionType.NavigationAction)
        {
            auto navDecision = cast(NavigationPolicyDecision) decision;
            if (navDecision)
            {
                auto action = navDecision.getNavigationAction();
                auto req = action.getRequest();
                if (req && req.getUri().length > 0)
                {
                    string uri = req.getUri();

                    import std.algorithm.searching : startsWith;

                    if (uri.startsWith(
                            "https://accounts.firefox.com/oauth/success/a2270f727f45f648"))
                    {
                        interceptOauthRedirect(uri);
                        decision.ignore();
                        return true;
                    }

                    if (action.getMouseButton() == 2 && onNewTabRequested)
                    {
                        onNewTabRequested(uri, null);
                        decision.ignore();
                        return true;
                    }
                }
            }
        }
        else if (type == PolicyDecisionType.Response)
        {
            auto respDecision = cast(ResponsePolicyDecision) decision;
            if (respDecision && !respDecision.isMimeTypeSupported())
            {
                decision.download();
                return true;
            }
        }
        return false;
    }

    void onClose(WebView v)
    {
        if (onCloseRequested)
            onCloseRequested();
    }

    void onMouseTargetChanged(HitTestResult hitTestResult, uint modifiers, WebView v)
    {
        if (hitTestResult.contextIsLink())
        {
            string linkUri = hitTestResult.getLinkUri();
            if (linkUri !is null && linkUri.length > 0)
            {
                if (onStatusRequested)
                    onStatusRequested(linkUri);
            }
            else
            {
                if (onHideStatusRequested)
                    onHideStatusRequested();
            }
        }
        else
        {
            if (onHideStatusRequested)
                onHideStatusRequested();
        }
    }

    bool onContextMenu(ContextMenu menu, HitTestResult hitTest, WebView v)
    {
        auto items = menu.getItems();
        int idx = 0;
        foreach (item; items)
        {
            auto action = item.getStockAction();
            if (action == ContextMenuAction.OpenLinkInNewWindow)
            {
                menu.remove(item);
                auto newItem = ContextMenuItem.newFromStockActionWithLabel(
                    ContextMenuAction.OpenLinkInNewWindow, "Open Link in New Tab");
                menu.insert(newItem, idx);
                break;
            }
            idx++;
        }
        return false;
    }

    void interceptOauthRedirect(string uri)
    {
        import std.string;
        import sync.ffi;
        import std.uri : decode;

        string code = "";
        string state = "";

        long qIdx = uri.indexOf("?");
        if (qIdx != -1)
        {
            string query = uri[qIdx + 1 .. $];
            auto pairs = query.split("&");
            foreach (pair; pairs)
            {
                long eqIdx = pair.indexOf("=");
                if (eqIdx != -1)
                {
                    string key = pair[0 .. eqIdx];
                    string value = pair[eqIdx + 1 .. $];
                    if (key == "code")
                        code = value;
                    if (key == "state")
                        state = value;
                }
            }
        }

        if (code.length > 0 && state.length > 0)
        {
            import std.string : toStringz;

            bool success = websurferx_sync_complete_login(toStringz(code), toStringz(state));
            if (success)
            {
                import sync.ffi : websurferx_sync_bookmarks, websurferx_sync_free_string;
                import std.string : fromStringz;
                import std.json : parseJSON, JSONType;

                char* result = websurferx_sync_bookmarks();
                if (result !is null)
                {
                    string jsonStr = cast(string) fromStringz(result).dup;
                    websurferx_sync_free_string(result);

                    try
                    {
                        auto j = parseJSON(jsonStr);
                        if (j.type == JSONType.array)
                        {
                            import storage.bookmarks : storeBookmarks, Bookmark;

                            Bookmark[] syncedBookmarks;
                            foreach (item; j.array)
                            {
                                if (item.type == JSONType.object)
                                {
                                    if ("title" in item && "bmkUri" in item)
                                    {
                                        syncedBookmarks ~= Bookmark(item["title"].str, item["bmkUri"].str);
                                    }
                                }
                            }
                            storeBookmarks(syncedBookmarks);
                        }
                    }
                    catch (Exception e)
                    {
                        import std.stdio : writeln;
                        writeln("Failed to store synced bookmarks: ", e.msg);
                    }
                }
            }
        }

        if (onCloseRequested)
            onCloseRequested();
    }
}
