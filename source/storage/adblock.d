module storage.adblock;

import std.path;
import std.file;
import std.process;
import std.stdio;

import webkit.user_content_filter_store;
import webkit.user_content_filter;
import webkit.user_content_manager;
import glib.error : ErrorWrap;
import gio.file : GioFile = File;
import gio.async_result;
import gio.cancellable;
import gobject.object;
import glib.global : idleAdd;

string getAdblockDir()
{
    string home = environment.get("HOME", "/tmp");
    string dir = buildPath(home, ".config", "websurferx", "adblock");
    if (!exists(dir))
        mkdirRecurse(dir);
    return dir;
}

__gshared UserContentFilterStore filterStore;
__gshared UserContentFilter[string] loadedFilters;
__gshared bool isInitialized = false;
__gshared void delegate(bool)[] pendingCallbacks;

void initAdblock(void delegate(bool) onReady)
{
    if (isInitialized)
    {
        if (onReady)
            onReady(true);
        return;
    }

    if (onReady)
        pendingCallbacks ~= onReady;

    if (filterStore is null)
    {
        filterStore = UserContentFilterStore.builder().path(getAdblockDir()).build();
    }

    if (pendingCallbacks.length > 1)
        return;

    string[] parts = ["combined-part1", "combined-part2"];
    string markerFile = buildPath(getAdblockDir(), "filters_v1.marker");

    if (exists(markerFile))
    {
        loadFilter(parts, 0, delegate void(bool success) {
            isInitialized = success;
            foreach (cb; pendingCallbacks)
                cb(success);
            pendingCallbacks.length = 0;
        });
    }
    else
    {
        writeln("Downloading adblock filters (this may take a moment)...");
        import std.parallelism : task, taskPool;

        auto downloadTask = task!downloadAndCompileFilters(parts, markerFile);
        taskPool.put(downloadTask);
    }
}

void loadFilter(string[] parts, int index, void delegate(bool) onReady)
{
    if (index >= parts.length)
    {
        if (onReady)
            onReady(true);
        return;
    }

    string part = parts[index];
    filterStore.load(part, null, delegate void(ObjectWrap sourceObject, AsyncResult res) {
        try
        {
            auto filter = filterStore.loadFinish(res);
            loadedFilters[part] = filter;
            loadFilter(parts, index + 1, onReady);
        }
        catch (Exception e)
        {
            writeln("Failed to load compiled filter ", part, ": ", e.msg);
            if (onReady)
                onReady(false);
        }
    });
}

void downloadAndCompileFilters(string[] parts, string markerFile)
{
    try
    {
        string tempDir = buildPath(getAdblockDir(), "tmp");
        if (!exists(tempDir))
            mkdirRecurse(tempDir);

        string[] tempFiles;
        foreach (part; parts)
        {
            string url = "https://github.com/bnema/ublock-webkit-filters/releases/latest/download/" ~ part ~ ".json";
            string dest = buildPath(tempDir, part ~ ".json");
            import std.net.curl : download;

            writeln("Downloading ", url, " to ", dest);
            download(url, dest);
            tempFiles ~= dest;
        }

        idleAdd(0, delegate bool() {
            compileNextFilter(parts, tempFiles, markerFile, 0, delegate void(bool success) {
                isInitialized = success;
                foreach (cb; pendingCallbacks)
                    cb(success);
                pendingCallbacks.length = 0;
            });
            return false;
        });
    }
    catch (Exception e)
    {
        writeln("Failed to download filters: ", e.msg);
        idleAdd(0, delegate bool() {
            foreach (cb; pendingCallbacks)
                cb(false);
            pendingCallbacks.length = 0;
            return false;
        });
    }
}

void compileNextFilter(string[] parts, string[] files, string markerFile, int index, void delegate(
        bool) onReady)
{
    if (index >= parts.length)
    {
        import std.file : write;

        write(markerFile, "done");
        if (onReady)
            onReady(true);
        return;
    }

    string part = parts[index];
    string file = files[index];

    GioFile gioFile = GioFile.newForPath(file);
    writeln("Compiling filter ", part, "...");
    filterStore.saveFromFile(part, gioFile, null, delegate void(ObjectWrap sourceObject, AsyncResult res) {
        try
        {
            auto filter = filterStore.saveFromFileFinish(res);
            loadedFilters[part] = filter;
            writeln("Successfully compiled filter: ", part);

            import std.file : remove;

            remove(file);

            compileNextFilter(parts, files, markerFile, index + 1, onReady);
        }
        catch (Exception e)
        {
            writeln("Failed to compile filter ", part, ": ", e.msg);
            if (onReady)
                onReady(false);
        }
    });
}

void loadAdblockFilters(UserContentManager ucm)
{
    import storage.settings : enableAdblock;

    if (!enableAdblock)
        return;

    foreach (part, filter; loadedFilters)
    {
        ucm.addFilter(filter);
    }
}

void removeAdblockFilters(UserContentManager ucm)
{
    ucm.removeAllFilters();
}
