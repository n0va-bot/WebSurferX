module ui.window;

import std.algorithm : countUntil, remove;
import std.string;
import std.conv;

import gtk.application;
import gtk.application_window;
import gtk.notebook;
import gtk.widget;
import gtk.box;
import gtk.overlay;
import gtk.label;
import gtk.revealer;
import gtk.event_controller_key;
import gtk.types;
import gdk.types;
import glib.error : ErrorWrap;

import webkit.web_view;

import ui.tab;
import ui.toolbar;
import ui.menu;
import ui.suggestions;
import ui.findbar;
import ui.downloads;

import core.config;
import core.keybinds;
import storage.history;

class BrowserWindow : ApplicationWindow
{
    Notebook notebook;
    BrowserTab[] tabs;

    Toolbar toolbar;
    MenuPopover menuPopover;
    SuggestionsPopover suggestionsPopover;
    FindBar findBar;

    Label statusLabel;
    Label toastLabel;
    Revealer toastRevealer;
    Overlay contentOverlay;

    int activeDownloads = 0;
    bool pendingDownloadsMenuSwitch = false;
    bool[string] downloadedUrls;

    this(Application app)
    {
        super(app);
        setTitle("WebSurferY");
        setDefaultSize(core.config.winSize[0], core.config.winSize[1]);

        Box mainBox = new Box(Orientation.Vertical, 0);
        setChild(mainBox);

        toolbar = new Toolbar(this);
        mainBox.append(toolbar);

        findBar = new FindBar(this);
        mainBox.append(findBar);

        contentOverlay = new Overlay();
        contentOverlay.setVexpand(true);

        notebook = new Notebook();
        notebook.setShowTabs(false);
        notebook.setShowBorder(false);
        notebook.connectSwitchPage(&onSwitchPage);
        contentOverlay.setChild(notebook);

        toastRevealer = new Revealer();
        toastRevealer.setTransitionType(RevealerTransitionType.SlideDown);
        toastRevealer.setHalign(Align.Center);
        toastRevealer.setValign(Align.Start);
        toastRevealer.setMarginTop(8);

        Box toastBox = new Box(Orientation.Horizontal, 6);
        toastBox.addCssClass("app-notification");

        toastLabel = new Label("");
        toastLabel.setMarginStart(12);
        toastLabel.setMarginEnd(12);
        toastLabel.setMarginTop(8);
        toastLabel.setMarginBottom(8);
        import pango.types : PangoEllipsizeMode = EllipsizeMode;

        toastLabel.setEllipsize(PangoEllipsizeMode.End);
        toastLabel.setMaxWidthChars(40);

        import gtk.frame;

        Frame toastFrame = new Frame(null);
        toastBox.append(toastLabel);
        toastFrame.setChild(toastBox);
        toastRevealer.setChild(toastFrame);

        contentOverlay.addOverlay(toastRevealer);

        statusLabel = new Label("");
        statusLabel.setHalign(Align.Start);
        statusLabel.setValign(Align.End);
        statusLabel.setMarginStart(6);
        statusLabel.setMarginBottom(4);
        statusLabel.setVisible(false);
        statusLabel.addCssClass("status-label");
        contentOverlay.addOverlay(statusLabel);

        mainBox.append(contentOverlay);

        menuPopover = new MenuPopover(this);
        toolbar.menuBtn.setPopover(menuPopover.popover);

        suggestionsPopover = new SuggestionsPopover(this, toolbar.urlEntry);

        import webkit.network_session : NetworkSession;
        import webkit.download : Download;

        NetworkSession.getDefault()
            .connectDownloadStarted(delegate void(Download d, NetworkSession session) {

                d.connectDecideDestination(delegate bool(string suggestedFilename, Download d_decide) {
                    import ui.downloads : getDefaultDownloadDir;
                    import std.path : buildPath;

                    string safeFilename = (suggestedFilename !is null && suggestedFilename.length > 0)
                    ? suggestedFilename : "download";
                    string dest = buildPath(getDefaultDownloadDir(), safeFilename);
                    d_decide.setDestination(dest);

                    menuPopover.downloadsPage.addDownload(d_decide);

                    auto dreq = d_decide.getRequest();
                    if (dreq && dreq.getUri())
                        downloadedUrls[dreq.getUri()] = true;

                    toastLabel.setLabel("Downloading " ~ safeFilename ~ "...");
                    toastRevealer.setRevealChild(true);

                    activeDownloads++;
                    pendingDownloadsMenuSwitch = true;
                    toolbar.setDownloadProgressVisible(true);

                    import glib.global : timeoutAdd;

                    timeoutAdd(0, 3000, delegate bool() {
                        toastRevealer.setRevealChild(false);
                        return false;
                    });

                    return true;
                });

                d.connectReceivedData(delegate void(ulong dataLength, Download d_recv) {
                    toolbar.setDownloadProgress(d_recv.getEstimatedProgress());
                });

                void onDownloadDone(Download done_d)
                {
                    activeDownloads--;
                    if (activeDownloads <= 0)
                    {
                        activeDownloads = 0;
                        toolbar.setDownloadProgressVisible(false);
                    }
                }

                d.connectFinished(delegate void(Download d_finished) {
                    onDownloadDone(d_finished);
                });
                d.connectFailed(delegate void(ErrorWrap e, Download d_failed) {
                    onDownloadDone(d_failed);
                });
            });

        applyCss();

        auto keyController = new EventControllerKey();
        keyController.connectKeyPressed(&onKeyPressed);
        addController(keyController);

        connectCloseRequest(&onWindowCloseRequest);
    }

    bool onWindowCloseRequest(ApplicationWindow w)
    {
        import storage.session : saveSession;

        string[] uris;
        foreach (tab; tabs)
        {
            string uri = tab.view.getUri();
            if (uri !is null && uri != "about:blank" && uri.length > 0)
            {
                if (uri.length >= 14 && uri[0 .. 14] == "data:text/html")
                    continue;
                if (uri.length >= 10 && uri[0 .. 10] == "websurfer:")
                    continue;
                if (uri in downloadedUrls)
                    continue;
                uris ~= uri;
            }
        }
        saveSession(uris);
        return false;
    }

    void applyCss()
    {
        import gtk.css_provider;
        import gtk.style_context;
        import gdk.display;

        auto cssProvider = new CssProvider();
        cssProvider.loadFromString(
            ".status-label {"
                ~ "  background-color: rgba(30, 30, 30, 0.92);"
                ~ "  color: #e0e0e0;"
                ~ "  padding: 3px 10px;"
                ~ "  border-radius: 4px 4px 0 0;"
                ~ "  font-size: 12px;"
                ~ "}"
                ~ "progressbar.success trough progress {"
                ~ "  background-color: #2ec27e;"
                ~ "}"
                ~ "progressbar.error trough progress {"
                ~ "  background-color: #e01b24;"
                ~ "}"
        );
        auto display = Display.getDefault();
        if (display)
            StyleContext.addProviderForDisplay(display, cssProvider, 800);
    }

    void showStatus(string text)
    {
        if (text.length > 100)
            text = text[0 .. 100] ~ "...";
        statusLabel.setLabel(text);
        statusLabel.setVisible(true);
    }

    void hideStatus()
    {
        statusLabel.setVisible(false);
    }

    void navigateOrSearch(string input)
    {
        if (input.length == 0)
            return;

        import core.utils : looksLikeUrl;

        string uri;
        if (looksLikeUrl(input))
        {
            if (input.indexOf("://") == -1 && input.indexOf("about:") == -1)
                uri = "https://" ~ input;
            else
                uri = input;
        }
        else
        {
            import std.uri : encode;

            uri = "https://duckduckgo.com/?q=" ~ encode(input);
        }

        auto tab = getActiveTab();
        if (tab)
            tab.loadUri(uri);
    }

    void updateUrl()
    {
        auto tab = getActiveTab();
        if (tab && toolbar.urlEntry)
        {
            string uri = tab.view.getUri();
            if (uri is null || uri == "about:blank" || uri == "websurfer:start"
                || (uri.length >= 14 && uri[0 .. 14] == "data:text/html")
                || tab.isStartPage)
                toolbar.urlEntry.setText("");
            else
                toolbar.urlEntry.setText(uri);
        }
    }

    void applyDarkModeSetting()
    {
        foreach (tab; tabs)
        {
            tab.applyDarkModeSetting();
        }
    }

    void applyAdblockSetting()
    {
        foreach (tab; tabs)
        {
            tab.applyAdblockSetting();
        }
    }

    BrowserTab newTab(string uri = "websurfer:start", WebView relatedView = null)
    {
        auto tab = new BrowserTab(uri, relatedView);
        tab.onStatusRequested = &showStatus;
        tab.onHideStatusRequested = &hideStatus;
        tab.onTitleChangedEvent = &updateTitle;
        tab.onHistoryRecordRequested = &recordHistory;
        tab.onNewTabRequested = (string u, WebView v) { return newTab(u, v); };
        tab.onCloseRequested = () { closeTab(tab); };

        tabs ~= tab;
        notebook.appendPage(tab.view, tab.tabLabel);
        notebook.setCurrentPage(cast(int) tabs.length - 1);
        return tab;
    }

    BrowserTab openOrSwitchToTab(string uri)
    {
        if (uri.length >= 10 && uri[0 .. 10] == "websurfer:")
        {
            for (int i = 0; i < tabs.length; i++)
            {
                if (tabs[i].view.getUri() == uri)
                {
                    notebook.setCurrentPage(i);
                    return tabs[i];
                }
            }
        }
        return newTab(uri);
    }

    void closeTab(BrowserTab tab)
    {
        int idx = cast(int) tabs.countUntil(tab);
        if (idx >= 0)
        {
            notebook.removePage(idx);
            tabs = tabs.remove(idx);
        }
        if (tabs.length == 0)
        {
            close();
        }
    }

    void updateTitle()
    {
        int idx = notebook.getCurrentPage();
        if (idx >= 0 && idx < tabs.length)
        {
            setTitle(tabs[idx].tabLabel.getLabel());
            updateUrl();
        }
    }

    void onSwitchPage(Widget page, uint pageNum, Notebook nb)
    {
        updateTitle();
    }

    BrowserTab getActiveTab()
    {
        int idx = notebook.getCurrentPage();
        if (idx >= 0 && idx < tabs.length)
            return tabs[idx];
        return null;
    }

    void recordHistory()
    {
        auto tab = getActiveTab();
        if (tab)
        {
            string uri = tab.view.getUri();
            string title = tab.view.getTitle();
            storage.history.addHistory(title !is null ? title : "", uri !is null ? uri : "");
        }
    }

    bool onKeyPressed(uint keyval, uint keycode, ModifierType state, EventControllerKey controller)
    {
        auto cleanState = state & (core.keybinds.MODKEY | ModifierType.ShiftMask);

        foreach (kb; core.keybinds.keys)
        {
            if (kb.keyval == keyval && kb.mod == cleanState)
            {
                handleAction(kb.action, kb.intArg, kb.floatArg, kb.strArg);
                return true;
            }
        }
        return false;
    }

    void handleAction(core.keybinds.Action action, int intArg, float floatArg, string strArg)
    {
        auto tab = getActiveTab();

        final switch (action)
        {
        case core.keybinds.Action.Go:
            toolbar.urlEntry.grabFocus();
            break;
        case core.keybinds.Action.Find:
            findBar.open();
            break;
        case core.keybinds.Action.Stop:
            if (tab)
                tab.view.stopLoading();
            break;
        case core.keybinds.Action.Reload:
            if (tab)
                tab.view.reload();
            break;
        case core.keybinds.Action.ReloadBypassCache:
            if (tab)
                tab.view.reloadBypassCache();
            break;
        case core.keybinds.Action.NavigateForward:
            if (tab)
                tab.view.goForward();
            break;
        case core.keybinds.Action.NavigateBack:
            if (tab)
                tab.view.goBack();
            break;
        case core.keybinds.Action.ScrollV:
            break;
        case core.keybinds.Action.ScrollH:
            break;
        case core.keybinds.Action.ZoomIn:
            if (tab)
                tab.view.setZoomLevel(tab.view.getZoomLevel() + 0.1);
            break;
        case core.keybinds.Action.ZoomOut:
            if (tab)
                tab.view.setZoomLevel(tab.view.getZoomLevel() - 0.1);
            break;
        case core.keybinds.Action.ZoomReset:
            if (tab)
                tab.view.setZoomLevel(1.0);
            break;
        case core.keybinds.Action.ClipboardCopy:
            break;
        case core.keybinds.Action.ClipboardPaste:
            break;
        case core.keybinds.Action.FindNext:
            findBar.onNextClicked(null);
            break;
        case core.keybinds.Action.FindPrev:
            findBar.onPrevClicked(null);
            break;
        case core.keybinds.Action.Print:
            if (tab)
                tab.view.executeEditingCommand("Print");
            break;
        case core.keybinds.Action.ShowCert:
            break;
        case core.keybinds.Action.ToggleCookiePolicy:
            break;
        case core.keybinds.Action.ToggleFullscreen:
            if (isFullscreen())
                unfullscreen();
            else
                fullscreen();
            break;
        case core.keybinds.Action.ToggleInspector:
            if (tab)
                tab.view.getInspector().show();
            break;
        case core.keybinds.Action.ToggleCaretBrowsing:
            break;
        case core.keybinds.Action.ToggleGeolocation:
            break;
        case core.keybinds.Action.ToggleJavaScript:
            break;
        case core.keybinds.Action.ToggleLoadImages:
            break;
        case core.keybinds.Action.ToggleScrollBars:
            break;
        case core.keybinds.Action.ToggleStrictTLS:
            break;
        case core.keybinds.Action.ToggleStyle:
            break;
        case core.keybinds.Action.ToggleDarkMode:
            break;
        case core.keybinds.Action.NewTab:
            newTab();
            break;
        case core.keybinds.Action.CloseTab:
            if (tab)
                closeTab(tab);
            break;
        case core.keybinds.Action.NextTab:
            int idx = notebook.getCurrentPage();
            if (idx + 1 < tabs.length)
                notebook.setCurrentPage(idx + 1);
            else if (tabs.length > 0)
                notebook.setCurrentPage(0);
            break;
        case core.keybinds.Action.PrevTab:
            int idx = notebook.getCurrentPage();
            if (idx - 1 >= 0)
                notebook.setCurrentPage(idx - 1);
            else if (tabs.length > 0)
                notebook.setCurrentPage(cast(int) tabs.length - 1);
            break;
        }
    }
}
