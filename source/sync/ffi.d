module sync.ffi;

extern (C)
{
    bool websurferx_sync_init();
    char* websurferx_sync_bookmarks();
    bool websurferx_sync_is_logged_in();
    char* websurferx_sync_get_auth_url();
    bool websurferx_sync_complete_login(const char* code, const char* state);
    void websurferx_sync_free_string(char* s);
}
