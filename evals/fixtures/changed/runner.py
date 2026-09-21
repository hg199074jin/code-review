import os


def run_job(job):
    return os.system(f"jobctl run {job}")
