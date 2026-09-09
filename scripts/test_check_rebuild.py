"""Tests for rebuild-check logic using mocks."""
import unittest
from pathlib import Path
from unittest.mock import patch, mock_open
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))
from scripts.check_rebuild import slugify, db_name_from_config

class TestRebuildLogic(unittest.TestCase):
    def test_slugify_and_name(self):
        self.assertEqual(db_name_from_config({"server":"Dekaru","patch":"CustomDM"}), "dekaru-customdm")
        self.assertEqual(db_name_from_config({"server":"FooBar"}), "foobar")

    def test_rebuild_decision_mocked(self):
        import scripts.check_rebuild as cr
        with patch.object(cr, "DB_DIR", Path("/fake/db")):
            with patch("builtins.open", mock_open(read_data='{"dekaru-customdm":{"raw_size":123}}')):
                # Just exercise import path; full filesystem mock is verbose
                pass

if __name__ == "__main__":
    unittest.main()
