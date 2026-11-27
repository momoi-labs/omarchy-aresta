use std::fs;
use std::io;
use std::path::{Path, PathBuf};

use crate::theme;

const IMAGES: [&str; 6] = ["jpg", "jpeg", "png", "gif", "bmp", "webp"];

pub struct Source {
    pub title: String,
    pub detail: String,
    pub path: PathBuf,
}

fn state() -> PathBuf {
    theme::home().join(".local/state/omarchy")
}

pub fn user_root() -> PathBuf {
    theme::home().join(".config/omarchy/backgrounds")
}

fn bundled(path: &Path) -> Option<PathBuf> {
    let staged = state().join("current/theme/backgrounds");
    let file = path.strip_prefix(&staged).ok()?;
    Some(
        theme::directory(&theme::current_name())?
            .join("backgrounds")
            .join(file),
    )
}

pub fn current() -> Option<PathBuf> {
    let path = fs::canonicalize(state().join("current/background")).ok()?;
    Some(bundled(&path).unwrap_or(path))
}

pub fn pin(slug: &str) {
    let Some(path) = fs::canonicalize(state().join("current/background")).ok() else {
        return;
    };
    let path = match bundled(&path) {
        Some(_) if theme::current_name().starts_with("aresta-") && slug.starts_with("aresta-") => {
            path
        }
        Some(source) => source,
        None => path,
    };
    if !path.is_file() || slug.is_empty() || slug.contains('/') {
        return;
    }
    let directory = state().join("theme-backgrounds");
    if fs::create_dir_all(&directory).is_ok() {
        let _ = fs::write(directory.join(slug), format!("{}\n", path.display()));
    }
}

pub fn images(directory: &Path) -> Vec<PathBuf> {
    let mut images: Vec<PathBuf> = fs::read_dir(directory)
        .map(|entries| {
            entries
                .filter_map(Result::ok)
                .map(|entry| entry.path())
                .filter(|path| {
                    path.is_file()
                        && path
                            .extension()
                            .and_then(|extension| extension.to_str())
                            .is_some_and(|extension| {
                                IMAGES.contains(&extension.to_lowercase().as_str())
                            })
                })
                .collect()
        })
        .unwrap_or_default();
    images.sort();
    images
}

pub fn sources(theme_title: &str, folders: &[String]) -> Vec<Source> {
    let slug = theme::current_name();
    let mut sources = Vec::new();
    if let Some(directory) = theme::directory(&slug) {
        sources.push(Source {
            title: theme_title.to_string(),
            detail: "from the theme".into(),
            path: directory.join("backgrounds"),
        });
    }
    let root = user_root();
    sources.push(Source {
        title: format!("Yours for {theme_title}"),
        detail: String::new(),
        path: root.join(&slug),
    });
    let mut others: Vec<PathBuf> = fs::read_dir(&root)
        .map(|entries| {
            entries
                .filter_map(Result::ok)
                .map(|entry| entry.path())
                .filter(|path| path.is_dir() && !path.ends_with(&slug))
                .collect()
        })
        .unwrap_or_default();
    others.sort();
    others.extend(folders.iter().map(PathBuf::from));
    sources.extend(others.into_iter().map(|path| Source {
        title: "Folder".into(),
        detail: String::new(),
        path,
    }));
    sources
}

pub fn add_photo(file: &Path) -> io::Result<PathBuf> {
    let name = file
        .file_name()
        .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidInput, "no file name"))?;
    let directory = user_root().join(theme::current_name());
    fs::create_dir_all(&directory)?;
    let target = directory.join(name);
    if target.exists() && fs::canonicalize(file)? == fs::canonicalize(&target)? {
        return Ok(target);
    }
    fs::copy(file, &target)?;
    Ok(target)
}
