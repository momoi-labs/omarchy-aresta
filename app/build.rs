use cxx_qt_build::{CxxQtBuilder, QmlModule};

fn main() {
    CxxQtBuilder::new_qml_module(QmlModule::new("Cupertino").qml_files([
        "qml/Main.qml",
        "qml/Theme.qml",
        "qml/SettingRow.qml",
        "qml/MacToggle.qml",
        "qml/MacSlider.qml",
        "qml/MacStepper.qml",
        "qml/MacSelect.qml",
        "qml/ShortcutKeys.qml",
        "qml/SectionIcon.qml",
        "qml/ThemeTile.qml",
        "qml/MacSegmented.qml",
        "qml/ThemePicker.qml",
        "qml/RoundedImage.qml",
    ]))
    .qt_module("Quick")
    .files(["src/backend.rs"])
    .build();
}
