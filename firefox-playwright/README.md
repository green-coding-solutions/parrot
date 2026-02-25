# Firefox Playwright Speedometer

Runs Speedometer 3.1 in Playwright (Firefox) and prints the final score.

## Setup

```bash
pip install playwright
playwright install firefox
```

## Usage

Headless (default):

```bash
python3 firefox-playwright/run_speedometer.py
```

Headful:

```bash
python3 firefox-playwright/run_speedometer.py --headful
```

JSON output:

```bash
python3 firefox-playwright/run_speedometer.py --json
```
