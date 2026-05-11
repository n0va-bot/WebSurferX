module ui.findbar;

import gtk.search_bar;
import gtk.search_entry;
import gtk.box;
import gtk.button;
import gtk.label;
import gtk.types : Orientation, Align;
import ui.window;

class FindBar : SearchBar
{
    SearchEntry entry;
    Button nextBtn;
    Button prevBtn;
    Button closeBtn;
    Label countLabel;
    BrowserWindow parentWindow;

    this(BrowserWindow parentWindow)
    {
        this.parentWindow = parentWindow;

        Box box = new Box(Orientation.Horizontal, 6);
        box.setHalign(Align.Center);

        entry = new SearchEntry();
        entry.setPlaceholderText("Find in page...");
        entry.connectSearchChanged(&onSearchChanged);
        entry.connectActivate(&onActivate);
        box.append(entry);

        countLabel = new Label("");
        countLabel.addCssClass("dim-label");
        box.append(countLabel);

        prevBtn = new Button();
        prevBtn.setIconName("go-up-symbolic");
        prevBtn.connectClicked(&onPrevClicked);
        box.append(prevBtn);

        nextBtn = new Button();
        nextBtn.setIconName("go-down-symbolic");
        nextBtn.connectClicked(&onNextClicked);
        box.append(nextBtn);

        closeBtn = new Button();
        closeBtn.setIconName("window-close-symbolic");
        closeBtn.connectClicked(delegate void(Button b) {
            setSearchMode(false);
            auto tab = this.parentWindow.getActiveTab();
            if (tab)
                tab.view.getFindController().searchFinish();
        });
        box.append(closeBtn);

        setChild(box);
        connectEntry(entry);
    }

    void open()
    {
        setSearchMode(true);
        entry.grabFocus();
    }

    void onSearchChanged(SearchEntry e)
    {
        string query = e.getText();
        auto tab = parentWindow.getActiveTab();
        if (tab is null)
            return;

        auto controller = tab.view.getFindController();
        controller.searchFinish();
        if (query.length > 0)
        {
            import webkit.types : FindOptions;

            controller.search(query, FindOptions.CaseInsensitive | FindOptions.WrapAround, 0);
        }
        else
        {
            countLabel.setLabel("");
        }
    }

    void onActivate(SearchEntry e)
    {
        onNextClicked(null);
    }

    void onNextClicked(Button b)
    {
        auto tab = parentWindow.getActiveTab();
        if (tab)
            tab.view.getFindController().searchNext();
    }

    void onPrevClicked(Button b)
    {
        auto tab = parentWindow.getActiveTab();
        if (tab)
            tab.view.getFindController().searchPrevious();
    }
}
