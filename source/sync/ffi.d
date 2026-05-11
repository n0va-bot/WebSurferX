module sync.ffi;

extern (C)
{
    bool websurfery_sync_init();
    bool websurfery_sync_bookmarks();
    bool websurfery_sync_is_logged_in();
    char* websurfery_sync_get_auth_url();
    bool websurfery_sync_complete_login(const char* code, const char* state);
    void websurfery_sync_free_string(char* s);
}
