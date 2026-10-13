from django.test import SimpleTestCase

from patients.views import calculate_age


class CalculateAgeTests(SimpleTestCase):
    def test_calculate_age_returns_zero_for_invalid_date(self):
        self.assertEqual(calculate_age(""), 0)
        self.assertEqual(calculate_age("not-a-date"), 0)
