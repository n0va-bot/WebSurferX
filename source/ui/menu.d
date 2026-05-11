module ui.menu;

import std.conv;
import std.string;
import gtk.popover;
import gtk.box;
import gtk.stack;
import gtk.stack_switcher;
import gtk.separator;
import gtk.search_entry;
import gtk.scrolled_window;
import gtk.list_box;
import gtk.list_box_row;
import gtk.button;
import gtk.label;
import gtk.widget;
import gtk.types;
import pango.types : PangoEllipsizeMode = EllipsizeMode;

import ui.window;
import storage.bookmarks;
import storage.history;
import ui.downloads;

class MenuPopover
{
    Popover popover;
    BrowserWindow parentWindow;

    Stack menuStack;
    SearchEntry tabSearchEntry;
    ListBox tabList;
    SearchEntry bookmarkSearchEntry;
    ListBox bookmarkList;
    SearchEntry historySearchEntry;
    ListBox historyList;
    DownloadsPage downloadsPage;

    this(BrowserWindow parentWindow)
    {
        this.parentWindow = parentWindow;

        popover = new Popover();
        popover.setHasArrow(false);
        popover.setSizeRequest(320, 350);

        Box outerBox = new Box(Orientation.Vertical, 0);

        menuStack = new Stack();
        menuStack.setVexpand(true);

        setupTabsPage();
        setupBookmarksPage();
        setupHistoryPage();
        downloadsPage = new DownloadsPage();
        menuStack.addNamed(downloadsPage, "downloads");
        menuStack.getPage(downloadsPage).setIconName("folder-download-symbolic");
        setupSettingsPage();

        outerBox.append(menuStack);

        outerBox.append(new Separator(Orientation.Horizontal));

        auto switcher = new StackSwitcher();
        switcher.setStack(menuStack);
        switcher.setHalign(Align.Center);
        switcher.setMarginTop(4);
        switcher.setMarginBottom(4);
        outerBox.append(switcher);

        popover.setChild(outerBox);

        popover.connectMap(delegate void(Widget w) {
            if (parentWindow.pendingDownloadsMenuSwitch)
            {
                menuStack.setVisibleChildName("downloads");
                parentWindow.pendingDownloadsMenuSwitch = false;
            }
            else
            {
                menuStack.setVisibleChildName("open");
            }
            updateTabsDropdown();
            updateBookmarksDropdown();
            updateHistoryDropdown();
        });
    }

    private void setupTabsPage()
    {
        Box tabsPage = new Box(Orientation.Vertical, 4);
        tabsPage.setMarginStart(6);
        tabsPage.setMarginEnd(6);
        tabsPage.setMarginTop(6);
        tabsPage.setMarginBottom(6);

        Box headerBox = new Box(Orientation.Horizontal, 4);
        Label titleLbl = new Label("<b>Tabs</b>");
        titleLbl.setUseMarkup(true);
        titleLbl.setHexpand(true);
        titleLbl.setXalign(0);
        headerBox.append(titleLbl);

        Button linkBtn = new Button();
        linkBtn.setIconName("window-new-symbolic");
        linkBtn.connectClicked(delegate void(Button b) {
            parentWindow.openOrSwitchToTab("websurfer:tabs");
            popover.popdown();
        });
        headerBox.append(linkBtn);
        tabsPage.append(headerBox);

        tabSearchEntry = new SearchEntry();
        tabSearchEntry.setPlaceholderText("Filter tabs...");
        tabSearchEntry.connectSearchChanged(delegate void(SearchEntry e) {
            updateTabsDropdown();
        });
        tabSearchEntry.connectActivate(delegate void(SearchEntry e) {
            string query = tabSearchEntry.getText();
            if (query.length > 0)
            {
                parentWindow.navigateOrSearch(query);
                popover.popdown();
            }
        });
        tabsPage.append(tabSearchEntry);

        auto tabScroll = new ScrolledWindow();
        tabScroll.setVexpand(true);
        tabScroll.setPropagateNaturalHeight(true);
        tabScroll.setMaxContentHeight(300);
        tabList = new ListBox();
        tabList.setSelectionMode(SelectionMode.None);
        tabList.setActivateOnSingleClick(true);
        tabList.connectRowActivated(&onTabRowActivated);
        tabScroll.setChild(tabList);
        tabsPage.append(tabScroll);

        Button newTabBtn = new Button();
        newTabBtn.setLabel("+ New Tab");
        newTabBtn.connectClicked(delegate void(Button b) {
            parentWindow.newTab();
            popover.popdown();
        });
        tabsPage.append(newTabBtn);

        menuStack.addNamed(tabsPage, "open");
        menuStack.getPage(tabsPage).setIconName("view-list-symbolic");
    }

    private void setupBookmarksPage()
    {
        Box bookmarksPage = new Box(Orientation.Vertical, 4);
        bookmarksPage.setMarginStart(6);
        bookmarksPage.setMarginEnd(6);
        bookmarksPage.setMarginTop(6);
        bookmarksPage.setMarginBottom(6);

        Box headerBox = new Box(Orientation.Horizontal, 4);
        Label titleLbl = new Label("<b>Bookmarks</b>");
        titleLbl.setUseMarkup(true);
        titleLbl.setHexpand(true);
        titleLbl.setXalign(0);
        headerBox.append(titleLbl);

        Button addBookmarkBtn = new Button();
        addBookmarkBtn.setIconName("starred-symbolic");
        addBookmarkBtn.setTooltipText("Bookmark Current Page");
        addBookmarkBtn.connectClicked(delegate void(Button b) {
            auto tab = parentWindow.getActiveTab();
            if (tab)
            {
                string uri = tab.view.getUri();
                string title = tab.view.getTitle();
                if (uri !is null && uri.length > 0 && uri != "websurfer:start" && uri != "about:blank")
                {
                    storage.bookmarks.addBookmark(title !is null ? title : uri, uri);
                    parentWindow.showStatus("Bookmarked: " ~ (title !is null ? title : uri));
                    updateBookmarksDropdown();
                }
            }
        });
        headerBox.append(addBookmarkBtn);

        Button linkBtn = new Button();
        linkBtn.setIconName("window-new-symbolic");
        linkBtn.connectClicked(delegate void(Button b) {
            parentWindow.openOrSwitchToTab("websurfer:bookmarks");
            popover.popdown();
        });
        headerBox.append(linkBtn);

        Button syncBtn = new Button();
        syncBtn.setIconName("view-refresh-symbolic");
        syncBtn.setTooltipText("Sync Bookmarks");
        syncBtn.connectClicked(delegate void(Button b) { 
            import sync.ffi : websurferx_sync_is_logged_in, websurferx_sync_bookmarks;
            if (websurferx_sync_is_logged_in()) {
                websurferx_sync_bookmarks();
            } else {
                startFxaLogin(); 
            }
        });
        headerBox.append(syncBtn);

        bookmarksPage.append(headerBox);

        bookmarkSearchEntry = new SearchEntry();
        bookmarkSearchEntry.setPlaceholderText("Filter bookmarks...");
        bookmarkSearchEntry.connectSearchChanged(delegate void(SearchEntry e) {
            updateBookmarksDropdown();
        });
        bookmarksPage.append(bookmarkSearchEntry);

        auto bmScroll = new ScrolledWindow();
        bmScroll.setVexpand(true);
        bmScroll.setPropagateNaturalHeight(true);
        bmScroll.setMaxContentHeight(300);
        bookmarkList = new ListBox();
        bookmarkList.setSelectionMode(SelectionMode.None);
        bookmarkList.setActivateOnSingleClick(true);
        bookmarkList.connectRowActivated(&onBookmarkRowActivated);
        bmScroll.setChild(bookmarkList);
        bookmarksPage.append(bmScroll);

        menuStack.addNamed(bookmarksPage, "bookmarks");
        menuStack.getPage(bookmarksPage).setIconName("user-bookmarks-symbolic");
    }

    private void setupHistoryPage()
    {
        Box historyPage = new Box(Orientation.Vertical, 4);
        historyPage.setMarginStart(6);
        historyPage.setMarginEnd(6);
        historyPage.setMarginTop(6);
        historyPage.setMarginBottom(6);

        Box headerBox = new Box(Orientation.Horizontal, 4);
        Label titleLbl = new Label("<b>History</b>");
        titleLbl.setUseMarkup(true);
        titleLbl.setHexpand(true);
        titleLbl.setXalign(0);
        headerBox.append(titleLbl);

        Button linkBtn = new Button();
        linkBtn.setIconName("window-new-symbolic");
        linkBtn.connectClicked(delegate void(Button b) {
            parentWindow.openOrSwitchToTab("websurfer:history");
            popover.popdown();
        });
        headerBox.append(linkBtn);
        historyPage.append(headerBox);

        historySearchEntry = new SearchEntry();
        historySearchEntry.setPlaceholderText("Filter history...");
        historySearchEntry.connectSearchChanged(delegate void(SearchEntry e) {
            updateHistoryDropdown();
        });
        historyPage.append(historySearchEntry);

        auto histScroll = new ScrolledWindow();
        histScroll.setVexpand(true);
        histScroll.setPropagateNaturalHeight(true);
        histScroll.setMaxContentHeight(300);
        historyList = new ListBox();
        historyList.setSelectionMode(SelectionMode.None);
        historyList.setActivateOnSingleClick(true);
        historyList.connectRowActivated(&onHistoryRowActivated);
        histScroll.setChild(historyList);
        historyPage.append(histScroll);

        menuStack.addNamed(historyPage, "history");
        menuStack.getPage(historyPage).setIconName("document-open-recent-symbolic");
    }

    private void setupSettingsPage()
    {
        Box settingsPage = new Box(Orientation.Vertical, 8);
        settingsPage.setMarginStart(12);
        settingsPage.setMarginEnd(12);
        settingsPage.setMarginTop(12);
        settingsPage.setMarginBottom(12);

        Box headerBox = new Box(Orientation.Horizontal, 4);
        Label titleLbl = new Label("<b>Settings</b>");
        titleLbl.setUseMarkup(true);
        titleLbl.setHexpand(true);
        titleLbl.setXalign(0);
        headerBox.append(titleLbl);

        Button linkBtn = new Button();
        linkBtn.setIconName("window-new-symbolic");
        linkBtn.connectClicked(delegate void(Button b) {
            parentWindow.openOrSwitchToTab("websurfer:settings");
            popover.popdown();
        });
        headerBox.append(linkBtn);
        settingsPage.append(headerBox);

        import gtk.switch_;
        import storage.settings : enableAdblock, saveSettings;

        Box adblockBox = new Box(Orientation.Horizontal, 12);
        Label adblockLbl = new Label("Enable Adblock (uBO)");
        adblockLbl.setHexpand(true);
        adblockLbl.setXalign(0);
        adblockBox.append(adblockLbl);

        auto adblockSwitch = new Switch();
        adblockSwitch.setValign(Align.Center);
        adblockSwitch.setActive(enableAdblock);
        adblockSwitch.setState(enableAdblock);
        adblockSwitch.connectStateSet(delegate bool(bool state, Switch s) {
            enableAdblock = state;
            saveSettings();
            parentWindow.applyAdblockSetting();
            return false;
        });
        adblockBox.append(adblockSwitch);

        settingsPage.append(adblockBox);

        auto fxaSep = new Separator(Orientation.Horizontal);
        settingsPage.append(fxaSep);

        Box fxaBox = new Box(Orientation.Horizontal, 12);
        Label fxaLbl = new Label("Firefox Account");
        fxaLbl.setHexpand(true);
        fxaLbl.setXalign(0);
        fxaBox.append(fxaLbl);

        Button fxaLoginBtn = new Button();
        fxaLoginBtn.setLabel("Sign In");
        fxaLoginBtn.setValign(Align.Center);
        fxaLoginBtn.connectClicked(delegate void(Button b) { startFxaLogin(); });
        fxaBox.append(fxaLoginBtn);
        settingsPage.append(fxaBox);

        menuStack.addNamed(settingsPage, "settings");
        menuStack.getPage(settingsPage).setIconName("emblem-system-symbolic");
    }

    void onTabRowActivated(ListBoxRow row, ListBox lb)
    {
        if (row is null)
            return;
        string name = row.getName();
        if (name !is null && name.length > 0)
        {
            try
            {
                int tabIdx = to!int(name);
                if (tabIdx >= 0 && tabIdx < parentWindow.tabs.length)
                {
                    parentWindow.notebook.setCurrentPage(tabIdx);
                    popover.popdown();
                }
            }
            catch (Exception e)
            {
            }
        }
    }

    void updateTabsDropdown()
    {
        tabList.removeAll();
        string query = tabSearchEntry.getText().toLower();

        foreach (idx, tab; parentWindow.tabs)
        {
            string title = tab.tabLabel.getLabel();
            if (query.length > 0 && title.toLower().indexOf(query) == -1)
                continue;

            Box rowBox = new Box(Orientation.Horizontal, 4);

            Label lbl = new Label(title);
            lbl.setHexpand(true);
            lbl.setXalign(0);
            lbl.setEllipsize(PangoEllipsizeMode.End);
            rowBox.append(lbl);

            Button closeBtn = new Button();
            closeBtn.setIconName("window-close-symbolic");
            closeBtn.setValign(Align.Center);

            string idxStr = to!string(idx);
            closeBtn.setName(idxStr);
            closeBtn.connectClicked(delegate void(Button b) {
                try
                {
                    int i = to!int(b.getName());
                    if (i >= 0 && i < parentWindow.tabs.length)
                    {
                        parentWindow.closeTab(parentWindow.tabs[i]);
                        updateTabsDropdown();
                    }
                }
                catch (Exception e)
                {
                }
            });
            rowBox.append(closeBtn);

            ListBoxRow row = new ListBoxRow();
            row.setChild(rowBox);
            row.setName(idxStr);
            tabList.append(row);
        }
    }

    void onBookmarkRowActivated(ListBoxRow row, ListBox lb)
    {
        if (row is null)
            return;
        string uri = row.getName();
        if (uri !is null && uri.length > 0)
        {
            auto tab = parentWindow.getActiveTab();
            if (tab)
                tab.loadUri(uri);
            popover.popdown();
        }
    }

    void updateBookmarksDropdown()
    {
        bookmarkList.removeAll();
        string query = bookmarkSearchEntry.getText().toLower();
        auto bookmarks = storage.bookmarks.loadBookmarks();

        foreach (bm; bookmarks)
        {
            if (query.length > 0
                && bm.title.toLower().indexOf(query) == -1
                && bm.uri.toLower().indexOf(query) == -1)
                continue;

            Box rowBox = new Box(Orientation.Horizontal, 4);

            Box textBox = new Box(Orientation.Vertical, 0);
            textBox.setHexpand(true);

            Label titleLbl = new Label(bm.title);
            titleLbl.setXalign(0);
            titleLbl.setEllipsize(PangoEllipsizeMode.End);
            textBox.append(titleLbl);

            Label uriLbl = new Label(bm.uri);
            uriLbl.setXalign(0);
            uriLbl.setEllipsize(PangoEllipsizeMode.End);
            uriLbl.addCssClass("dim-label");
            textBox.append(uriLbl);

            rowBox.append(textBox);

            Button delBtn = new Button();
            delBtn.setIconName("edit-delete-symbolic");
            delBtn.setValign(Align.Center);
            string bmUri = bm.uri;
            delBtn.setName(bmUri);
            delBtn.connectClicked(delegate void(Button b) {
                storage.bookmarks.removeBookmark(b.getName());
                updateBookmarksDropdown();
            });
            rowBox.append(delBtn);

            ListBoxRow row = new ListBoxRow();
            row.setChild(rowBox);
            row.setName(bm.uri);
            bookmarkList.append(row);
        }
    }

    void onHistoryRowActivated(ListBoxRow row, ListBox lb)
    {
        if (row is null)
            return;
        string uri = row.getName();
        if (uri !is null && uri.length > 0)
        {
            auto tab = parentWindow.getActiveTab();
            if (tab)
                tab.loadUri(uri);
            popover.popdown();
        }
    }

    void updateHistoryDropdown()
    {
        historyList.removeAll();
        string query = historySearchEntry.getText().toLower();
        auto entries = storage.history.loadHistory();

        int shown = 0;
        foreach (entry; entries)
        {
            if (shown >= 50)
                break;

            if (query.length > 0
                && entry.title.toLower().indexOf(query) == -1
                && entry.uri.toLower().indexOf(query) == -1)
                continue;

            Box rowBox = new Box(Orientation.Horizontal, 4);

            Box textBox = new Box(Orientation.Vertical, 0);
            textBox.setHexpand(true);

            Label titleLbl = new Label(entry.title);
            titleLbl.setXalign(0);
            titleLbl.setEllipsize(PangoEllipsizeMode.End);
            textBox.append(titleLbl);

            Label uriLbl = new Label(entry.uri);
            uriLbl.setXalign(0);
            uriLbl.setEllipsize(PangoEllipsizeMode.End);
            uriLbl.addCssClass("dim-label");
            textBox.append(uriLbl);

            rowBox.append(textBox);

            ListBoxRow row = new ListBoxRow();
            row.setChild(rowBox);
            row.setName(entry.uri);
            historyList.append(row);
            shown++;
        }
    }

    private void startFxaLogin()
    {
        import sync.ffi;
        import std.string : fromStringz;

        char* urlCStr = websurferx_sync_get_auth_url();
        if (urlCStr !is null)
        {
            string authUrl = cast(string) fromStringz(urlCStr).dup;
            websurferx_sync_free_string(urlCStr);

            parentWindow.newTab(authUrl);
            popover.popdown();
        }
    }
}
