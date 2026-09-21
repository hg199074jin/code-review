# High-risk requirement

1. run_job(job) receives an untrusted job identifier.
2. It must invoke jobctl without a shell.
3. A malicious job string must never become executable shell syntax.
