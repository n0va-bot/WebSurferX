module core.config;

bool surfUserAgent = true;
string fullUserAgent = "";
string scriptFile = "~/.local/share/websurferx/script.js";
string styleDir = "~/.local/share/websurferx/styles/";
string certDir = "~/.local/share/websurferx/certificates/";
string cacheDir = "~/.local/share/websurferx/cache/";
string cookieFile = "~/.local/share/websurferx/cookies.txt";

int[] winSize = [800, 600];

enum ParamName
{
    AccessMicrophone,
    AccessWebcam,
    CaretBrowsing,
    Certificate,
    CookiePolicies,
    DarkMode,
    DiskCache,
    DefaultCharset,
    DNSPrefetch,
    Ephemeral,
    FileURLsCrossAccess,
    FontSize,
    Geolocation,
    HideBackground,
    Inspector,
    JavaScript,
    KioskMode,
    LoadImages,
    MediaManualPlay,
    PDFJSviewer,
    PreferredLanguages,
    RunInFullscreen,
    ScrollBars,
    ShowIndicators,
    SiteQuirks,
    SmoothScrolling,
    SpellChecking,
    SpellLanguages,
    StrictTLS,
    Style,
    WebGL,
    ZoomLevel
}

struct ParamValue
{
    int i;
    float f;
    string s;
}

struct Parameter
{
    ParamValue val;
    int prio;
}

Parameter[ParamName] defConfig;

static this()
{
    defConfig[ParamName.AccessMicrophone] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.AccessWebcam] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.Certificate] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.CaretBrowsing] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.CookiePolicies] = Parameter(ParamValue(0, 0, "@Aa"), 0);
    defConfig[ParamName.DarkMode] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.DefaultCharset] = Parameter(ParamValue(0, 0, "UTF-8"), 0);
    defConfig[ParamName.DiskCache] = Parameter(ParamValue(1), 0);
    defConfig[ParamName.DNSPrefetch] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.Ephemeral] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.FileURLsCrossAccess] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.FontSize] = Parameter(ParamValue(12), 0);
    defConfig[ParamName.Geolocation] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.HideBackground] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.Inspector] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.JavaScript] = Parameter(ParamValue(1), 0);
    defConfig[ParamName.KioskMode] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.LoadImages] = Parameter(ParamValue(1), 0);
    defConfig[ParamName.MediaManualPlay] = Parameter(ParamValue(1), 0);
    defConfig[ParamName.PDFJSviewer] = Parameter(ParamValue(1), 0);
    defConfig[ParamName.PreferredLanguages] = Parameter(ParamValue(0, 0, ""), 0);
    defConfig[ParamName.RunInFullscreen] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.ScrollBars] = Parameter(ParamValue(1), 0);
    defConfig[ParamName.ShowIndicators] = Parameter(ParamValue(1), 0);
    defConfig[ParamName.SiteQuirks] = Parameter(ParamValue(1), 0);
    defConfig[ParamName.SmoothScrolling] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.SpellChecking] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.SpellLanguages] = Parameter(ParamValue(0, 0, "en_US"), 0);
    defConfig[ParamName.StrictTLS] = Parameter(ParamValue(1), 0);
    defConfig[ParamName.Style] = Parameter(ParamValue(1), 0);
    defConfig[ParamName.WebGL] = Parameter(ParamValue(0), 0);
    defConfig[ParamName.ZoomLevel] = Parameter(ParamValue(0, 1.0), 0);
}

struct UriParameters
{
    string uriRegex;
    Parameter[ParamName] config;
}

UriParameters[] uriParams;

static this()
{
    uriParams ~= UriParameters("(://|\\.)suckless\\.org(/|$)", [
            ParamName.JavaScript: Parameter(ParamValue(0), 1)
        ]);
}

struct SiteSpecific
{
    string regex;
    string file;
}

SiteSpecific[] styles = [
    SiteSpecific(".*", "default.css")
];

SiteSpecific[] certs = [
    SiteSpecific("://suckless\\.org/", "suckless.org.crt")
];
