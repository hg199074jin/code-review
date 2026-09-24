def parse_setting(line):
    """Parse 'KEY=value' lines from the app config."""
    key, _, value = line.partition("=")
    return (key.strip(), value.strip())
