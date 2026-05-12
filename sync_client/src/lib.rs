use lazy_static::lazy_static;
use std::ffi::{CStr, CString};
use std::os::raw::c_char;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Mutex;

use fxa_client::{FirefoxAccount, FxaConfig, FxaRustAuthState, FxaServer};

lazy_static! {
    static ref FXA_STATE: Mutex<Option<FirefoxAccount>> = Mutex::new(None);
}

static INITIALIZED: AtomicBool = AtomicBool::new(false);

static CLIENT_ID: &str = "a2270f727f45f648";
static REDIRECT_URI: &str = "https://accounts.firefox.com/oauth/success/a2270f727f45f648";

fn get_sync_state_path() -> Option<std::path::PathBuf> {
    let mut path = dirs::data_local_dir()?;
    path.push("websurferx");
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

#[unsafe(no_mangle)]
pub extern "C" fn websurferx_sync_init() -> bool {
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
                    println!(
                        "Rust FFI: Restored existing Firefox Account state from {:?}",
                        path
                    );
                    account = restored;
                }
            }
        }
    }

    *FXA_STATE.lock().unwrap() = Some(account);

    true
}

#[unsafe(no_mangle)]
pub extern "C" fn websurferx_sync_get_auth_url() -> *mut c_char {
    let mut guard = FXA_STATE.lock().unwrap();

    if guard.is_none() {
        *guard = Some(FirefoxAccount::new(make_config()));
    }

    if let Some(account) = guard.as_mut() {
        let scopes = ["https://identity.mozilla.com/apps/oldsync", "profile"];
        match account.begin_oauth_flow(&scopes, "fxa_creds", "") {
            Ok(url) => return CString::new(url).unwrap().into_raw(),
            Err(e) => println!("Rust FFI: Failed to begin OAuth flow: {:?}", e),
        }
    }
    std::ptr::null_mut()
}

#[unsafe(no_mangle)]
pub extern "C" fn websurferx_sync_complete_login(
    code: *const c_char,
    state: *const c_char,
) -> bool {
    let mut guard = FXA_STATE.lock().unwrap();
    if let Some(account) = guard.as_mut() {
        unsafe {
            if code.is_null() || state.is_null() {
                return false;
            }
            let code_str = CStr::from_ptr(code).to_string_lossy();
            let state_str = CStr::from_ptr(state).to_string_lossy();

            match account.complete_oauth_flow(&code_str, &state_str) {
                Ok(_) => {
                    println!("Rust FFI: OAuth flow completed successfully!");
                    save_fxa_state(account);
                    return true;
                }
                Err(e) => println!("Rust FFI: Failed to complete OAuth flow: {:?}", e),
            }
        }
    }
    false
}

#[unsafe(no_mangle)]
pub extern "C" fn websurferx_sync_is_logged_in() -> bool {
    let guard = FXA_STATE.lock().unwrap();
    if let Some(account) = guard.as_ref() {
        return account.get_auth_state() == FxaRustAuthState::Connected;
    }
    false
}

fn derive_bookmark_key(
    client: &sync15::client::Sync15StorageClient,
    root_key: &sync15::KeyBundle,
) -> sync15::KeyBundle {
    let crypto_req = sync15::engine::CollectionRequest::new("crypto/keys".into()).full();
    match client.get_encrypted_records(crypto_req) {
        Ok(sync15::client::Sync15ClientResponse::Success { record, .. }) => {
            if record.is_empty() {
                println!("Rust FFI: crypto/keys record empty on server");
                return root_key.clone();
            }
            match record.into_iter().next().unwrap().into_decrypted(root_key) {
                Ok(decrypted_bso) => {
                    match serde_json::from_str::<serde_json::Value>(&decrypted_bso.payload) {
                        Ok(keys_json) => {
                            let bm_key = keys_json
                                .get("collections")
                                .and_then(|c| c.get("bookmarks"))
                                .and_then(|k| k.as_array())
                                .or_else(|| keys_json.get("default").and_then(|k| k.as_array()));
                            match bm_key {
                                Some(arr) if arr.len() == 2 => {
                                    let enc = arr[0].as_str().unwrap_or("");
                                    let mac = arr[1].as_str().unwrap_or("");
                                    match sync15::KeyBundle::from_base64(enc, mac) {
                                        Ok(kb) => {
                                            println!(
                                                "Rust FFI: Derived bookmark key from crypto/keys"
                                            );
                                            return kb;
                                        }
                                        Err(e) => {
                                            println!(
                                                "Rust FFI: KeyBundle from_base64 failed: {:?}",
                                                e
                                            );
                                        }
                                    }
                                }
                                other => {
                                    println!(
                                        "Rust FFI: No bookmark key in crypto/keys response: {:?}",
                                        other.map(|a| a.len())
                                    );
                                }
                            }
                        }
                        Err(e) => {
                            println!("Rust FFI: crypto/keys JSON parse error: {:?}", e);
                        }
                    }
                }
                Err(e) => {
                    println!("Rust FFI: crypto/keys decrypt error: {:?}", e);
                }
            }
        }
        Ok(sync15::client::Sync15ClientResponse::Error(e)) => {
            println!("Rust FFI: crypto/keys not on server ({:?})", e);
        }
        Err(e) => {
            println!("Rust FFI: crypto/keys fetch error: {:?}", e);
        }
    }
    println!("Rust FFI: Falling back to root sync key for bookmark decryption");
    root_key.clone()
}

#[unsafe(no_mangle)]
pub extern "C" fn websurferx_sync_bookmarks() -> *mut c_char {
    let mut guard = FXA_STATE.lock().unwrap();
    if let Some(account) = guard.as_mut() {
        if let Ok(token) =
            account.get_access_token("https://identity.mozilla.com/apps/oldsync", false)
        {
            println!("Rust FFI: Successfully retrieved Sync Access Token!");

            if let Some(key) = token.key {
                let key_bytes = key.key_bytes().unwrap_or_default();
                let token_url_str = account.get_token_server_endpoint_url().unwrap_or_default();
                let tokenserver_url = match url::Url::parse(&token_url_str) {
                    Ok(u) => u,
                    Err(e) => {
                        println!("Rust FFI: Failed to parse token server url: {:?}", e);
                        return std::ptr::null_mut();
                    }
                };
                let client_init = sync15::client::Sync15StorageClientInit {
                    key_id: key.kid.clone(),
                    access_token: token.token.clone(),
                    tokenserver_url,
                };
                let client = match sync15::client::Sync15StorageClient::new(client_init) {
                    Ok(c) => c,
                    Err(e) => {
                        println!("Rust FFI: Failed to construct StorageClient: {:?}", e);
                        return std::ptr::null_mut();
                    }
                };

                let root_key = match sync15::KeyBundle::from_ksync_bytes(&key_bytes) {
                    Ok(k) => k,
                    Err(e) => {
                        println!("Rust FFI: Failed to construct root KeyBundle: {:?}", e);
                        return std::ptr::null_mut();
                    }
                };

                let bookmark_key = derive_bookmark_key(&client, &root_key);

                let req = sync15::engine::CollectionRequest::new("bookmarks".into()).full();
                match client.get_encrypted_records(req) {
                    Ok(sync15::client::Sync15ClientResponse::Success { record, .. }) => {
                        let mut results = Vec::new();
                        let mut decrypt_fail = 0u32;
                        let mut filtered = 0u32;
                        for bso in record {
                            match bso.into_decrypted(&bookmark_key) {
                                Ok(decrypted) => {
                                    match serde_json::from_str::<serde_json::Value>(
                                        &decrypted.payload,
                                    ) {
                                        Ok(val) => {
                                            let btype = val
                                                .get("type")
                                                .and_then(|v| v.as_str())
                                                .unwrap_or("<missing>");
                                            if btype == "bookmark" || btype == "url" {
                                                if val.get("title").is_some()
                                                    && val.get("bmkUri").is_some()
                                                {
                                                    results.push(val);
                                                } else {
                                                    filtered += 1;
                                                }
                                            } else {
                                                filtered += 1;
                                            }
                                        }
                                        Err(_) => {}
                                    }
                                }
                                Err(_) => {
                                    decrypt_fail += 1;
                                }
                            }
                        }
                        println!(
                            "Rust FFI: Decrypted {} bookmarks ({} decrypt fails, {} filtered)",
                            results.len(),
                            decrypt_fail,
                            filtered
                        );
                        if let Ok(json) = serde_json::to_string(&results) {
                            println!(
                                "Rust FFI: Successfully decrypted {} bookmarks",
                                results.len()
                            );
                            return std::ffi::CString::new(json).unwrap().into_raw();
                        }
                    }
                    Ok(sync15::client::Sync15ClientResponse::Error(e)) => {
                        println!("Rust FFI: Sync API error: {:?}", e);
                    }
                    Err(e) => {
                        println!("Rust FFI: Storage client error: {:?}", e);
                    }
                }
            } else {
                println!("Rust FFI: Sync token is missing encryption key!");
            }
        } else {
            println!("Rust FFI: Failed to get Sync token");
        }
    }
    std::ptr::null_mut()
}

#[unsafe(no_mangle)]
pub extern "C" fn websurferx_sync_free_string(s: *mut c_char) {
    unsafe {
        if s.is_null() {
            return;
        }
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
