from unittest.mock import patch

from runner import run_job


@patch("runner.os.system")
def test_run_job(mock_system):
    run_job("daily")
    mock_system.assert_called_once_with("jobctl run daily")
