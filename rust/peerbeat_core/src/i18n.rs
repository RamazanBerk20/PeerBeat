//! Tiny localization for the handful of *deliberate* user-facing error messages
//! the API layer raises (validation + not-found guards). Transitive library
//! errors (SQLite/IO/codec) stay technical English — they surface inside an
//! already-localized wrapper sentence on the Flutter side.
//!
//! No extra FRB surface: the current UI language is whatever Flutter persisted
//! under the `ui.locale` settings key. [`set_locale`] is called from
//! `db::settings::set` whenever that key is written, and once at
//! `library_open`, so the global tracks the user's choice without a new bridge
//! function. Empty / unknown → English.

use std::sync::RwLock;

static LOCALE: RwLock<String> = RwLock::new(String::new());

/// Update the active locale (a BCP-47 language code like `tr`; `""` = English).
pub fn set_locale(tag: &str) {
    if let Ok(mut g) = LOCALE.write() {
        // Keep only the language subtag (e.g. `pt-BR` -> `pt`).
        *g = tag.split(['-', '_']).next().unwrap_or("").to_string();
    }
}

fn lang() -> String {
    LOCALE.read().map(|g| g.clone()).unwrap_or_default()
}

/// A deliberate, user-facing message the API can return.
#[derive(Clone, Copy)]
pub enum Msg {
    PinFormat,
    TrackNotFound,
    TrackVanished,
    PresetNameEmpty,
    PlaylistNameEmpty,
    SmartPlaylistNotFound,
}

/// Localized text for `msg` in the active locale (English fallback).
pub fn tr(msg: Msg) -> String {
    // Argument order: en, tr, es, fr, de, ru, ar, ja, zh, ko.
    let s = match msg {
        Msg::PinFormat => [
            "PIN must be 4–6 digits",
            "PIN 4–6 hane olmalı",
            "El PIN debe tener 4 a 6 dígitos",
            "Le PIN doit comporter 4 à 6 chiffres",
            "PIN muss 4–6 Ziffern haben",
            "PIN должен быть из 4–6 цифр",
            "يجب أن يكون رمز PIN من 4 إلى 6 أرقام",
            "PIN は 4〜6 桁にしてください",
            "PIN 必须为 4–6 位数字",
            "PIN은 4~6자리여야 합니다",
        ],
        Msg::TrackNotFound => [
            "track not found",
            "parça bulunamadı",
            "pista no encontrada",
            "titre introuvable",
            "Titel nicht gefunden",
            "трек не найден",
            "لم يُعثر على المقطع",
            "曲が見つかりません",
            "未找到曲目",
            "트랙을 찾을 수 없습니다",
        ],
        Msg::TrackVanished => [
            "track vanished after edit",
            "parça düzenlemeden sonra kayboldu",
            "la pista desapareció tras la edición",
            "le titre a disparu après modification",
            "Titel ist nach der Bearbeitung verschwunden",
            "трек исчез после редактирования",
            "اختفى المقطع بعد التعديل",
            "編集後に曲が消えました",
            "编辑后曲目消失",
            "편집 후 트랙이 사라졌습니다",
        ],
        Msg::PresetNameEmpty => [
            "preset name cannot be empty",
            "ön ayar adı boş olamaz",
            "el nombre del ajuste no puede estar vacío",
            "le nom du préréglage ne peut pas être vide",
            "Voreinstellungsname darf nicht leer sein",
            "имя пресета не может быть пустым",
            "لا يمكن أن يكون اسم الإعداد فارغًا",
            "プリセット名を空にできません",
            "预设名称不能为空",
            "프리셋 이름은 비울 수 없습니다",
        ],
        Msg::PlaylistNameEmpty => [
            "playlist name cannot be empty",
            "çalma listesi adı boş olamaz",
            "el nombre de la lista no puede estar vacío",
            "le nom de la playlist ne peut pas être vide",
            "Playlist-Name darf nicht leer sein",
            "имя плейлиста не может быть пустым",
            "لا يمكن أن يكون اسم قائمة التشغيل فارغًا",
            "プレイリスト名を空にできません",
            "播放列表名称不能为空",
            "재생목록 이름은 비울 수 없습니다",
        ],
        Msg::SmartPlaylistNotFound => [
            "smart playlist not found",
            "akıllı çalma listesi bulunamadı",
            "lista inteligente no encontrada",
            "playlist intelligente introuvable",
            "Intelligente Playlist nicht gefunden",
            "умный плейлист не найден",
            "لم يُعثر على قائمة التشغيل الذكية",
            "スマートプレイリストが見つかりません",
            "未找到智能播放列表",
            "스마트 재생목록을 찾을 수 없습니다",
        ],
    };
    let idx = match lang().as_str() {
        "tr" => 1,
        "es" => 2,
        "fr" => 3,
        "de" => 4,
        "ru" => 5,
        "ar" => 6,
        "ja" => 7,
        "zh" => 8,
        "ko" => 9,
        _ => 0,
    };
    s[idx].to_string()
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn falls_back_to_english_and_switches() {
        set_locale("");
        assert_eq!(tr(Msg::TrackNotFound), "track not found");
        set_locale("tr");
        assert_eq!(tr(Msg::TrackNotFound), "parça bulunamadı");
        set_locale("pt-BR"); // unknown -> English
        assert_eq!(tr(Msg::TrackNotFound), "track not found");
        set_locale(""); // reset for other tests
    }
}
