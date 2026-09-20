import importlib.util
import io
import json
import tempfile
import unittest
from datetime import date, datetime
from pathlib import Path
from unittest import mock
from zoneinfo import ZoneInfo


SPEC = importlib.util.spec_from_file_location("yaqazah", Path(__file__).parents[1] / "yaqazah.py")
yaqazah = importlib.util.module_from_spec(SPEC)
assert SPEC.loader
SPEC.loader.exec_module(yaqazah)


class YaqazahTests(unittest.TestCase):
    def test_limited_reader_rejects_oversized_input(self):
        with self.assertRaises(yaqazah.YaqazahError):
            yaqazah.read_limited(io.BytesIO(b"12345"), 4)

    def test_json_cache_rejects_oversized_file(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "cache.json"
            path.write_bytes(b" " * (yaqazah.CACHE_MAX_BYTES + 1))
            self.assertIsNone(yaqazah.read_json(path))

    def test_limited_file_reader_rejects_symlink(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            target = root / "target.txt"
            link = root / "link.txt"
            target.write_text("private", encoding="utf-8")
            link.symlink_to(target)
            with self.assertRaises(OSError):
                yaqazah.read_text_limited(link, 32)

    def test_limited_file_reader_rejects_special_file_without_blocking(self):
        with tempfile.TemporaryDirectory() as directory:
            fifo = Path(directory) / "input.fifo"
            fifo.parent.chmod(0o700)
            yaqazah.os.mkfifo(fifo)
            with self.assertRaises(yaqazah.YaqazahError):
                yaqazah.read_text_limited(fifo, 32)

    def test_atomic_write_replaces_symlink_without_touching_target(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            root.chmod(0o700)
            target = root / "target.txt"
            output = root / "output.txt"
            target.write_text("unchanged", encoding="utf-8")
            output.symlink_to(target)

            yaqazah.atomic_write_text(output, "generated", 32)

            self.assertFalse(output.is_symlink())
            self.assertEqual(output.read_text(encoding="utf-8"), "generated")
            self.assertEqual(target.read_text(encoding="utf-8"), "unchanged")

    def test_file_access_rejects_symlinked_parent_directory(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            real = root / "real"
            link = root / "link"
            real.mkdir()
            link.symlink_to(real, target_is_directory=True)
            (real / "data.txt").write_text("value", encoding="utf-8")
            with self.assertRaises(OSError):
                yaqazah.read_text_limited(link / "data.txt", 32)

    def test_json_shape_rejects_excessive_entries(self):
        value = list(range(yaqazah.JSON_MAX_CONTAINER_ITEMS + 1))
        with self.assertRaises(yaqazah.YaqazahError):
            yaqazah.validate_json_shape(value)

    def test_request_json_streams_with_a_byte_limit(self):
        class Response(io.BytesIO):
            headers = {}

            def __enter__(self):
                return self

            def __exit__(self, *_args):
                self.close()

        response = Response(json.dumps({"city": "Bristol"}).encode())
        with mock.patch.object(yaqazah.urllib.request, "urlopen", return_value=response):
            self.assertEqual(yaqazah.request_json("https://example.test")["city"], "Bristol")

    def test_location_fields_and_coordinates_are_bounded(self):
        base = {
            "city": "Bristol",
            "country": "United Kingdom",
            "country_code": "GB",
            "latitude": 51.45,
            "longitude": -2.58,
            "timezone": "Europe/London",
        }
        self.assertEqual(yaqazah.normalize_location(base, "auto")["city"], "Bristol")
        with self.assertRaises(yaqazah.YaqazahError):
            yaqazah.normalize_location({**base, "city": "x" * 129}, "auto")
        with self.assertRaises(yaqazah.YaqazahError):
            yaqazah.normalize_location({**base, "latitude": 91}, "auto")

    def test_prayer_time_range_is_validated(self):
        with self.assertRaises(yaqazah.YaqazahError):
            yaqazah.parse_api_time("25:00")

    def test_country_method_recommendations(self):
        self.assertEqual(yaqazah.recommended_method("GB"), "Moonsighting")
        self.assertEqual(yaqazah.recommended_method("SA"), "Makkah")
        self.assertEqual(yaqazah.recommended_method("EG"), "Egypt")
        self.assertEqual(yaqazah.recommended_method("JO"), "Jordan")
        self.assertEqual(yaqazah.recommended_method("XX"), "MWL")

    def test_explicit_method_wins(self):
        self.assertEqual(yaqazah.select_method("ISNA", "GB"), ("ISNA", 2, False))
        self.assertEqual(yaqazah.select_method("Egypt", "EG"), ("Egypt", 5, False))
        self.assertEqual(yaqazah.select_method("MWL", "GB"), ("MWL", 3, False))
        self.assertEqual(yaqazah.select_method("Karachi", "PK"), ("Karachi", 1, False))
        self.assertEqual(yaqazah.select_method("Jordan", "JO"), ("Jordan", 23, False))

    def test_official_aladhan_method_ids(self):
        expected = {
            "Jafari": 0,
            "Karachi": 1,
            "ISNA": 2,
            "MWL": 3,
            "Makkah": 4,
            "Egypt": 5,
            "Tehran": 7,
            "Gulf": 8,
            "Kuwait": 9,
            "Qatar": 10,
            "Singapore": 11,
            "France": 12,
            "Turkey": 13,
            "Russia": 14,
            "Moonsighting": 15,
            "Dubai": 16,
            "JAKIM": 17,
            "Tunisia": 18,
            "Algeria": 19,
            "Kemenag": 20,
            "Morocco": 21,
            "Portugal": 22,
            "Jordan": 23,
        }
        for name, method_id in expected.items():
            self.assertEqual(yaqazah.METHODS.get(name), method_id, f"Method {name} ID mismatch")

    def test_schedule_marks_next_prayer(self):
        timings = {
            "date": date(2026, 8, 23).isoformat(),
            "timings": {
                "fajr": "04:20",
                "sunrise": "06:02",
                "dhuhr": "13:10",
                "asr": "17:04",
                "maghrib": "20:16",
                "isha": "21:26",
            },
        }
        now = datetime(2026, 8, 23, 14, 24, tzinfo=ZoneInfo("Europe/London"))
        rows, next_prayer = yaqazah.build_schedule(timings, now)
        self.assertEqual(next_prayer["name"], "Asr")
        self.assertEqual(next_prayer["countdown"], "2h 40m")
        self.assertEqual(next_prayer["minutesLeft"], 160)
        self.assertEqual(next_prayer["secondsLeft"], 160 * 60)
        self.assertGreater(next_prayer["targetTimestamp"], 0)
        self.assertEqual(next(row for row in rows if row["key"] == "asr")["status"], "next")
        self.assertEqual(next(row for row in rows if row["key"] == "dhuhr")["status"], "past")

    def test_schedule_under_one_hour(self):
        timings = {
            "date": date(2026, 8, 23).isoformat(),
            "timings": {
                "fajr": "04:20",
                "sunrise": "06:02",
                "dhuhr": "13:10",
                "asr": "17:04",
                "maghrib": "20:16",
                "isha": "21:26",
            },
        }
        # 16:34 is exactly 30 minutes before Asr (17:04)
        now = datetime(2026, 8, 23, 16, 34, tzinfo=ZoneInfo("Europe/London"))
        rows, next_prayer = yaqazah.build_schedule(timings, now)
        self.assertEqual(next_prayer["name"], "Asr")
        self.assertEqual(next_prayer["countdown"], "30m")
        self.assertEqual(next_prayer["minutesLeft"], 30)
        self.assertEqual(next_prayer["secondsLeft"], 30 * 60)
        self.assertLess(next_prayer["minutesLeft"], 60)

    def test_after_isha_rolls_to_tomorrow(self):
        timings = {
            "date": "2026-08-23",
            "timings": {
                "fajr": "04:20",
                "sunrise": "06:02",
                "dhuhr": "13:10",
                "asr": "17:04",
                "maghrib": "20:16",
                "isha": "21:26",
            },
        }
        now = datetime(2026, 8, 23, 23, 0, tzinfo=ZoneInfo("Europe/London"))
        _, next_prayer = yaqazah.build_schedule(timings, now)
        self.assertEqual(next_prayer["name"], "Fajr")
        self.assertEqual(next_prayer["dayLabel"], "Tomorrow")

    def test_stale_previous_day_still_rolls_forward(self):
        timings = {
            "date": "2026-08-22",
            "timings": {
                "fajr": "04:20",
                "sunrise": "06:02",
                "dhuhr": "13:10",
                "asr": "17:04",
                "maghrib": "20:16",
                "isha": "21:26",
            },
        }
        now = datetime(2026, 8, 23, 23, 0, tzinfo=ZoneInfo("Europe/London"))
        _, next_prayer = yaqazah.build_schedule(timings, now)
        self.assertEqual(next_prayer["time"], "04:20")
        self.assertEqual(next_prayer["dayLabel"], "Tomorrow")
        self.assertFalse(next_prayer["countdown"].startswith("in "))
        self.assertTrue("h" in next_prayer["countdown"] or "m" in next_prayer["countdown"])

    def test_search_cities_formats_results(self):
        fake_payload = {
            "results": [
                {
                    "name": "Cairo",
                    "country": "Egypt",
                    "country_code": "EG",
                    "admin1": "Cairo Governorate",
                }
            ]
        }
        with mock.patch.object(yaqazah, "request_json", return_value=fake_payload):
            results = yaqazah.search_cities("Cairo")
            self.assertEqual(len(results), 1)
            self.assertEqual(results[0]["name"], "Cairo")
            self.assertEqual(results[0]["country"], "Egypt")
            self.assertEqual(results[0]["label"], "Cairo, Cairo Governorate, Egypt")

    def test_format_clock(self):
        self.assertEqual(yaqazah.format_clock("04:20", "24h"), "04:20")
        self.assertEqual(yaqazah.format_clock("04:20", "12h"), "4:20 AM")
        self.assertEqual(yaqazah.format_clock("12:00", "12h"), "12:00 PM")
        self.assertEqual(yaqazah.format_clock("12:30", "12h"), "12:30 PM")
        self.assertEqual(yaqazah.format_clock("15:45", "12h"), "3:45 PM")
        self.assertEqual(yaqazah.format_clock("00:15", "12h"), "12:15 AM")

    def test_schedule_includes_12h_format(self):
        timings = {
            "date": "2026-08-23",
            "timings": {
                "fajr": "04:20",
                "sunrise": "06:02",
                "dhuhr": "13:10",
                "asr": "17:04",
                "maghrib": "20:16",
                "isha": "21:26",
            },
        }
        now = datetime(2026, 8, 23, 14, 24, tzinfo=ZoneInfo("Europe/London"))
        rows, next_prayer = yaqazah.build_schedule(timings, now)
        self.assertEqual(next_prayer["time"], "17:04")
        self.assertEqual(next_prayer["time12"], "5:04 PM")
        asr_row = next(r for r in rows if r["key"] == "asr")
        self.assertEqual(asr_row["time"], "17:04")
        self.assertEqual(asr_row["time12"], "5:04 PM")


if __name__ == "__main__":
    unittest.main()

