mod auto;
mod backend;
mod keys;
mod settings;
mod theme;
mod thumbnail;
mod wallpaper;

use cxx_qt_lib::{QGuiApplication, QQmlApplicationEngine, QString, QUrl};

fn main() {
    if std::env::args().nth(1).as_deref() == Some("--auto") {
        let force = std::env::args().nth(2).as_deref() == Some("--force");
        if let Err(error) = auto::run(force) {
            eprintln!("cupertino-settings: {error}");
            std::process::exit(1);
        }
        return;
    }

    let mut app = QGuiApplication::new();
    let mut engine = QQmlApplicationEngine::new();

    if let Some(mut app) = app.as_mut() {
        app.as_mut()
            .set_application_name(&QString::from("cupertino-settings"));
        app.as_mut()
            .set_application_display_name(&QString::from("Cupertino Settings"));
    }
    QGuiApplication::set_desktop_file_name(&QString::from("cupertino-settings"));

    if let Some(engine) = engine.as_mut() {
        engine.load(&QUrl::from("qrc:/qt/qml/Cupertino/qml/Main.qml"));
    }

    if let Some(app) = app.as_mut() {
        std::process::exit(app.exec());
    }
}
