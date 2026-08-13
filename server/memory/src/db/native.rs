// SPDX-License-Identifier: AGPL-3.0-or-later

use std::sync::OnceLock;

use tokio_rusqlite::rusqlite;

use crate::{MemoryError, Result};

static REGISTRATION: OnceLock<std::result::Result<(), ()>> = OnceLock::new();

pub(super) fn register_sqlite_vec() -> Result<()> {
    REGISTRATION
        .get_or_init(register_once)
        .map_err(|()| MemoryError::VectorExtensionRegistration)
}

#[allow(unsafe_code)]
fn register_once() -> std::result::Result<(), ()> {
    // SAFETY: sqlite-vec documents process-wide registration through
    // sqlite3_auto_extension using this exact initializer conversion. The
    // function is guarded by OnceLock, the initializer is linked into this
    // binary, and SQLite copies the function pointer for future connections.
    let result = unsafe {
        let initializer = std::mem::transmute::<
            *const (),
            unsafe extern "C" fn(
                *mut rusqlite::ffi::sqlite3,
                *mut *mut std::os::raw::c_char,
                *const rusqlite::ffi::sqlite3_api_routines,
            ) -> std::os::raw::c_int,
        >(sqlite_vec::sqlite3_vec_init as *const ());
        rusqlite::ffi::sqlite3_auto_extension(Some(initializer))
    };
    if result == rusqlite::ffi::SQLITE_OK {
        Ok(())
    } else {
        Err(())
    }
}
