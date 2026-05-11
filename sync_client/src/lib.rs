use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::Mutex;
use lazy_static::lazy_static;
use std::sync::atomic::{AtomicBool, Ordering};

use fxa_client::{FirefoxAccount, FxaConfig, FxaServer, FxaRustAuthState};

lazy_static! {
    static ref FXA_STATE: Mutex<Option<FirefoxAccount>> = Mutex::new(None);
}

static INITIALIZED: AtomicBool = AtomicBool::new(false);

static CLIENT_ID: &str = "a2270f727f45f648"; 
static REDIRECT_URI: &str = "http://127.0.0.1/websurfer-fxa-login";

fn get_sync_state_path() -> Option<std::path::PathBuf> {
    let mut path = dirs::data_local_dir()?;
    path.push("websurfery");
    std::fs::create_dir_all(&path).ok()?;
    path.push("sync_state.json");
    Some(path)
}

fn make_config() -> FxaConfig {
    FxaConfig {
        server: FxaServer::Release,
        redirect_uri: REDIRECT_URI.into(),
        client_id: CLIENT_ID.into(),
        token_server_url_override: None,
    }
}

fn save_fxa_state(account: &FirefoxAccount) {
    if let Some(path) = get_sync_state_path() {
        if let Ok(json) = account.to_json() {
            std::fs::write(path, json).unwrap_or_else(|e| println!("Failed to save state: {}", e));
        }
    }
}

fn clear_saved_state() {
    if let Some(path) = get_sync_state_path() {
        if path.exists() {
            let _ = std::fs::remove_file(&path);
        }
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn websurfery_sync_init() -> bool {
    // Only initialize once — the PKCE flow state lives in memory
    // and must not be destroyed by re-init during an active flow.
    if INITIALIZED.swap(true, Ordering::SeqCst) {
        return true;
    }

    nss::ensure_initialized();
    
    if let Err(e) = viaduct_hyper::viaduct_init_backend_hyper() {
        println!("Rust FFI: Failed to init viaduct: {:?}", e);
        INITIALIZED.store(false, Ordering::SeqCst);
        return false;
    }

    let mut account = FirefoxAccount::new(make_config());

    if let Some(path) = get_sync_state_path() {
        if path.exists() {
            if let Ok(data) = std::fs::read_to_string(&path) {
                if let Ok(restored) = FirefoxAccount::from_json(&data) {
                    println!("Rust FFI: Restored existing Firefox Account state from {:?}", path);
                    account = restored;
                }
            }
        }
    }

    *FXA_STATE.lock().unwrap() = Some(account);

    true
}

#[unsafe(no_mangle)]
pub extern "C" fn websurfery_sync_get_auth_url() -> *mut c_char {
    let mut guard = FXA_STATE.lock().unwrap();
    if let Some(account) = guard.as_mut() {
        // If we're disconnected (no tokens), start with a completely fresh
        // account to avoid stale last_seen_profile or other artifacts from
        // prior failed attempts causing "Expired Code" errors.
        if account.get_auth_state() == FxaRustAuthState::Disconnected {
            clear_saved_state();
            *account = FirefoxAccount::new(make_config());
        }

        let scopes = ["https://identity.mozilla.com/apps/oldsync", "profile"];
        match account.begin_oauth_flow(&scopes, "websurfery_toolbar", "websurfery_login") {
            Ok(url) => {
                save_fxa_state(account);
                return CString::new(url).unwrap().into_raw();
            },
            Err(e) => println!("Rust FFI: Failed to begin OAuth flow: {:?}", e),
        }
    }
    std::ptr::null_mut()
}

#[unsafe(no_mangle)]
pub extern "C" fn websurfery_sync_complete_login(code: *const c_char, state: *const c_char) -> bool {
    let mut guard = FXA_STATE.lock().unwrap();
    if let Some(account) = guard.as_mut() {
        unsafe {
            if code.is_null() || state.is_null() { return false; }
            let code_str = CStr::from_ptr(code).to_string_lossy();
            let state_str = CStr::from_ptr(state).to_string_lossy();
            
            match account.complete_oauth_flow(&code_str, &state_str) {
                Ok(_) => {
                    println!("Rust FFI: OAuth flow completed successfully!");
                    save_fxa_state(account);
                    return true;
                },
                Err(e) => println!("Rust FFI: Failed to complete OAuth flow: {:?}", e),
            }
        }
    }
    false
}

#[unsafe(no_mangle)]
pub extern "C" fn websurfery_sync_is_logged_in() -> bool {
    let guard = FXA_STATE.lock().unwrap();
    if let Some(account) = guard.as_ref() {
        return account.get_auth_state() == FxaRustAuthState::Connected;
    }
    false
}

#[unsafe(no_mangle)]
pub extern "C" fn websurfery_sync_bookmarks() -> bool {
    let mut guard = FXA_STATE.lock().unwrap();
    if let Some(account) = guard.as_mut() {
        match account.get_access_token("https://identity.mozilla.com/apps/oldsync", false) {
            Ok(_) => {
                println!("Rust FFI: Successfully retrieved Sync Access Token!");
                return true;
            },
            Err(e) => println!("Rust FFI: Failed to get Sync token: {:?}", e),
        }
    }
    false
}

#[unsafe(no_mangle)]
pub extern "C" fn websurfery_sync_free_string(s: *mut c_char) {
    unsafe {
        if s.is_null() { return }
        let _ = CString::from_raw(s);
    }
}

#[unsafe(no_mangle)]
pub extern "C" fn VerifyCodeSigningCertificateChain(
    _certificates: *mut *const u8,
    _certificate_lengths: *const u16,
    _num_certificates: usize,
    _seconds_since_epoch: u64,
    _root_sha256_hash: *const u8,
    _hostname: *const u8,
    _hostname_length: usize,
    _error: *mut i32,
) -> bool {
    false
}
