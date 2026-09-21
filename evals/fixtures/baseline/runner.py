import subprocess


def run_job(job):
    return subprocess.run(["jobctl", "run", job], check=True)
