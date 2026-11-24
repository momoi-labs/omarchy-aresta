#[cxx_qt::bridge]
pub mod qobject {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        include!("cxx-qt-lib/qstringlist.h");
        type QStringList = cxx_qt_lib::QStringList;
    }

    extern "RustQt" {
        #[qobject]
        #[qml_element]
        #[qproperty(QString, background)]
        #[qproperty(QString, foreground)]
        #[qproperty(QString, accent)]
        #[qproperty(QString, theme_name, cxx_name = "themeName")]
        #[qproperty(QStringList, themes)]
        #[qproperty(i32, revision)]
        #[qproperty(QString, recording)]
        #[qproperty(QString, error)]
        #[qproperty(QString, current_wallpaper, cxx_name = "currentWallpaper")]
        #[qproperty(f64, auto_next, cxx_name = "autoNext")]
        #[qproperty(bool, auto_next_dark, cxx_name = "autoNextDark")]
        #[qproperty(QString, auto_error, cxx_name = "autoError")]
        type Backend = super::BackendRust;

        #[qinvokable]
        fn tick(self: Pin<&mut Self>);

        #[qinvokable]
        fn number(&self, key: &QString) -> f64;

        #[qinvokable]
        fn flag(&self, key: &QString) -> bool;

        #[qinvokable]
        fn text(&self, key: &QString) -> QString;

        #[qinvokable]
        #[cxx_name = "setNumber"]
        fn set_number(self: Pin<&mut Self>, key: &QString, value: f64);

        #[qinvokable]
        #[cxx_name = "setFlag"]
        fn set_flag(self: Pin<&mut Self>, key: &QString, value: bool);

        #[qinvokable]
        #[cxx_name = "setText"]
        fn set_text(self: Pin<&mut Self>, key: &QString, value: &QString);

        #[qinvokable]
        #[cxx_name = "shortcutLabels"]
        fn shortcut_labels(&self, key: &QString) -> QStringList;

        #[qinvokable]
        #[cxx_name = "startRecording"]
        fn start_recording(self: Pin<&mut Self>, key: &QString);

        #[qinvokable]
        #[cxx_name = "stopRecording"]
        fn stop_recording(self: Pin<&mut Self>);

        #[qinvokable]
        fn record(self: Pin<&mut Self>, modifiers: u32, keycode: i32) -> bool;

        #[qinvokable]
        #[cxx_name = "clearShortcut"]
        fn clear_shortcut(self: Pin<&mut Self>);

        #[qinvokable]
        #[cxx_name = "themeSlug"]
        fn theme_slug(&self, name: &QString) -> QString;

        #[qinvokable]
        #[cxx_name = "themeTitle"]
        fn theme_title(&self, slug: &QString) -> QString;

        #[qinvokable]
        #[cxx_name = "themeNames"]
        fn theme_names(&self, dark: bool) -> QStringList;

        #[qinvokable]
        #[cxx_name = "themeDark"]
        fn theme_dark(&self, name: &QString) -> bool;

        #[qinvokable]
        #[cxx_name = "themeColors"]
        fn theme_colors(&self, name: &QString) -> QStringList;

        #[qinvokable]
        #[cxx_name = "themePalette"]
        fn theme_palette(&self, name: &QString) -> QStringList;

        #[qinvokable]
        #[cxx_name = "themeLuminance"]
        fn theme_luminance(&self, name: &QString) -> f64;

        #[qinvokable]
        #[cxx_name = "themeFile"]
        fn theme_file(&self, name: &QString) -> QString;

        #[qinvokable]
        #[cxx_name = "setAppearance"]
        fn set_appearance(self: Pin<&mut Self>, mode: &QString);

        #[qinvokable]
        #[cxx_name = "pickTheme"]
        fn pick_theme(self: Pin<&mut Self>, dark: bool, name: &QString);

        #[qinvokable]
        #[cxx_name = "wallpaperSources"]
        fn wallpaper_sources(&self) -> QStringList;

        #[qinvokable]
        #[cxx_name = "wallpaperImages"]
        fn wallpaper_images(&self, path: &QString) -> QStringList;

        #[qinvokable]
        #[cxx_name = "setWallpaper"]
        fn set_wallpaper(self: Pin<&mut Self>, path: &QString);

        #[qinvokable]
        #[cxx_name = "addPhoto"]
        fn add_photo(self: Pin<&mut Self>, path: &QString);

        #[qinvokable]
        #[cxx_name = "addFolder"]
        fn add_folder(self: Pin<&mut Self>, path: &QString);

        #[qinvokable]
        #[cxx_name = "shortPath"]
        fn short_path(&self, path: &QString) -> QString;
    }

    impl cxx_qt::Initialize for Backend {}
}

use crate::auto;
use crate::keys;
use crate::settings::{Settings, Value};
use crate::theme;
use crate::wallpaper;
use core::pin::Pin;
use cxx_qt::CxxQtType;
use cxx_qt_lib::{QString, QStringList};
use std::fs;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};
use std::time::{Duration, Instant, SystemTime};

const RELOAD_DELAY: Duration = Duration::from_millis(250);
const RECORD_SUBMAP: &str = "omarchy-cupertino-record";

pub struct BackendRust {
    background: QString,
    foreground: QString,
    accent: QString,
    theme_name: QString,
    themes: QStringList,
    revision: i32,
    recording: QString,
    error: QString,
    current_wallpaper: QString,
    auto_next: f64,
    auto_next_dark: bool,
    auto_error: QString,
    modes: Vec<(String, bool)>,
    settings: Settings,
    settings_stamp: Option<SystemTime>,
    colors_stamp: Option<SystemTime>,
    auto_stamp: Option<SystemTime>,
    reload_at: Option<Instant>,
}

impl Default for BackendRust {
    fn default() -> Self {
        Self {
            background: QString::from("#1e1e1e"),
            foreground: QString::from("#dddddd"),
            accent: QString::from("#0a84ff"),
            theme_name: QString::default(),
            themes: QStringList::default(),
            revision: 0,
            recording: QString::default(),
            error: QString::default(),
            current_wallpaper: QString::default(),
            auto_next: 0.0,
            auto_next_dark: false,
            auto_error: QString::default(),
            modes: Vec::new(),
            settings: Settings::load(),
            settings_stamp: modified(&Settings::path()),
            colors_stamp: None,
            auto_stamp: None,
            reload_at: None,
        }
    }
}

fn modified(path: &Path) -> Option<SystemTime> {
    fs::metadata(path).and_then(|meta| meta.modified()).ok()
}

fn spawn(program: &str, args: &[&str]) -> Result<(), String> {
    let mut command = Command::new(program);
    command.args(args);
    run_detached(command, program)
}

fn run_detached(mut command: Command, program: &str) -> Result<(), String> {
    let mut child = command
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .spawn()
        .map_err(|error| format!("{program}: {error}"))?;
    std::thread::spawn(move || child.wait());
    Ok(())
}

fn hyprctl_dispatch(expression: &str) -> Result<(), String> {
    spawn("hyprctl", &["dispatch", expression])
}

impl cxx_qt::Initialize for qobject::Backend {
    fn initialize(mut self: Pin<&mut Self>) {
        let modes = theme::with_mode();
        let themes: QStringList = modes.iter().map(|(name, _)| QString::from(name)).collect();
        self.as_mut().rust_mut().modes = modes;
        self.as_mut().set_themes(themes);
        self.as_mut().refresh_theme();
        self.as_mut().refresh_wallpaper();
        self.as_mut().refresh_auto();
    }
}

impl qobject::Backend {
    fn report(mut self: Pin<&mut Self>, result: Result<(), String>) {
        let message = result.err().unwrap_or_default();
        self.as_mut().set_error(QString::from(&message));
    }

    fn refresh_theme(mut self: Pin<&mut Self>) {
        let directory = theme::current_directory();
        let stamp = modified(&directory.join("colors.toml"));
        let name = QString::from(&theme::current_name());
        if *self.theme_name() != name {
            self.as_mut().set_theme_name(name);
        }
        if stamp == self.colors_stamp {
            return;
        }
        self.as_mut().rust_mut().colors_stamp = stamp;
        if let Some(colors) = theme::read_colors(&directory) {
            self.as_mut()
                .set_background(QString::from(&colors.background));
            self.as_mut()
                .set_foreground(QString::from(&colors.foreground));
            self.as_mut().set_accent(QString::from(&colors.accent));
        }
    }

    fn refresh_wallpaper(mut self: Pin<&mut Self>) {
        let path = wallpaper::current()
            .map(|path| QString::from(&path.display().to_string()))
            .unwrap_or_default();
        if *self.current_wallpaper() != path {
            self.as_mut().set_current_wallpaper(path);
        }
    }

    fn refresh_auto(mut self: Pin<&mut Self>) {
        let stamp = modified(&auto::status_path());
        if stamp == self.auto_stamp {
            return;
        }
        self.as_mut().rust_mut().auto_stamp = stamp;
        let text = fs::read_to_string(auto::status_path()).unwrap_or_default();
        let field = |name: &str| {
            text.lines()
                .find_map(|line| line.strip_prefix(name)?.strip_prefix('='))
                .unwrap_or_default()
                .to_string()
        };
        let next = field("next").parse::<f64>().unwrap_or_default() * 1000.0;
        self.as_mut().set_auto_next(next);
        self.as_mut()
            .set_auto_next_dark(field("next_dark") == "true");
        self.as_mut().set_auto_error(QString::from(&field("error")));
    }

    fn slug_of(&self, key: &str) -> String {
        match self.settings.get(key) {
            Some(Value::Text(slug)) => slug.clone(),
            _ => String::new(),
        }
    }

    fn apply_theme(mut self: Pin<&mut Self>, slug: &str) {
        let keep = matches!(self.settings.get("wallpaper_keep"), Some(Value::Flag(true)));
        if keep {
            wallpaper::pin(slug);
        }
        let command = theme::set_command(slug);
        let result = run_detached(command, "omarchy-theme-set");
        self.as_mut().report(result);
    }

    fn run_auto(mut self: Pin<&mut Self>) {
        let _ = fs::remove_file(auto::transition_path());
        let result = std::env::current_exe()
            .map_err(|error| error.to_string())
            .and_then(|exe| {
                let mut command = Command::new(exe);
                command.arg("--auto");
                run_detached(command, "cupertino-settings --auto")
            });
        self.as_mut().report(result);
    }

    fn bump(mut self: Pin<&mut Self>) {
        let next = self.revision().wrapping_add(1);
        self.as_mut().set_revision(next);
    }

    fn store(mut self: Pin<&mut Self>, key: &QString, value: Value) {
        let Some(hyprland) = self
            .as_mut()
            .rust_mut()
            .settings
            .set(&key.to_string(), value)
        else {
            return;
        };
        let saved = self
            .settings
            .save()
            .map_err(|error| format!("Could not save {}: {error}", Settings::path().display()));
        if saved.is_ok() {
            let stamp = modified(&Settings::path());
            self.as_mut().rust_mut().settings_stamp = stamp;
            if hyprland {
                self.as_mut().rust_mut().reload_at = Some(Instant::now() + RELOAD_DELAY);
            }
        }
        self.as_mut().report(saved);
        self.bump();
    }

    pub fn tick(mut self: Pin<&mut Self>) {
        self.as_mut().refresh_theme();
        self.as_mut().refresh_wallpaper();
        self.as_mut().refresh_auto();

        let stamp = modified(&Settings::path());
        if stamp != self.settings_stamp {
            self.as_mut().rust_mut().settings_stamp = stamp;
            self.as_mut().rust_mut().settings.reload();
            self.as_mut().bump();
        }

        if self.reload_at.is_some_and(|at| Instant::now() >= at) {
            self.as_mut().rust_mut().reload_at = None;
            let result = spawn("hyprctl", &["reload"]);
            self.report(result);
        }
    }

    pub fn number(&self, key: &QString) -> f64 {
        match self.settings.get(&key.to_string()) {
            Some(Value::Number(number)) => *number,
            _ => 0.0,
        }
    }

    pub fn flag(&self, key: &QString) -> bool {
        matches!(self.settings.get(&key.to_string()), Some(Value::Flag(true)))
    }

    pub fn text(&self, key: &QString) -> QString {
        match self.settings.get(&key.to_string()) {
            Some(Value::Text(text)) => QString::from(text),
            _ => QString::default(),
        }
    }

    pub fn set_number(self: Pin<&mut Self>, key: &QString, value: f64) {
        let rounded = (value * 10.0).round() / 10.0;
        self.store(key, Value::Number(rounded));
    }

    pub fn set_flag(self: Pin<&mut Self>, key: &QString, value: bool) {
        self.store(key, Value::Flag(value));
    }

    pub fn set_text(self: Pin<&mut Self>, key: &QString, value: &QString) {
        self.store(key, Value::Text(value.to_string()));
    }

    pub fn shortcut_labels(&self, key: &QString) -> QStringList {
        match self.settings.get(&key.to_string()) {
            Some(Value::Text(binding)) => keys::labels(binding).iter().map(QString::from).collect(),
            _ => QStringList::default(),
        }
    }

    pub fn start_recording(mut self: Pin<&mut Self>, key: &QString) {
        let result = hyprctl_dispatch(&format!("hl.dsp.submap(\"{RECORD_SUBMAP}\")"));
        self.as_mut().report(result);
        self.set_recording(key.clone());
    }

    pub fn stop_recording(mut self: Pin<&mut Self>) {
        if self.recording().is_empty() {
            return;
        }
        let result = hyprctl_dispatch("hl.dsp.submap(\"reset\")");
        self.as_mut().report(result);
        self.set_recording(QString::default());
    }

    pub fn record(mut self: Pin<&mut Self>, modifiers: u32, keycode: i32) -> bool {
        let key = self.recording().clone();
        if key.is_empty() {
            return false;
        }
        let Some(binding) = keys::binding(modifiers, keycode) else {
            return false;
        };
        if self.settings.shortcut_in_use(&binding, &key.to_string()) {
            let labels = keys::labels(&binding).join("+");
            self.as_mut()
                .set_error(QString::from(&format!("{labels} is already in use")));
            return false;
        }
        self.as_mut().stop_recording();
        self.store(&key, Value::Text(binding));
        true
    }

    pub fn clear_shortcut(mut self: Pin<&mut Self>) {
        let key = self.recording().clone();
        if key.is_empty() {
            return;
        }
        self.as_mut().stop_recording();
        self.store(&key, Value::Text(String::new()));
    }

    pub fn theme_slug(&self, name: &QString) -> QString {
        QString::from(&theme::slug(&name.to_string()))
    }

    pub fn theme_title(&self, slug: &QString) -> QString {
        let slug = slug.to_string();
        self.modes
            .iter()
            .find(|(name, _)| theme::slug(name) == slug)
            .map(|(name, _)| QString::from(name))
            .unwrap_or_else(|| QString::from(&slug))
    }

    pub fn theme_names(&self, dark: bool) -> QStringList {
        let default = if dark { "osx-dark" } else { "osx-light" };
        let mut names: Vec<&String> = self
            .modes
            .iter()
            .filter(|(_, mode)| *mode == dark)
            .map(|(name, _)| name)
            .collect();
        names.sort_by_key(|name| theme::slug(name) != default);
        names.into_iter().map(QString::from).collect()
    }

    pub fn theme_dark(&self, name: &QString) -> bool {
        let slug = theme::slug(&name.to_string());
        self.modes
            .iter()
            .find(|(name, _)| theme::slug(name) == slug)
            .map(|(_, dark)| *dark)
            .or_else(|| theme::directory(&slug).and_then(|directory| theme::is_dark(&directory)))
            .unwrap_or(true)
    }

    pub fn theme_colors(&self, name: &QString) -> QStringList {
        theme::directory(&name.to_string())
            .and_then(|directory| theme::read_colors(&directory))
            .map(|colors| {
                [colors.background, colors.foreground, colors.accent]
                    .iter()
                    .map(QString::from)
                    .collect()
            })
            .unwrap_or_default()
    }

    pub fn theme_palette(&self, name: &QString) -> QStringList {
        theme::directory(&name.to_string())
            .map(|directory| {
                theme::palette(&directory)
                    .iter()
                    .map(|(key, value)| QString::from(&format!("{key}|{value}")))
                    .collect()
            })
            .unwrap_or_default()
    }

    pub fn theme_luminance(&self, name: &QString) -> f64 {
        theme::directory(&name.to_string())
            .and_then(|directory| theme::read_colors(&directory))
            .and_then(|colors| theme::luminance(&colors.background))
            .unwrap_or_default()
    }

    pub fn theme_file(&self, name: &QString) -> QString {
        theme::directory(&name.to_string())
            .map(|directory| {
                let path = directory.join("colors.toml").display().to_string();
                self.short_path(&QString::from(&path))
            })
            .unwrap_or_default()
    }

    pub fn set_appearance(mut self: Pin<&mut Self>, mode: &QString) {
        let mode = mode.to_string();
        let auto = mode == "auto";
        self.as_mut()
            .store(&QString::from("appearance_auto"), Value::Flag(auto));
        if auto {
            self.run_auto();
            return;
        }
        let key = if mode == "dark" {
            "dark_theme"
        } else {
            "light_theme"
        };
        let slug = self.slug_of(key);
        self.apply_theme(&slug);
    }

    pub fn pick_theme(mut self: Pin<&mut Self>, dark: bool, name: &QString) {
        let slug = theme::slug(&name.to_string());
        let key = if dark { "dark_theme" } else { "light_theme" };
        self.as_mut()
            .store(&QString::from(key), Value::Text(slug.clone()));
        let current = self.theme_name().clone();
        if self.theme_dark(&current) == dark && current.to_string() != slug {
            self.apply_theme(&slug);
        }
    }

    pub fn wallpaper_sources(&self) -> QStringList {
        let folders = match self.settings.get("wallpaper_folders") {
            Some(Value::List(folders)) => folders.clone(),
            _ => Vec::new(),
        };
        let title = self.theme_title(&QString::from(&theme::current_name()));
        wallpaper::sources(&title.to_string(), &folders)
            .iter()
            .map(|source| {
                QString::from(&format!(
                    "{}\t{}\t{}",
                    source.title,
                    source.detail,
                    source.path.display()
                ))
            })
            .collect()
    }

    pub fn wallpaper_images(&self, path: &QString) -> QStringList {
        wallpaper::images(Path::new(&path.to_string()))
            .iter()
            .map(|image| QString::from(&image.display().to_string()))
            .collect()
    }

    pub fn set_wallpaper(mut self: Pin<&mut Self>, path: &QString) {
        let result = spawn("omarchy-theme-bg-set", &[&path.to_string()]);
        self.as_mut().report(result);
    }

    pub fn add_photo(mut self: Pin<&mut Self>, path: &QString) {
        let result = wallpaper::add_photo(Path::new(&path.to_string()))
            .map(|_| ())
            .map_err(|error| format!("Could not add the photo: {error}"));
        self.as_mut().report(result);
        self.bump();
    }

    pub fn add_folder(self: Pin<&mut Self>, path: &QString) {
        let path = path.to_string();
        let mut folders = match self.settings.get("wallpaper_folders") {
            Some(Value::List(folders)) => folders.clone(),
            _ => Vec::new(),
        };
        if path.is_empty() || folders.contains(&path) {
            return;
        }
        folders.push(path);
        self.store(&QString::from("wallpaper_folders"), Value::List(folders));
    }

    pub fn short_path(&self, path: &QString) -> QString {
        let path = PathBuf::from(path.to_string());
        let shown = path
            .strip_prefix(theme::home())
            .map(|rest| format!("~/{}", rest.display()))
            .unwrap_or_else(|_| path.display().to_string());
        QString::from(&shown)
    }
}
