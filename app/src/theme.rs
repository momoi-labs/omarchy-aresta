use std::fs;
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::sync::Arc;
use std::sync::atomic::{AtomicU64, Ordering};

pub type Stamp = Vec<(PathBuf, Option<(u64, u64, i64, i64)>)>;

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

fn roots() -> [PathBuf; 2] {
    [
        home().join(".config/omarchy/themes"),
        omarchy_path().join("themes"),
    ]
}

fn directory_in(roots: &[PathBuf], name: &str) -> Option<PathBuf> {
    let slug = slug(name);
    roots
        .iter()
        .map(|root| root.join(&slug))
        .find(|path| path.is_dir())
}

pub fn directory(name: &str) -> Option<PathBuf> {
    directory_in(&roots(), name)
}

fn stamp_in(roots: &[PathBuf]) -> Stamp {
    let mut stamp: Stamp = roots
        .iter()
        .filter_map(|root| fs::read_dir(root).ok())
        .flat_map(|entries| entries.flatten())
        .map(|entry| {
            let colors = fs::metadata(entry.path().join("colors.toml"))
                .map(|meta| (meta.dev(), meta.ino(), meta.ctime(), meta.ctime_nsec()))
                .ok();
            (entry.path(), colors)
        })
        .collect();
    stamp.sort();
    stamp
}

pub fn stamp() -> Stamp {
    stamp_in(&roots())
}

pub fn installed() -> Option<Vec<String>> {
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
}

fn modes_in(roots: &[PathBuf], names: Vec<String>) -> Vec<(String, bool)> {
    names
        .into_iter()
        .filter_map(|name| {
            let dark = is_dark(&directory_in(roots, &name)?)?;
            Some((name, dark))
        })
        .collect()
}

pub fn with_mode() -> Option<Vec<(String, bool)>> {
    Some(modes_in(&roots(), installed()?))
}

#[derive(Debug, PartialEq)]
pub struct Appearance {
    pub auto: bool,
    pub start_auto: bool,
    pub theme: Option<(String, bool)>,
}

pub fn appearance(mode: &str, was_auto: bool, light: &str, dark: &str) -> Appearance {
    let auto = mode == "auto";
    let wants_dark = mode == "dark";
    let theme = (!auto).then(|| {
        let slug = if wants_dark { dark } else { light };
        (slug.to_string(), wants_dark)
    });
    Appearance {
        auto,
        start_auto: auto && !was_auto,
        theme,
    }
}

pub fn newest(requests: &Arc<AtomicU64>) -> impl Fn() -> bool + use<> {
    let requests = requests.clone();
    let mine = requests.fetch_add(1, Ordering::SeqCst) + 1;
    move || requests.load(Ordering::SeqCst) == mine
}

pub fn switch(
    slug: &str,
    command: Command,
    prepare: impl FnOnce(&str) -> bool,
) -> Result<(), String> {
    switch_in(&home(), slug, command, prepare)
}

fn switch_in(
    home: &Path,
    slug: &str,
    mut command: Command,
    prepare: impl FnOnce(&str) -> bool,
) -> Result<(), String> {
    let state = home.join(".local/state/aresta");
    let _lock = fs::create_dir_all(&state)
        .and_then(|()| fs::File::create(state.join("theme-lock")))
        .and_then(|file| file.lock().map(|()| file))
        .map_err(|error| format!("{}: {error}", state.join("theme-lock").display()))?;
    let current = fs::read_to_string(home.join(".local/state/omarchy/current/theme.name"))
        .map(|name| name.trim().to_string())
        .unwrap_or_default();
    if current == slug || !prepare(&current) {
        return Ok(());
    }
    let status = command
        .stdin(Stdio::null())
        .status()
        .map_err(|error| format!("omarchy-theme-set: {error}"))?;
    if status.success() {
        Ok(())
    } else {
        Err(format!("omarchy-theme-set: {status}"))
    }
}

pub fn set_command(slug: &str) -> Command {
    let mut command = Command::new("omarchy-theme-set");
    command.arg(slug);
    command
}

#[cfg(test)]
mod tests {
    use super::*;

    fn scratch(name: &str) -> PathBuf {
        let base = std::env::temp_dir().join(format!("aresta-theme-{name}-{}", std::process::id()));
        let _ = fs::remove_dir_all(&base);
        fs::create_dir_all(&base).unwrap();
        base
    }

    fn names(list: &[&str]) -> Vec<String> {
        list.iter().map(|name| name.to_string()).collect()
    }

    fn switch_from(name: &str, current: &str, slug: &str, go: bool) -> (bool, bool) {
        let home = scratch(name);
        let state = home.join(".local/state/omarchy/current");
        fs::create_dir_all(&state).unwrap();
        fs::write(state.join("theme.name"), format!("{current}\n")).unwrap();
        let mut command = Command::new("touch");
        command.arg(home.join("set"));
        let mut prepared = false;
        let prepare = |_: &str| {
            prepared = true;
            go
        };
        switch_in(&home, slug, command, prepare).unwrap();
        (prepared, home.join("set").exists())
    }

    #[test]
    fn the_theme_already_on_is_not_set_again() {
        assert_eq!(
            switch_from("same", "nosferatu", "nosferatu", true),
            (false, false)
        );
    }

    #[test]
    fn another_theme_gets_its_wallpaper_and_is_set() {
        assert_eq!(
            switch_from("other", "nosferatu-light", "nosferatu", true),
            (true, true)
        );
    }

    #[test]
    fn a_switch_that_is_called_off_under_the_lock_sets_nothing() {
        assert_eq!(
            switch_from("off", "nosferatu-light", "nosferatu", false),
            (true, false)
        );
    }

    #[test]
    fn a_failed_theme_command_is_an_error() {
        let home = scratch("failed");
        let result = switch_in(&home, "nosferatu", Command::new("false"), |_| true);
        assert!(result.is_err());
    }

    #[test]
    fn no_lock_means_no_switch() {
        let home = scratch("lock");
        fs::create_dir_all(home.join(".local/state")).unwrap();
        fs::write(home.join(".local/state/aresta"), "").unwrap();
        let mut command = Command::new("touch");
        command.arg(home.join("set"));
        let mut prepared = false;
        let prepare = |_: &str| {
            prepared = true;
            true
        };
        assert!(switch_in(&home, "nosferatu", command, prepare).is_err());
        assert!(!prepared && !home.join("set").exists());
    }

    #[test]
    fn the_last_choice_wins_over_a_switch_in_progress() {
        let home = scratch("race");
        let state = home.join(".local/state/omarchy/current");
        fs::create_dir_all(&state).unwrap();
        let name = state.join("theme.name");
        fs::write(&name, "day\n").unwrap();
        let set = |slug: &str, wait: &str| {
            let mut command = Command::new("sh");
            command.args(["-c", "sleep $0; echo $1 >$2", wait, slug]);
            command.arg(&name);
            command
        };
        let to_night = set("night", "0.4");
        let first = {
            let home = home.clone();
            std::thread::spawn(move || switch_in(&home, "night", to_night, |_| true))
        };
        std::thread::sleep(std::time::Duration::from_millis(150));
        switch_in(&home, "day", set("day", "0"), |current| current == "night").unwrap();
        first.join().unwrap().unwrap();
        assert_eq!(fs::read_to_string(&name).unwrap().trim(), "day");
    }

    #[test]
    fn an_older_request_that_gets_the_lock_last_sets_nothing() {
        let home = scratch("order");
        let state = home.join(".local/state/omarchy/current");
        fs::create_dir_all(&state).unwrap();
        let name = state.join("theme.name");
        fs::write(&name, "day\n").unwrap();
        let set = |slug: &str| {
            let mut command = Command::new("sh");
            command.args(["-c", "echo $0 >$1", slug]);
            command.arg(&name);
            command
        };
        let requests = Arc::default();
        let to_night = newest(&requests);
        let to_day = newest(&requests);
        switch_in(&home, "day", set("day"), |_| to_day()).unwrap();
        switch_in(&home, "night", set("night"), |_| to_night()).unwrap();
        assert_eq!(fs::read_to_string(&name).unwrap().trim(), "day");
    }

    #[test]
    fn auto_starts_only_when_it_was_off() {
        let start = |mode, was_auto| appearance(mode, was_auto, "day", "night").start_auto;
        assert!(start("auto", false));
        assert!(!start("auto", true));
        assert!(!start("dark", true));
        assert!(!start("light", false));
    }

    #[test]
    fn light_and_dark_leave_auto_and_name_their_theme() {
        let pick = |mode, was_auto| {
            let choice = appearance(mode, was_auto, "day", "night");
            (choice.auto, choice.theme)
        };
        for was_auto in [false, true] {
            assert_eq!(
                pick("dark", was_auto),
                (false, Some(("night".to_string(), true)))
            );
            assert_eq!(
                pick("light", was_auto),
                (false, Some(("day".to_string(), false)))
            );
            assert_eq!(pick("auto", was_auto), (true, None));
        }
    }

    #[test]
    fn lists_a_theme_only_once_its_colors_exist() {
        let base = scratch("modes");
        let roots = [base.join("user"), base.join("system")];
        fs::create_dir_all(roots[1].join("day")).unwrap();
        fs::write(roots[1].join("day/colors.toml"), "mode = \"light\"\n").unwrap();
        fs::create_dir_all(roots[0].join("tokyo-night")).unwrap();

        let listed = names(&["Day", "Tokyo Night"]);
        assert_eq!(
            modes_in(&roots, listed.clone()),
            [("Day".to_string(), false)]
        );

        fs::write(
            roots[0].join("tokyo-night/colors.toml"),
            "background = \"#1a1b26\"\n",
        )
        .unwrap();
        assert_eq!(
            modes_in(&roots, listed.clone()),
            [
                ("Day".to_string(), false),
                ("Tokyo Night".to_string(), true)
            ]
        );

        fs::remove_dir_all(roots[0].join("tokyo-night")).unwrap();
        assert_eq!(modes_in(&roots, listed), [("Day".to_string(), false)]);
        fs::remove_dir_all(&base).unwrap();
    }

    #[test]
    fn stamp_changes_when_a_theme_is_added_filled_or_removed() {
        let base = scratch("stamp");
        let roots = [base.join("user"), base.join("system")];
        let empty = stamp_in(&roots);
        assert!(empty.is_empty());

        fs::create_dir_all(roots[0].join("night")).unwrap();
        let added = stamp_in(&roots);
        assert_eq!(added, [(roots[0].join("night"), None)]);
        assert_eq!(stamp_in(&roots), added);

        fs::write(roots[0].join("night/colors.toml"), "mode = \"dark\"\n").unwrap();
        let filled = stamp_in(&roots);
        assert_ne!(filled, added);

        fs::rename(roots[0].join("night"), base.join("spare")).unwrap();
        std::os::unix::fs::symlink(base.join("spare"), roots[0].join("night")).unwrap();
        let linked = stamp_in(&roots);
        assert_eq!(linked[0].0, roots[0].join("night"));
        assert_eq!(linked[0].1, filled[0].1);

        fs::create_dir_all(base.join("other")).unwrap();
        fs::write(base.join("other/colors.toml"), "mode = \"light\"\n").unwrap();
        fs::remove_file(roots[0].join("night")).unwrap();
        std::os::unix::fs::symlink(base.join("other"), roots[0].join("night")).unwrap();
        assert_ne!(stamp_in(&roots)[0].1, linked[0].1);

        fs::remove_file(roots[0].join("night")).unwrap();
        assert_eq!(stamp_in(&roots), empty);
        fs::remove_dir_all(&base).unwrap();
    }
}
