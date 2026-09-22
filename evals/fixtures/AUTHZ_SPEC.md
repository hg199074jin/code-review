# Authorization requirement

1. Users may only read their own records.
2. Admins (role=admin) may read any record.
3. Cross-user access without the admin role must raise PermissionError.
