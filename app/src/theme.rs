use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Colors {
    pub background: String,
    pub foreground: String,
    pub accent: String,
}

pub fn home() -> PathBuf {
    PathBuf::from(std::env::var_os("HOME").unwrap_or_default())
}

fn omarchy_path() -> PathBuf {
    std::env::var_os("OMARCHY_PATH")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from("/usr/share/omarchy"))
}

pub fn current_directory() -> PathBuf {
    home().join(".local/state/omarchy/current/theme")
}

pub fn current_name() -> String {
    fs::read_to_string(home().join(".local/state/omarchy/current/theme.name"))
        .map(|name| name.trim().to_string())
        .unwrap_or_default()
}

fn values(directory: &Path) -> Option<Vec<(String, String)>> {
    let text = fs::read_to_string(directory.join("colors.toml")).ok()?;
    Some(
        text.lines()
            .filter_map(|line| {
                let (key, value) = line.split_once('=')?;
                Some((
                    key.trim().to_string(),
                    value.trim().trim_matches('"').to_string(),
                ))
            })
            .collect(),
    )
}

fn is_hex(value: &str) -> bool {
    value.len() == 7 && value.starts_with('#') && value[1..].chars().all(|c| c.is_ascii_hexdigit())
}

pub fn palette(directory: &Path) -> Vec<(String, String)> {
    values(directory)
        .unwrap_or_default()
        .into_iter()
        .filter(|(_, value)| is_hex(value))
        .collect()
}

pub fn read_colors(directory: &Path) -> Option<Colors> {
    let palette = palette(directory);
    let color = |name: &str| {
        palette
            .iter()
            .find(|(key, _)| key == name)
            .map(|(_, value)| value.clone())
    };
    Some(Colors {
        background: color("background")?,
        foreground: color("foreground")?,
        accent: color("accent")
            .or_else(|| color("blue"))
            .unwrap_or_else(|| "#0a84ff".into()),
    })
}

pub fn luminance(hex: &str) -> Option<f64> {
    if !is_hex(hex) {
        return None;
    }
    let channel = |index: usize| {
        let value = f64::from(u8::from_str_radix(&hex[index..index + 2], 16).ok()?) / 255.0;
        Some(if value <= 0.03928 {
            value / 12.92
        } else {
            ((value + 0.055) / 1.055).powf(2.4)
        })
    };
    Some(0.2126 * channel(1)? + 0.7152 * channel(3)? + 0.0722 * channel(5)?)
}

pub fn is_dark(directory: &Path) -> Option<bool> {
    let values = values(directory)?;
    let value = |name: &str| {
        values
            .iter()
            .find(|(key, _)| key == name)
            .map(|(_, value)| value.as_str())
    };
    match value("mode") {
        Some("dark") => Some(true),
        Some("light") => Some(false),
        _ => luminance(value("background")?).map(|luminance| luminance <= 0.5),
    }
}

pub fn slug(name: &str) -> String {
    name.trim().to_lowercase().replace(' ', "-")
}

pub fn directory(name: &str) -> Option<PathBuf> {
    let slug = slug(name);
    [
        home().join(".config/omarchy/themes").join(&slug),
        omarchy_path().join("themes").join(&slug),
    ]
    .into_iter()
    .find(|path| path.is_dir())
}

pub fn installed() -> Vec<String> {
    Command::new("omarchy-theme-list")
        .output()
        .ok()
        .filter(|output| output.status.success())
        .map(|output| {
            String::from_utf8_lossy(&output.stdout)
                .lines()
                .map(str::trim)
                .filter(|line| !line.is_empty())
                .map(String::from)
                .collect()
        })
        .unwrap_or_default()
}

pub fn with_mode() -> Vec<(String, bool)> {
    installed()
        .into_iter()
        .filter_map(|name| {
            let dark = is_dark(&directory(&name)?)?;
            Some((name, dark))
        })
        .collect()
}

pub fn set_command(slug: &str, keep_wallpaper: bool) -> Command {
    if keep_wallpaper {
        crate::wallpaper::pin(slug);
    }
    let mut command = Command::new("omarchy-theme-set");
    command.arg(slug);
    command
}
