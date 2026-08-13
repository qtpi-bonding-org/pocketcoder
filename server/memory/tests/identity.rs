// SPDX-License-Identifier: AGPL-3.0-or-later

use axum::http::{HeaderMap, HeaderValue};
use base64::{Engine as _, engine::general_purpose::URL_SAFE_NO_PAD};
use pocket_memory::{
    MemoryError,
    identity::{MEMORY_CONTEXT_HEADER, decode_identity},
};

fn encoded(value: &serde_json::Value) -> HeaderValue {
    let json = serde_json::to_vec(&value).unwrap();
    HeaderValue::from_str(&URL_SAFE_NO_PAD.encode(json)).unwrap()
}

#[test]
fn versioned_unicode_identity_round_trips() {
    let mut headers = HeaderMap::new();
    headers.insert(
        &MEMORY_CONTEXT_HEADER,
        encoded(&serde_json::json!({
            "version": 1,
            "account_id": "family",
            "agent_profile_id": "poco-id",
            "agent_name": "ポコ 🐈"
        })),
    );

    let identity = decode_identity(&headers).unwrap();
    assert_eq!(identity.account_id, "family");
    assert_eq!(identity.agent_profile_id, "poco-id");
    assert_eq!(identity.agent_name, "ポコ 🐈");
}

#[test]
fn missing_malformed_and_unknown_versions_are_rejected() {
    assert!(matches!(
        decode_identity(&HeaderMap::new()),
        Err(MemoryError::InvalidIdentity(_))
    ));

    let mut malformed = HeaderMap::new();
    malformed.insert(&MEMORY_CONTEXT_HEADER, HeaderValue::from_static("nope"));
    assert!(matches!(
        decode_identity(&malformed),
        Err(MemoryError::InvalidIdentity(_))
    ));

    let mut unknown = HeaderMap::new();
    unknown.insert(
        &MEMORY_CONTEXT_HEADER,
        encoded(&serde_json::json!({
            "version": 2,
            "account_id": "family",
            "agent_profile_id": "poco-id",
            "agent_name": "Poco"
        })),
    );
    assert!(matches!(
        decode_identity(&unknown),
        Err(MemoryError::InvalidIdentity(_))
    ));
}
