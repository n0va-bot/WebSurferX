module ui.suggestions;

import gtk.popover;
import gtk.list_box;
import gtk.list_box_row;
import gtk.label;
import gtk.scrolled_window;
import gtk.entry;
import core.thread : Thread;
import glib.global;
import glib.types;
import gtk.types;
import core.search;
import ui.window;

class SuggestionsPopover
{
    Popover popover;
    ListBox list;
    Suggestion[] currentSuggestions;
    bool suggestionsPending = false;
    BrowserWindow parentWindow;
    Entry urlEntry;
    SearchProvider searchProvider;

    this(BrowserWindow parentWindow, Entry urlEntry, SearchProvider searchProvider = null)
    {
        this.parentWindow = parentWindow;
        this.urlEntry = urlEntry;
        this.searchProvider = searchProvider ? searchProvider : new CompositeSearchProvider();

        popover = new Popover();
        popover.setHasArrow(false);
        popover.setAutohide(false);

        auto scrollWin = new ScrolledWindow();
        scrollWin.setMaxContentHeight(400);
        scrollWin.setPropagateNaturalHeight(true);

        list = new ListBox();
        list.setSelectionMode(SelectionMode.None);
        list.setActivateOnSingleClick(true);
        list.connectRowActivated(&onRowActivated);
        scrollWin.setChild(list);

        popover.setChild(scrollWin);
        popover.setParent(urlEntry);
    }

    void onRowActivated(ListBoxRow row, ListBox lb)
    {
        if (row is null)
            return;
        string text = row.getName();
        if (text !is null && text.length > 0)
        {
            urlEntry.setText(text);
            parentWindow.navigateOrSearch(text);
            hide();
        }
    }

    void scheduleFetch(string text)
    {
        import core.utils : looksLikeUrl;

        if (text.length < 2 || looksLikeUrl(text))
        {
            hide();
            return;
        }

        suggestionsPending = true;
        string query = text.idup;

        new Thread({
            try
            {
                Suggestion[] suggestions = searchProvider.fetchSuggestions(query);
                currentSuggestions = suggestions;
                suggestionsPending = false;

                idleAdd(PRIORITY_DEFAULT, delegate bool() { show(); return false; });
            }
            catch (Exception e)
            {
                suggestionsPending = false;
            }
        }).start();
    }

    void show()
    {
        list.removeAll();

        if (currentSuggestions.length == 0)
        {
            hide();
            return;
        }

        foreach (s; currentSuggestions)
        {
            import gtk.box;
            import gtk.image;
            import gtk.types : Orientation;

            Box rowBox = new Box(Orientation.Horizontal, 6);

            if (s.iconName !is null)
            {
                Image icon = new Image();
                icon.setFromIconName(s.iconName);
                icon.setMarginStart(4);
                rowBox.append(icon);
            }

            string displayText = s.title;
            if (s.uri !is null)
                displayText ~= " - " ~ s.uri;

            Label lbl = new Label(displayText);
            lbl.setXalign(0);
            lbl.setMarginStart(4);
            lbl.setMarginEnd(4);

            import pango.types : PangoEllipsizeMode = EllipsizeMode;

            lbl.setEllipsize(PangoEllipsizeMode.End);

            rowBox.append(lbl);

            ListBoxRow row = new ListBoxRow();
            row.setChild(rowBox);
            row.setName(s.uri !is null ? s.uri : s.title);
            list.append(row);
        }

        int barWidth = urlEntry.getAllocatedWidth();
        if (barWidth > 200)
            popover.setSizeRequest(barWidth, -1);

        popover.popup();
    }

    void hide()
    {
        popover.popdown();
        currentSuggestions = [];
    }
}
