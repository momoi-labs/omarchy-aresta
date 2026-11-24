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
        #[cxx_name = "selectTheme"]
        fn select_theme(self: Pin<&mut Self>, name: &QString);

        #[qinvokable]
        #[cxx_name = "themeSlug"]
        fn theme_slug(&self, name: &QString) -> QString;

        #[qinvokable]
        #[cxx_name = "themePreview"]
        fn theme_preview(&self, name: &QString) -> QString;

        #[qinvokable]
        #[cxx_name = "themeColors"]
        fn theme_colors(&self, name: &QString) -> QStringList;
    }

    impl cxx_qt::Initialize for Backend {}
}

use crate::keys;
use crate::settings::{Settings, Value};
use crate::theme;
use core::pin::Pin;
use cxx_qt::CxxQtType;
use cxx_qt_lib::{QString, QStringList};
use std::fs;
use std::path::Path;
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
    settings: Settings,
    settings_stamp: Option<SystemTime>,
    colors_stamp: Option<SystemTime>,
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
            settings: Settings::load(),
            settings_stamp: modified(&Settings::path()),
            colors_stamp: None,
            reload_at: None,
        }
    }
}

fn modified(path: &Path) -> Option<SystemTime> {
    fs::metadata(path).and_then(|meta| meta.modified()).ok()
}

fn spawn(program: &str, args: &[&str]) -> Result<(), String> {
    let mut child = Command::new(program)
        .args(args)
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
        let themes: QStringList = theme::installed().iter().map(QString::from).collect();
        self.as_mut().set_themes(themes);
        self.as_mut().refresh_theme();
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

    pub fn select_theme(mut self: Pin<&mut Self>, name: &QString) {
        let result = spawn("omarchy-theme-set", &[&name.to_string()]);
        self.as_mut().report(result);
    }

    pub fn theme_slug(&self, name: &QString) -> QString {
        QString::from(&theme::slug(&name.to_string()))
    }

    pub fn theme_preview(&self, name: &QString) -> QString {
        theme::preview(&name.to_string())
            .map(|path| QString::from(&format!("file://{}", path.display())))
            .unwrap_or_default()
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
}
