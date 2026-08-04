"""
Shared "dirty data" helpers used by all bronze generators.

Every function here draws from the module-level `random` instance, which
is seeded exactly once (in config.py) before any generator runs. Callers
must invoke these in a fixed, deterministic order (loop over lists, not
sets/dicts) so reruns of build.py produce byte-identical bronze tables.
"""

import random

# --- Mixed-boolean text pool ------------------------------------------
# As specified: {Y,N,y,n,true,false,1,0,yes,no,NULL} stored as literal TEXT.
BOOL_TRUE_TEXTS = ["Y", "y", "true", "1", "yes"]
BOOL_FALSE_TEXTS = ["N", "n", "false", "0", "no"]


def messy_bool(is_true, null_prob=0.05):
    """Return a dirty TEXT representation of a boolean, or None sometimes."""
    if random.random() < null_prob:
        return None
    pool = BOOL_TRUE_TEXTS if is_true else BOOL_FALSE_TEXTS
    return random.choice(pool)


def maybe_null(value, prob):
    """Return None with probability `prob`, else the original value."""
    if random.random() < prob:
        return None
    return value


def maybe_empty(value, prob):
    """Return '' with probability `prob`, else the original value."""
    if random.random() < prob:
        return ""
    return value


# --- Casing ---------------------------------------------------------------

def scramble_casing(s):
    """Randomly render a string as UPPER, lower, Title, or left as-is."""
    if s is None:
        return s
    choice = random.choice(["upper", "lower", "title", "asis"])
    if choice == "upper":
        return s.upper()
    if choice == "lower":
        return s.lower()
    if choice == "title":
        return s.title()
    return s


def inject_whitespace(s, prob=0.08):
    """Occasionally add leading/trailing space or collapse-breaking double space."""
    if s is None or s == "":
        return s
    if random.random() < prob:
        style = random.choice(["leading", "trailing", "both", "double_internal"])
        if style == "leading":
            return " " + s
        if style == "trailing":
            return s + " "
        if style == "both":
            return " " + s + " "
        if style == "double_internal" and " " in s:
            return s.replace(" ", "  ", 1)
    return s


# --- Phone -----------------------------------------------------------------

_PHONE_FORMATS = [
    lambda a, p, l: f"({a}) {p}-{l}",
    lambda a, p, l: f"{a}-{p}-{l}",
    lambda a, p, l: f"{a}{p}{l}",
    lambda a, p, l: f"{a}.{p}.{l}",
    lambda a, p, l: f"+1 {a} {p} {l}",
]


def messy_phone(area, prefix, line):
    """Render a phone number in one of several inconsistent formats."""
    fmt = random.choice(_PHONE_FORMATS)
    return fmt(area, prefix, line)


# --- State -------------------------------------------------------------
# a few US states have a well-known "Calif."-style abbreviation people
# actually type on paper forms; keep this small and deliberate.
_STATE_DOTTED_ABBREVIATIONS = {
    "California": "Calif.",
    "Florida": "Fla.",
    "Massachusetts": "Mass.",
    "Pennsylvania": "Penn.",
    "Washington": "Wash.",
}


def messy_state(full_name, abbrev):
    """Return one of several inconsistent renderings of a US state."""
    options = [abbrev, abbrev.lower(), full_name, full_name.lower()]
    if full_name in _STATE_DOTTED_ABBREVIATIONS:
        options.append(_STATE_DOTTED_ABBREVIATIONS[full_name])
    return random.choice(options)


# --- Dates ---------------------------------------------------------------

def messy_date(d, include_time=False):
    """
    Render a date.date as one of several inconsistent string formats.
    d: a datetime.date
    include_time: if True, sometimes appends a time component.
    """
    fmt_choice = random.choice(["iso", "slash", "iso_time"])
    if fmt_choice == "iso":
        return d.strftime("%Y-%m-%d")
    if fmt_choice == "slash":
        return d.strftime("%m/%d/%Y")
    # iso_time
    hh = random.randint(0, 23)
    mm = random.randint(0, 59)
    ss = random.randint(0, 59)
    return f"{d.strftime('%Y-%m-%d')} {hh:02d}:{mm:02d}:{ss:02d}"


# --- Category / free-text casing variants -------------------------------

# A few categories get a deliberate spacing variant on top of casing
# (e.g. "Footwear" -> "Foot Wear") to mirror real free-text entry.
_CATEGORY_SPACING_VARIANTS = {
    "Footwear": "Foot Wear",
    "Camping & Hiking": "Camping and Hiking",
    "Nutrition & Hydration": "Nutrition and Hydration",
}


def messy_category(name):
    """Return an inconsistent casing/spacing rendering of a category name."""
    base = name
    if name in _CATEGORY_SPACING_VARIANTS and random.random() < 0.25:
        base = _CATEGORY_SPACING_VARIANTS[name]
    variant = random.choice(["upper", "upper_pad", "lower", "asis", "asis"])
    if variant == "upper":
        return base.upper()
    if variant == "upper_pad":
        return base.upper() + " "
    if variant == "lower":
        return base.lower()
    return base


def random_name_casing(name):
    """Alias of scramble_casing kept for readability at call sites."""
    return scramble_casing(name)
