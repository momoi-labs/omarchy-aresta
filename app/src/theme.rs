use std::fs;
use std::path::{Path, PathBuf};
use std::process::Command;

#[derive(Clone, Debug, Default, PartialEq)]
pub struct Colors {
    pub background: String,
    pub foreground: String,
    pub accent: String,
}

fn home() -> PathBuf {
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

pub fn read_colors(directory: &Path) -> Option<Colors> {
    let text = fs::read_to_string(directory.join("colors.toml")).ok()?;
    let color = |name: &str| {
        text.lines().find_map(|line| {
            let (key, value) = line.split_once('=')?;
            if key.trim() != name {
                return None;
            }
            let value = value.trim().trim_matches('"');
            (value.len() == 7 && value.starts_with('#')).then(|| value.to_string())
        })
    };
    Some(Colors {
        background: color("background")?,
        foreground: color("foreground")?,
        accent: color("accent")
            .or_else(|| color("blue"))
            .unwrap_or_else(|| "#0a84ff".into()),
    })
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

pub fn preview(name: &str) -> Option<PathBuf> {
    directory(name)
        .map(|directory| directory.join("preview.png"))
        .filter(|path| path.is_file())
}
