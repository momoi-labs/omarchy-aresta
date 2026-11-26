use std::fs;
use std::path::PathBuf;
use std::process::{Command, Stdio};
use std::time::{Duration, SystemTime, UNIX_EPOCH};

use chrono::{DateTime, Days, Local, NaiveDateTime, NaiveTime, TimeDelta, TimeZone};
use sunrise::{Coordinates, SolarDay, SolarEvent};

use crate::settings::{Settings, Value};
use crate::theme;
use crate::wallpaper;

const LOCATION_LIFETIME: Duration = Duration::from_secs(24 * 60 * 60);
const DEFAULT_LIGHT: NaiveTime = NaiveTime::from_hms_opt(7, 0, 0).unwrap();
const DEFAULT_DARK: NaiveTime = NaiveTime::from_hms_opt(19, 0, 0).unwrap();

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

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum Schedule {
    Solar,
    Custom,
}

pub enum Status {
    Off,
    NoLocation,
    Planned(Plan, Schedule),
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
    let switches: Vec<Switch> = [
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
    around(switches, now)
}

fn around(mut switches: Vec<Switch>, now: i64) -> Option<Plan> {
    switches.sort_by_key(|switch| switch.at);
    let current = *switches.iter().rev().find(|switch| switch.at <= now)?;
    let next = *switches.iter().find(|switch| switch.at > now)?;
    Some(Plan { current, next })
}

fn clock(text: &str) -> Option<NaiveTime> {
    let (hour, minute) = text.split_once(':')?;
    let digits = |part: &str| part.len() == 2 && part.bytes().all(|byte| byte.is_ascii_digit());
    if !digits(hour) || !digits(minute) {
        return None;
    }
    NaiveTime::from_hms_opt(hour.parse().ok()?, minute.parse().ok()?, 0)
}

fn clocks(light: &str, dark: &str) -> (NaiveTime, NaiveTime) {
    match (clock(light), clock(dark)) {
        (Some(light), Some(dark)) if light != dark => (light, dark),
        _ => (DEFAULT_LIGHT, DEFAULT_DARK),
    }
}

fn instant<Zone: TimeZone>(zone: &Zone, local: NaiveDateTime) -> Option<i64> {
    zone.from_local_datetime(&local)
        .earliest()
        .or_else(|| {
            zone.from_local_datetime(&(local + TimeDelta::hours(1)))
                .earliest()
        })
        .map(|time| time.timestamp())
}

pub fn custom_plan<Zone: TimeZone>(zone: &Zone, light: &str, dark: &str, now: i64) -> Option<Plan> {
    let (light, dark) = clocks(light, dark);
    let today = zone.timestamp_opt(now, 0).single()?.date_naive();
    let mut locals: Vec<(NaiveDateTime, bool)> = [
        today.checked_sub_days(Days::new(1))?,
        today,
        today.checked_add_days(Days::new(1))?,
    ]
    .into_iter()
    .flat_map(|date| [(date.and_time(light), false), (date.and_time(dark), true)])
    .collect();
    locals.sort_by_key(|(local, _)| *local);
    let mut floor = i64::MIN;
    let mut switches: Vec<Switch> = locals
        .into_iter()
        .filter_map(|(local, dark)| {
            floor = instant(zone, local)?.max(floor);
            Some(Switch { at: floor, dark })
        })
        .collect();
    switches.dedup_by(|later, kept| {
        let same = later.at == kept.at;
        if same {
            kept.dark = later.dark;
        }
        same
    });
    around(switches, now)
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
        Status::Planned(plan, schedule) => format!(
            "next={}\nnext_dark={}\nschedule={}\n",
            plan.next.at,
            plan.next.dark,
            match schedule {
                Schedule::Solar => "solar",
                Schedule::Custom => "custom",
            }
        ),
    };
    let _ = fs::create_dir_all(state());
    let _ = fs::write(status_path(), text);
}

pub fn run(force: bool) -> Result<(), String> {
    let _ = fs::create_dir_all(state());
    let _lock =
        fs::File::create(state().join("auto-lock")).and_then(|file| file.lock().map(|()| file));
    if force {
        let _ = fs::remove_file(transition_path());
    }
    let settings = Settings::load();
    if !matches!(settings.get("appearance_auto"), Some(Value::Flag(true))) {
        write_status(&Status::Off);
        return Ok(());
    }
    let text = |key: &str| match settings.get(key) {
        Some(Value::Text(text)) => text.as_str(),
        _ => "",
    };
    let (found, schedule) = if text("appearance_auto_schedule") == "custom" {
        let light = text("appearance_auto_light");
        let dark = text("appearance_auto_dark");
        (custom_plan(&Local, light, dark, now()), Schedule::Custom)
    } else {
        (
            location().and_then(|place| plan(place, now())),
            Schedule::Solar,
        )
    };
    let Some(plan) = found else {
        write_status(&Status::NoLocation);
        return Ok(());
    };
    write_status(&Status::Planned(plan, schedule));

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
    if theme::current_name() != *slug {
        if matches!(settings.get("wallpaper_keep"), Some(Value::Flag(true))) {
            wallpaper::pin(slug);
        }
        let status = theme::set_command(slug)
            .stdin(Stdio::null())
            .status()
            .map_err(|error| format!("omarchy-theme-set: {error}"))?;
        if !status.success() {
            return Err(format!("omarchy-theme-set: {status}"));
        }
    }
    fs::write(transition_path(), format!("{}\n", plan.current.at))
        .map_err(|error| format!("{}: {error}", transition_path().display()))
}

#[cfg(test)]
mod tests {
    use super::*;
    use chrono::{FixedOffset, MappedLocalTime, NaiveDate};

    #[derive(Clone, Copy)]
    struct Spring;

    fn winter() -> FixedOffset {
        FixedOffset::west_opt(5 * 3600).unwrap()
    }

    fn summer() -> FixedOffset {
        FixedOffset::west_opt(4 * 3600).unwrap()
    }

    fn gap() -> NaiveDateTime {
        NaiveDate::from_ymd_opt(2026, 3, 8)
            .unwrap()
            .and_hms_opt(2, 0, 0)
            .unwrap()
    }

    impl TimeZone for Spring {
        type Offset = FixedOffset;

        fn from_offset(_: &FixedOffset) -> Self {
            Spring
        }

        fn offset_from_local_date(&self, local: &NaiveDate) -> MappedLocalTime<FixedOffset> {
            self.offset_from_local_datetime(&local.and_time(NaiveTime::MIN))
        }

        fn offset_from_local_datetime(
            &self,
            local: &NaiveDateTime,
        ) -> MappedLocalTime<FixedOffset> {
            if *local < gap() {
                MappedLocalTime::Single(winter())
            } else if *local < gap() + TimeDelta::hours(1) {
                MappedLocalTime::None
            } else {
                MappedLocalTime::Single(summer())
            }
        }

        fn offset_from_utc_date(&self, utc: &NaiveDate) -> FixedOffset {
            self.offset_from_utc_datetime(&utc.and_time(NaiveTime::MIN))
        }

        fn offset_from_utc_datetime(&self, utc: &NaiveDateTime) -> FixedOffset {
            if *utc < gap() + TimeDelta::hours(5) {
                winter()
            } else {
                summer()
            }
        }
    }

    fn spring(day: u32, hour: u32, minute: u32, dark: bool) -> Switch {
        Switch {
            at: summer()
                .with_ymd_and_hms(2026, 3, day, hour, minute, 0)
                .unwrap()
                .timestamp(),
            dark,
        }
    }

    fn zone() -> FixedOffset {
        FixedOffset::west_opt(3 * 3600).unwrap()
    }

    fn at(day: u32, hour: u32, minute: u32) -> i64 {
        let local = NaiveDate::from_ymd_opt(2026, 11, day)
            .unwrap()
            .and_hms_opt(hour, minute, 0)
            .unwrap();
        zone().from_local_datetime(&local).unwrap().timestamp()
    }

    fn switch(day: u32, hour: u32, minute: u32, dark: bool) -> Switch {
        Switch {
            at: at(day, hour, minute),
            dark,
        }
    }

    fn planned(light: &str, dark: &str, now: i64) -> Plan {
        custom_plan(&zone(), light, dark, now).unwrap()
    }

    #[test]
    fn custom_before_light_is_dark_since_yesterday() {
        assert_eq!(
            planned("07:00", "19:00", at(26, 5, 30)),
            Plan {
                current: switch(25, 19, 0, true),
                next: switch(26, 7, 0, false),
            }
        );
    }

    #[test]
    fn custom_between_light_and_dark_is_light() {
        assert_eq!(
            planned("07:00", "19:00", at(26, 12, 0)),
            Plan {
                current: switch(26, 7, 0, false),
                next: switch(26, 19, 0, true),
            }
        );
    }

    #[test]
    fn custom_after_dark_is_dark_until_tomorrow() {
        assert_eq!(
            planned("07:00", "19:00", at(26, 22, 15)),
            Plan {
                current: switch(26, 19, 0, true),
                next: switch(27, 7, 0, false),
            }
        );
    }

    #[test]
    fn custom_switches_at_the_exact_minute() {
        assert_eq!(
            planned("07:00", "19:00", at(26, 18, 59)).current,
            switch(26, 7, 0, false)
        );
        assert_eq!(
            planned("07:00", "19:00", at(26, 19, 0)).current,
            switch(26, 19, 0, true)
        );
        assert_eq!(
            planned("07:00", "19:00", at(26, 7, 0)).current,
            switch(26, 7, 0, false)
        );
    }

    #[test]
    fn custom_inverted_schedule_is_light_overnight() {
        assert_eq!(
            planned("18:00", "06:00", at(26, 3, 0)),
            Plan {
                current: switch(25, 18, 0, false),
                next: switch(26, 6, 0, true),
            }
        );
        assert_eq!(
            planned("18:00", "06:00", at(26, 12, 0)),
            Plan {
                current: switch(26, 6, 0, true),
                next: switch(26, 18, 0, false),
            }
        );
        assert_eq!(
            planned("18:00", "06:00", at(26, 20, 0)),
            Plan {
                current: switch(26, 18, 0, false),
                next: switch(27, 6, 0, true),
            }
        );
    }

    #[test]
    fn custom_uses_the_local_day_of_the_zone() {
        let late = at(26, 23, 30);
        assert_eq!(
            DateTime::from_timestamp(late, 0).unwrap().date_naive(),
            NaiveDate::from_ymd_opt(2026, 11, 27).unwrap()
        );
        assert_eq!(
            planned("07:00", "19:00", late),
            Plan {
                current: switch(26, 19, 0, true),
                next: switch(27, 7, 0, false),
            }
        );
    }

    #[test]
    fn custom_equal_times_fall_back_to_the_defaults() {
        assert_eq!(
            planned("12:00", "12:00", at(26, 12, 0)),
            planned("07:00", "19:00", at(26, 12, 0))
        );
    }

    #[test]
    fn custom_malformed_times_fall_back_to_the_defaults() {
        let expected = planned("07:00", "19:00", at(26, 20, 0));
        for (light, dark) in [
            ("", ""),
            ("7:00", "19:00"),
            ("07:00", "24:00"),
            ("07:60", "19:00"),
            ("morning", "19:00"),
            ("09:00", "21"),
            ("+9:00", "21:00"),
            ("09:00 ", "21:00"),
        ] {
            assert_eq!(
                planned(light, dark, at(26, 20, 0)),
                expected,
                "{light} {dark}"
            );
        }
    }

    #[test]
    fn custom_keeps_valid_times_with_minutes() {
        assert_eq!(
            planned("06:45", "21:30", at(26, 21, 29)),
            Plan {
                current: switch(26, 6, 45, false),
                next: switch(26, 21, 30, true),
            }
        );
    }

    #[test]
    fn custom_time_in_a_skipped_hour_moves_past_the_gap() {
        assert_eq!(
            custom_plan(&Spring, "02:30", "19:00", spring(8, 12, 0, false).at).unwrap(),
            Plan {
                current: spring(8, 3, 30, false),
                next: spring(8, 19, 0, true),
            }
        );
    }

    #[test]
    fn custom_skipped_hour_keeps_the_order_of_the_switches() {
        assert_eq!(
            custom_plan(&Spring, "02:30", "03:00", spring(8, 3, 15, false).at).unwrap(),
            Plan {
                current: Switch {
                    at: winter()
                        .with_ymd_and_hms(2026, 3, 7, 3, 0, 0)
                        .unwrap()
                        .timestamp(),
                    dark: true,
                },
                next: spring(8, 3, 30, true),
            }
        );
        assert_eq!(
            custom_plan(&Spring, "02:30", "03:00", spring(8, 12, 0, false).at).unwrap(),
            Plan {
                current: spring(8, 3, 30, true),
                next: spring(9, 2, 30, false),
            }
        );
    }
}
