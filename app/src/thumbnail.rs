use std::collections::HashSet;
use std::fs::{self, DirBuilder, File, OpenOptions};
use std::io::{BufReader, BufWriter};
use std::os::unix::fs::{DirBuilderExt, OpenOptionsExt};
use std::path::{Path, PathBuf};
use std::sync::mpsc::{self, Receiver, Sender};
use std::sync::{Arc, Mutex};
use std::time::UNIX_EPOCH;

use crate::theme;

type Job = (PathBuf, u32, u64);

const WORKERS: usize = 3;

fn root() -> PathBuf {
    std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .filter(|path| path.is_absolute())
        .unwrap_or_else(|| theme::home().join(".cache"))
        .join("thumbnails")
}

fn folder(size: u32) -> &'static str {
    match size {
        0..=128 => "normal",
        129..=256 => "large",
        257..=512 => "x-large",
        _ => "xx-large",
    }
}

fn limit(size: u32) -> u32 {
    match folder(size) {
        "normal" => 128,
        "large" => 256,
        "x-large" => 512,
        _ => 1024,
    }
}

fn escape(path: &Path) -> String {
    let mut text = String::new();
    for byte in path.as_os_str().as_encoded_bytes() {
        match byte {
            b'A'..=b'Z' | b'a'..=b'z' | b'0'..=b'9' => text.push(*byte as char),
            b'-' | b'_' | b'.' | b'~' | b'!' | b'$' | b'&' | b'\'' | b'(' | b')' | b'*' | b'+'
            | b',' | b'/' | b':' | b'=' | b'@' => text.push(*byte as char),
            _ => text.push_str(&format!("%{byte:02X}")),
        }
    }
    text
}

pub fn uri(path: &Path) -> String {
    format!("file://{}", escape(path))
}

fn file(path: &Path, size: u32) -> PathBuf {
    root()
        .join(folder(size))
        .join(format!("{:x}.png", md5::compute(uri(path))))
}

fn stamp(path: &Path) -> Option<(u64, u64)> {
    let meta = fs::metadata(path).ok()?;
    let mtime = meta.modified().ok()?.duration_since(UNIX_EPOCH).ok()?;
    Some((mtime.as_secs(), meta.len()))
}

fn valid(thumb: &Path, uri: &str, mtime: u64) -> bool {
    let Ok(file) = File::open(thumb) else {
        return false;
    };
    let Ok(reader) = png::Decoder::new(BufReader::new(file)).read_info() else {
        return false;
    };
    let text = &reader.info().uncompressed_latin1_text;
    let value = |key: &str| {
        text.iter()
            .find(|chunk| chunk.keyword == key)
            .map(|chunk| chunk.text.as_str())
    };
    value("Thumb::URI") == Some(uri) && value("Thumb::MTime") == Some(&mtime.to_string())
}

pub fn cached(path: &Path, size: u32) -> Result<String, Option<u64>> {
    let Some((mtime, _)) = stamp(path) else {
        return Err(None);
    };
    let thumb = file(path, size);
    if valid(&thumb, &uri(path), mtime) {
        Ok(format!("{}?{mtime}", uri(&thumb)))
    } else {
        Err(Some(mtime))
    }
}

fn generate(path: &Path, size: u32) -> Result<(), String> {
    let (mtime, length) = stamp(path).ok_or("no such file")?;
    let image = image::ImageReader::open(path)
        .and_then(|reader| reader.with_guessed_format())
        .map_err(|error| error.to_string())?
        .decode()
        .map_err(|error| error.to_string())?;
    let (width, height) = (image.width(), image.height());
    let edge = limit(size);
    let small = match width.max(height) > edge {
        true => image.thumbnail(edge, edge),
        false => image,
    }
    .into_rgba8();

    let thumb = file(path, size);
    let directory = thumb.parent().ok_or("no cache folder")?;
    DirBuilder::new()
        .recursive(true)
        .mode(0o700)
        .create(directory)
        .map_err(|error| error.to_string())?;
    let temporary = directory.join(format!(
        ".{}.{}",
        thumb.file_name().unwrap_or_default().display(),
        std::process::id()
    ));
    let output = OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .mode(0o600)
        .open(&temporary)
        .map_err(|error| error.to_string())?;
    let mut encoder = png::Encoder::new(BufWriter::new(output), small.width(), small.height());
    encoder.set_color(png::ColorType::Rgba);
    encoder.set_depth(png::BitDepth::Eight);
    let text = [
        ("Thumb::URI", uri(path)),
        ("Thumb::MTime", mtime.to_string()),
        ("Thumb::Size", length.to_string()),
        ("Thumb::Image::Width", width.to_string()),
        ("Thumb::Image::Height", height.to_string()),
        ("Software", "aresta-settings".to_string()),
    ];
    let written = text
        .into_iter()
        .try_for_each(|(key, value)| encoder.add_text_chunk(key.to_string(), value))
        .and_then(|_| encoder.write_header())
        .and_then(|mut writer| {
            writer.write_image_data(small.as_raw())?;
            writer.finish()
        })
        .map_err(|error| error.to_string())
        .and_then(|_| fs::rename(&temporary, &thumb).map_err(|error| error.to_string()));
    if written.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    written
}

#[derive(Default)]
pub struct Queue {
    jobs: Mutex<Option<Sender<Job>>>,
    asked: Arc<Mutex<HashSet<Job>>>,
}

impl Queue {
    pub fn request<F>(&self, path: &Path, size: u32, mtime: u64, done: F)
    where
        F: Fn() + Clone + Send + 'static,
    {
        let job = (path.to_path_buf(), size, mtime);
        let Ok(mut asked) = self.asked.lock() else {
            return;
        };
        if !asked.insert(job.clone()) {
            return;
        }
        let Ok(mut jobs) = self.jobs.lock() else {
            asked.remove(&job);
            return;
        };
        let sender = jobs.get_or_insert_with(|| start(Arc::clone(&self.asked), done));
        if sender.send(job.clone()).is_err() {
            asked.remove(&job);
        }
    }
}

fn start<F>(asked: Arc<Mutex<HashSet<Job>>>, done: F) -> Sender<Job>
where
    F: Fn() + Clone + Send + 'static,
{
    let (sender, receiver) = mpsc::channel::<Job>();
    let receiver = Arc::new(Mutex::new(receiver));
    for _ in 0..WORKERS {
        let receiver: Arc<Mutex<Receiver<Job>>> = Arc::clone(&receiver);
        let done = done.clone();
        let asked = Arc::clone(&asked);
        std::thread::spawn(move || {
            loop {
                let job = match receiver.lock() {
                    Ok(receiver) => receiver.recv(),
                    Err(_) => return,
                };
                let Ok(job) = job else {
                    return;
                };
                let made = generate(&job.0, job.1).is_ok();
                if let Ok(mut asked) = asked.lock() {
                    asked.remove(&job);
                }
                if made {
                    done();
                }
            }
        });
    }
    sender
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::sync::atomic::{AtomicUsize, Ordering};
    use std::time::{Duration, Instant};

    static ENV_LOCK: Mutex<()> = Mutex::new(());

    #[test]
    fn escapes_like_glib() {
        assert_eq!(
            uri(Path::new("/home/a b/ç#%?;x.png")),
            "file:///home/a%20b/%C3%A7%23%25%3F%3Bx.png"
        );
    }

    #[test]
    fn writes_a_thumbnail_that_passes_the_checks() {
        let _guard = ENV_LOCK.lock().unwrap();
        let base = std::env::temp_dir().join(format!("aresta-thumb-{}", std::process::id()));
        let _ = fs::remove_dir_all(&base);
        fs::create_dir_all(&base).unwrap();
        let source = base.join("wide picture.png");
        image::RgbaImage::new(1200, 600).save(&source).unwrap();
        unsafe { std::env::set_var("XDG_CACHE_HOME", base.join("cache")) };

        assert!(cached(&source, 256).is_err());
        generate(&source, 256).unwrap();
        let url = cached(&source, 256).unwrap();
        assert!(url.contains("/thumbnails/large/"));
        let thumb = file(&source, 256);
        let small = image::open(&thumb).unwrap();
        assert_eq!((small.width(), small.height()), (256, 128));

        File::options()
            .append(true)
            .open(&source)
            .unwrap()
            .set_modified(UNIX_EPOCH + Duration::from_secs(1_000_000))
            .unwrap();
        assert!(cached(&source, 256).is_err());

        fs::remove_dir_all(&base).unwrap();
    }

    #[test]
    fn retries_failed_and_deleted_thumbnails() {
        let _guard = ENV_LOCK.lock().unwrap();
        let base = std::env::temp_dir().join(format!("aresta-thumb-queue-{}", std::process::id()));
        let _ = fs::remove_dir_all(&base);
        fs::create_dir_all(&base).unwrap();
        let source = base.join("retry.png");
        fs::write(&source, b"not a png").unwrap();
        unsafe { std::env::set_var("XDG_CACHE_HOME", base.join("cache")) };

        let queue = Queue::default();
        let hits = Arc::new(AtomicUsize::new(0));
        let (mtime, _) = stamp(&source).unwrap();
        let hits_clone = Arc::clone(&hits);
        queue.request(&source, 256, mtime, move || {
            hits_clone.fetch_add(1, Ordering::SeqCst);
        });

        let deadline = Instant::now() + Duration::from_secs(5);
        while !queue.asked.lock().unwrap().is_empty() && Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(10));
        }
        assert!(queue.asked.lock().unwrap().is_empty());
        assert_eq!(hits.load(Ordering::SeqCst), 0);

        image::RgbaImage::new(400, 200).save(&source).unwrap();
        let (mtime, _) = stamp(&source).unwrap();
        let hits_clone = Arc::clone(&hits);
        queue.request(&source, 256, mtime, move || {
            hits_clone.fetch_add(1, Ordering::SeqCst);
        });

        let deadline = Instant::now() + Duration::from_secs(5);
        while hits.load(Ordering::SeqCst) < 1 && Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(10));
        }
        assert_eq!(hits.load(Ordering::SeqCst), 1);
        assert!(cached(&source, 256).is_ok());

        fs::remove_file(file(&source, 256)).unwrap();
        assert!(cached(&source, 256).is_err());

        let hits_clone = Arc::clone(&hits);
        queue.request(&source, 256, mtime, move || {
            hits_clone.fetch_add(1, Ordering::SeqCst);
        });

        let deadline = Instant::now() + Duration::from_secs(5);
        while hits.load(Ordering::SeqCst) < 2 && Instant::now() < deadline {
            std::thread::sleep(Duration::from_millis(10));
        }
        assert_eq!(hits.load(Ordering::SeqCst), 2);
        assert!(cached(&source, 256).is_ok());

        fs::remove_dir_all(&base).unwrap();
    }
}
