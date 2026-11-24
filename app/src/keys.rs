const MODIFIERS: &[(&str, &str, u32)] = &[
    ("SUPER", "Super", 0x1000_0000),
    ("CTRL", "Ctrl", 0x0400_0000),
    ("ALT", "Alt", 0x0800_0000),
    ("SHIFT", "Shift", 0x0200_0000),
];

const MODIFIER_KEYCODES: &[i32] = &[37, 50, 62, 64, 105, 108, 133, 134];

fn keycode_label(code: i32) -> String {
    const ROW_NUMBERS: &str = "1234567890-=";
    const ROW_TOP: &str = "QWERTYUIOP[]";
    const ROW_HOME: &str = "ASDFGHJKL;'`";
    const ROW_BOTTOM: &str = "ZXCVBNM,./";
    let pick = |row: &str, first: i32| {
        row.chars()
            .nth((code - first) as usize)
            .map(String::from)
            .unwrap_or_default()
    };
    match code {
        9 => "Esc".into(),
        10..=21 => pick(ROW_NUMBERS, 10),
        22 => "Backspace".into(),
        23 => "Tab".into(),
        24..=35 => pick(ROW_TOP, 24),
        36 => "Return".into(),
        38..=49 => pick(ROW_HOME, 38),
        51 => "\\".into(),
        52..=61 => pick(ROW_BOTTOM, 52),
        65 => "Space".into(),
        67..=76 => format!("F{}", code - 66),
        95 => "F11".into(),
        96 => "F12".into(),
        110 => "Home".into(),
        111 => "Up".into(),
        112 => "Page Up".into(),
        113 => "Left".into(),
        114 => "Right".into(),
        115 => "End".into(),
        116 => "Down".into(),
        117 => "Page Down".into(),
        118 => "Insert".into(),
        119 => "Delete".into(),
        _ => format!("Key {code}"),
    }
}

pub fn labels(binding: &str) -> Vec<String> {
    binding
        .split('+')
        .map(str::trim)
        .filter(|part| !part.is_empty())
        .map(|part| {
            if let Some((_, label, _)) = MODIFIERS.iter().find(|(name, _, _)| *name == part) {
                return (*label).to_string();
            }
            match part
                .strip_prefix("code:")
                .and_then(|code| code.parse().ok())
            {
                Some(code) => keycode_label(code),
                None => part.to_string(),
            }
        })
        .collect()
}

pub fn binding(modifiers: u32, keycode: i32) -> Option<String> {
    if MODIFIER_KEYCODES.contains(&keycode) || keycode <= 8 {
        return None;
    }
    let mut parts: Vec<String> = MODIFIERS
        .iter()
        .filter(|(_, _, flag)| modifiers & flag != 0)
        .map(|(name, _, _)| (*name).to_string())
        .collect();
    if parts.iter().all(|part| part == "SHIFT") {
        return None;
    }
    parts.push(format!("code:{keycode}"));
    Some(parts.join(" + "))
}
