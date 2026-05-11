module main;

import gtk.application;
import gio.application : GioApplication = Application;
import gio.types;
import gtk.settings : Settings;
import ui.window;

int main(string[] args)
{
    auto app = new Application("org.websurfery.browser", ApplicationFlags.FlagsNone);

    BrowserWindow win;

    app.connectActivate(delegate void(GioApplication gioApp) {
        import storage.settings : loadSettings;
        import storage.adblock : initAdblock;

        loadSettings();

        import sync.ffi : websurfery_sync_init;

        websurfery_sync_init();

        initAdblock(delegate void(bool success) {
            import std.stdio;

            if (success)
            {
                writeln("Adblock filters loaded successfully.");
                if (win !is null)
                    win.applyAdblockSetting();
            }
            else
            {
                writeln("Failed to load adblock filters.");
            }
        });

        import internal_pages.scheme : registerWebsurferScheme;

        registerWebsurferScheme();

        Settings.getDefault().gtkApplicationPreferDarkTheme = true;
        auto application = cast(Application) gioApp;

        import gio.menu : Menu;
        import gio.simple_action : SimpleAction;
        import glib.variant : Variant;

        auto menubar = new Menu();
        auto fileMenu = new Menu();
        fileMenu.append("New Tab", "app.newTab");
        fileMenu.append("Quit", "app.quit");
        menubar.appendSubmenu("File", fileMenu);

        auto editMenu = new Menu();
        menubar.appendSubmenu("Edit", editMenu);

        auto viewMenu = new Menu();
        menubar.appendSubmenu("View", viewMenu);

        auto historyMenu = new Menu();
        menubar.appendSubmenu("History", historyMenu);

        auto bookmarksMenu = new Menu();
        menubar.appendSubmenu("Bookmarks", bookmarksMenu);

        auto downloadsMenu = new Menu();
        menubar.appendSubmenu("Downloads", downloadsMenu);

        auto helpMenu = new Menu();
        menubar.appendSubmenu("Help", helpMenu);

        viewMenu.append("Settings", "app.showSettings");
        historyMenu.append("Show History", "app.showHistory");
        bookmarksMenu.append("Show Bookmarks", "app.showBookmarks");
        downloadsMenu.append("Show Downloads", "app.showDownloads");

        application.setMenubar(menubar);

        auto quitAction = new SimpleAction("quit", null);
        quitAction.connectActivate(delegate void(Variant v, SimpleAction a) {
            application.quit();
        });
        application.addAction(quitAction);

        auto newTabAction = new SimpleAction("newTab", null);
        newTabAction.connectActivate(delegate void(Variant v, SimpleAction a) {
            if (win !is null)
                win.newTab("websurfer:start");
        });
        application.addAction(newTabAction);

        auto showHistoryAction = new SimpleAction("showHistory", null);
        showHistoryAction.connectActivate(delegate void(Variant v, SimpleAction a) {
            if (win !is null)
                win.openOrSwitchToTab("websurfer:history");
        });
        application.addAction(showHistoryAction);

        auto showBookmarksAction = new SimpleAction("showBookmarks", null);
        showBookmarksAction.connectActivate(delegate void(Variant v, SimpleAction a) {
            if (win !is null)
                win.openOrSwitchToTab("websurfer:bookmarks");
        });
        application.addAction(showBookmarksAction);

        auto showDownloadsAction = new SimpleAction("showDownloads", null);
        showDownloadsAction.connectActivate(delegate void(Variant v, SimpleAction a) {
            if (win !is null)
                win.openOrSwitchToTab("websurfer:downloads");
        });
        application.addAction(showDownloadsAction);

        auto showSettingsAction = new SimpleAction("showSettings", null);
        showSettingsAction.connectActivate(delegate void(Variant v, SimpleAction a) {
            if (win !is null)
                win.openOrSwitchToTab("websurfer:settings");
        });
        application.addAction(showSettingsAction);

        win = new BrowserWindow(application);

        import storage.session : loadSession;

        string[] sessionUris = loadSession();

        if (args.length > 1)
        {
            win.newTab(args[1]);
        }
        else if (sessionUris.length > 0)
        {
            foreach (uri; sessionUris)
                win.newTab(uri);
        }
        else
        {
            win.newTab("websurfer:start");
        }

        win.present();
    });

    return app.run([args[0]]);
}
