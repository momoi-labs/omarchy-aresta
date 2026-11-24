use std::fs;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use chrono::{DateTime, Days};
use sunrise::{Coordinates, SolarDay, SolarEvent};

use crate::settings::{Settings, Value};
use crate::theme;
use crate::wallpaper;

const LOCATION_LIFETIME: Duration = Duration::from_secs(24 * 60 * 60);

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Switch {
    pub at: i64,
    pub dark: bool,
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct Plan {
    pub current: Switch,
    pub next: Switch,
}

pub enum Status {
    Off,
    NoLocation,
    Planned(Plan),
}

fn state() -> PathBuf {
    theme::home().join(".local/state/omarchy-cupertino")
}

pub fn status_path() -> PathBuf {
    state().join("auto-status")
}

pub fn transition_path() -> PathBuf {
    state().join("auto-transition")
}

fn coordinates(text: &str) -> Option<Coordinates> {
    let value: serde_json::Value = serde_json::from_str(text).ok()?;
    Coordinates::new(value["latitude"].as_f64()?, value["longitude"].as_f64()?)
}

fn location() -> Option<Coordinates> {
    let weather = theme::home().join(".local/state/omarchy/settings/weather.json");
    if let Some(found) = fs::read_to_string(weather)
        .ok()
        .and_then(|text| coordinates(&text))
    {
        return Some(found);
    }
    let cache = state().join("location.json");
    let fresh = fs::metadata(&cache)
        .and_then(|meta| meta.modified())
        .ok()
        .and_then(|modified| modified.elapsed().ok())
        .is_some_and(|age| age < LOCATION_LIFETIME);
    if fresh
        && let Some(found) = fs::read_to_string(&cache)
            .ok()
            .and_then(|text| coordinates(&text))
    {
        return Some(found);
    }
    let output = Command::new("curl")
        .args(["-fsS", "--max-time", "4", "https://geo.omarchy.org/"])
        .stdin(Stdio::null())
        .stderr(Stdio::null())
        .output()
        .ok()
        .filter(|output| output.status.success())?;
    let text = String::from_utf8_lossy(&output.stdout);
    let found = coordinates(&text)?;
    let _ = fs::create_dir_all(state());
    let _ = fs::write(cache, text.as_bytes());
    Some(found)
}

pub fn plan(place: Coordinates, now: i64) -> Option<Plan> {
    let today = DateTime::from_timestamp(now, 0)?.date_naive();
    let mut switches: Vec<Switch> = [
        today.checked_sub_days(Days::new(1))?,
        today,
        today.checked_add_days(Days::new(1))?,
    ]
    .into_iter()
    .flat_map(|date| {
        let day = SolarDay::new(place, date);
        [(SolarEvent::Sunrise, false), (SolarEvent::Sunset, true)]
            .into_iter()
            .filter_map(move |(event, dark)| {
                day.event_time(event).map(|time| Switch {
                    at: time.timestamp(),
                    dark,
                })
            })
    })
    .collect();
    switches.sort_by_key(|switch| switch.at);
    let current = *switches.iter().rev().find(|switch| switch.at <= now)?;
    let next = *switches.iter().find(|switch| switch.at > now)?;
    Some(Plan { current, next })
}

fn now() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|elapsed| elapsed.as_secs() as i64)
        .unwrap_or_default()
}

fn write_status(status: &Status) {
    let text = match status {
        Status::Off => String::new(),
        Status::NoLocation => "error=no-location\n".into(),
        Status::Planned(plan) => format!("next={}\nnext_dark={}\n", plan.next.at, plan.next.dark),
    };
    let _ = fs::create_dir_all(state());
    let _ = fs::write(status_path(), text);
}

pub fn run() -> Result<(), String> {
    let settings = Settings::load();
    if !matches!(settings.get("appearance_auto"), Some(Value::Flag(true))) {
        write_status(&Status::Off);
        return Ok(());
    }
    let Some(plan) = location().and_then(|place| plan(place, now())) else {
        write_status(&Status::NoLocation);
        return Ok(());
    };
    write_status(&Status::Planned(plan));

    let done = fs::read_to_string(transition_path())
        .ok()
        .and_then(|text| text.trim().parse::<i64>().ok());
    if done == Some(plan.current.at) {
        return Ok(());
    }
    let key = if plan.current.dark {
        "dark_theme"
    } else {
        "light_theme"
    };
    let Some(Value::Text(slug)) = settings.get(key) else {
        return Ok(());
    };
    fs::write(transition_path(), format!("{}\n", plan.current.at))
        .map_err(|error| format!("{}: {error}", transition_path().display()))?;
    if theme::current_name() == *slug {
        return Ok(());
    }
    let keep = matches!(settings.get("wallpaper_keep"), Some(Value::Flag(true)));
    if keep {
        wallpaper::pin(slug);
    }
    theme::set_command(slug)
        .stdin(Stdio::null())
        .status()
        .map_err(|error| format!("omarchy-theme-set: {error}"))?;
    Ok(())
}
