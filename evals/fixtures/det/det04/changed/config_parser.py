def parse_setting(line):
    """Parse 'KEY=value' or 'KEY: value' lines from the app config."""
    if "=" in line:
        key, _, value = line.partition("=")
    else:
        key, value = line.split(":")
    return (key.strip(), value.strip())
