module ui.toolbar;

import gtk.box;
import gtk.button;
import gtk.entry;
import gtk.menu_button;
import gtk.types;
import gobject.param_spec;
import gobject.object;

import ui.window;
import storage.bookmarks;

class Toolbar : Box
{
    Entry urlEntry;
    MenuButton menuBtn;
    CircularProgressBar downloadProgress;
    BrowserWindow parentWindow;

    this(BrowserWindow parentWindow)
    {
        super(Orientation.Horizontal, 4);
        this.parentWindow = parentWindow;

        setMarginTop(4);
        setMarginBottom(4);
        setMarginStart(4);
        setMarginEnd(4);

        Button backBtn = new Button();
        backBtn.setIconName("go-previous-symbolic");
        backBtn.connectClicked(delegate void(Button b) {
            if (auto t = parentWindow.getActiveTab())
                t.view.goBack();
        });
        append(backBtn);

        Button fwdBtn = new Button();
        fwdBtn.setIconName("go-next-symbolic");
        fwdBtn.connectClicked(delegate void(Button b) {
            if (auto t = parentWindow.getActiveTab())
                t.view.goForward();
        });
        append(fwdBtn);

        Button reloadBtn = new Button();
        reloadBtn.setIconName("view-refresh-symbolic");
        reloadBtn.connectClicked(delegate void(Button b) {
            if (auto t = parentWindow.getActiveTab())
                t.view.reload();
        });
        append(reloadBtn);

        urlEntry = new Entry();
        urlEntry.setHexpand(true);
        urlEntry.setPlaceholderText("Search or enter URL...");
        urlEntry.connectActivate(delegate void(Entry e) {
            parentWindow.navigateOrSearch(e.getText());
            parentWindow.suggestionsPopover.hide();
        });

        import gtk.event_controller_focus;

        auto focusController = new EventControllerFocus();
        focusController.connectEnter(delegate void(EventControllerFocus c) {
            import glib.global : idleAdd;

            idleAdd(0, delegate bool() {
                urlEntry.selectRegion(0, -1);
                return false;
            });
        });
        urlEntry.addController(focusController);

        urlEntry.connectNotify("text", delegate void(gobject.param_spec.ParamSpec pspec, gobject
                .object.ObjectWrap obj) {
            parentWindow.suggestionsPopover.scheduleFetch(urlEntry.getText());
        });

        append(urlEntry);


        menuBtn = new MenuButton();

        import gtk.stack;
        import gtk.image;

        auto menuStack = new Stack();
        menuStack.setTransitionType(gtk.types.StackTransitionType.Crossfade);

        auto menuIcon = new Image();
        menuIcon.setFromIconName("open-menu-symbolic");
        menuStack.addNamed(menuIcon, "icon");

        downloadProgress = new CircularProgressBar();
        downloadProgress.setHalign(Align.Center);
        downloadProgress.setValign(Align.Center);
        menuStack.addNamed(downloadProgress, "progress");

        menuBtn.setChild(menuStack);
        append(menuBtn);
    }

    void setDownloadProgressVisible(bool visible)
    {
        import gtk.stack;

        auto stack = cast(Stack) menuBtn.getChild();
        if (visible)
        {
            stack.setVisibleChildName("progress");
        }
        else
        {
            stack.setVisibleChildName("icon");
            downloadProgress.setFraction(0.0);
        }
    }

    void setDownloadProgress(double fraction)
    {
        downloadProgress.setFraction(fraction);
    }
}

import gtk.drawing_area;
import cairo.context;
import std.math;

class CircularProgressBar : DrawingArea
{
    private double fraction = 0.0;

    this()
    {
        super();
        setSizeRequest(16, 16);
        setDrawFunc(delegate void(DrawingArea area, Context cr, int width, int height) {
            cr.setLineWidth(3.5);
            import cairo.types : LineCap;

            cr.setLineCap(LineCap.Round);

            double cx = width / 2.0;
            double cy = height / 2.0;
            double radius = (width < height ? width : height) / 2.0 - 1.75;

            cr.setSourceRgba(0.5, 0.5, 0.5, 0.3);
            cr.arc(cx, cy, radius, 0, 2 * PI);
            cr.stroke();

            cr.setSourceRgba(0.2, 0.6, 1.0, 1.0);
            double endAngle = -PI / 2.0 + fraction * 2 * PI;
            cr.arc(cx, cy, radius, -PI / 2.0, endAngle);
            cr.stroke();
        });
    }

    void setFraction(double f)
    {
        fraction = f;
        queueDraw();
    }
}
