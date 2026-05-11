module ui.downloads;

import gtk.box;
import gtk.label;
import gtk.scrolled_window;
import gtk.list_box;
import gtk.list_box_row;
import gtk.progress_bar;
import gtk.button;
import gtk.types : Orientation, Align, SelectionMode;
import std.path : buildPath, baseName;
import std.process : environment;
import std.uri : decode;
import std.array : split;

import webkit.download;
import glib.error : ErrorWrap;

class DownloadsPage : Box
{
    ListBox list;

    this()
    {
        super(Orientation.Vertical, 4);
        setMarginStart(6);
        setMarginEnd(6);
        setMarginTop(6);
        setMarginBottom(6);

        Box headerBox = new Box(Orientation.Horizontal, 4);
        Label titleLabel = new Label("<b>Downloads</b>");
        titleLabel.setUseMarkup(true);
        titleLabel.setHexpand(true);
        titleLabel.setXalign(0);
        headerBox.append(titleLabel);

        Button linkBtn = new Button();
        linkBtn.setIconName("window-new-symbolic");
        linkBtn.connectClicked(delegate void(Button b) {
            import ui.window : BrowserWindow;

            BrowserWindow win = cast(BrowserWindow) getRoot();
            if (win)
            {
                win.openOrSwitchToTab("websurfer:downloads");
                win.menuPopover.popover.popdown();
            }
        });
        headerBox.append(linkBtn);
        append(headerBox);

        auto scroll = new ScrolledWindow();
        scroll.setVexpand(true);
        scroll.setPropagateNaturalHeight(true);
        scroll.setMaxContentHeight(300);

        list = new ListBox();
        list.setSelectionMode(SelectionMode.None);
        list.connectRowActivated(delegate void(ListBoxRow row, ListBox b) {
            import std.process : spawnProcess;

            if (auto ptr = row in rowDestinations)
            {
                spawnProcess(["xdg-open", *ptr]);
            }
        });
        scroll.setChild(list);
        append(scroll);
    }

    private string[ListBoxRow] rowDestinations;
    private Download[] allDownloads;

    import std.json : JSONValue;

    JSONValue[] getDownloadsList()
    {
        JSONValue[] arr;
        foreach (d; allDownloads)
        {
            auto req = d.getRequest();
            string url = req ? req.getUri() : "";
            string dest = d.getDestination();
            string filename = "download";
            if (dest && dest.length > 0)
                filename = baseName(dest);
            else if (url.length > 0)
            {
                auto parts = url.split("/");
                if (parts.length > 0)
                    filename = decode(parts[$ - 1]);
            }

            JSONValue obj = JSONValue(string[string].init);
            obj["filename"] = filename;
            obj["url"] = url;
            obj["progress"] = d.getEstimatedProgress();
            arr ~= obj;
        }
        return arr;
    }

    void addDownload(Download download)
    {
        allDownloads ~= download;

        Box rowBox = new Box(Orientation.Horizontal, 6);
        rowBox.setMarginTop(4);
        rowBox.setMarginBottom(4);

        Box infoBox = new Box(Orientation.Vertical, 2);
        infoBox.setHexpand(true);

        auto req = download.getRequest();
        string url = req ? req.getUri() : "Unknown";
        string filename = "download";

        auto dest = download.getDestination();
        if (dest && dest.length > 0)
        {
            filename = baseName(dest);
        }
        else
        {
            auto parts = url.split("/");
            if (parts.length > 0)
                filename = decode(parts[$ - 1]);
        }

        Label nameLbl = new Label(filename);
        nameLbl.setXalign(0);
        import pango.types : PangoEllipsizeMode = EllipsizeMode;

        nameLbl.setEllipsize(PangoEllipsizeMode.End);
        infoBox.append(nameLbl);

        ProgressBar progress = new ProgressBar();
        progress.setFraction(0.0);
        infoBox.append(progress);

        rowBox.append(infoBox);

        Button copyBtn = new Button();
        copyBtn.setIconName("edit-copy-symbolic");
        copyBtn.setValign(Align.Center);
        copyBtn.setTooltipText("Copy download URL");
        string downloadUrl = url;
        copyBtn.connectClicked(delegate void(Button b) {
            import gdk.display : Display;
            import gobject.value : Value;

            auto clipboard = Display.getDefault().getClipboard();
            auto val = new Value(downloadUrl);
            clipboard.set(val);
        });
        rowBox.append(copyBtn);

        Button cancelBtn = new Button();
        cancelBtn.setIconName("process-stop-symbolic");
        cancelBtn.setValign(Align.Center);
        cancelBtn.setTooltipText("Cancel download");
        cancelBtn.connectClicked(delegate void(Button b) { download.cancel(); });
        rowBox.append(cancelBtn);

        ListBoxRow row = new ListBoxRow();
        row.setChild(rowBox);
        list.prepend(row);

        if (dest && dest.length > 0)
            rowDestinations[row] = dest;

        download.connectReceivedData(delegate void(ulong dataLength, Download d) {
            double est = d.getEstimatedProgress();
            progress.setFraction(est);
        });

        download.connectFinished(delegate void(Download d) {
            progress.setFraction(1.0);
            nameLbl.setLabel("✓ " ~ filename);
            progress.addCssClass("success");
            cancelBtn.setVisible(false);
        });

        download.connectFailed(delegate void(ErrorWrap e, Download d) {
            nameLbl.setLabel("✗ " ~ filename);
            progress.addCssClass("error");
            cancelBtn.setVisible(false);
        });
    }
}

string getDefaultDownloadDir()
{
    string home = environment.get("HOME", "/tmp");
    return buildPath(home, "Downloads");
}
