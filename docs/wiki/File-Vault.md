# File Vault

Use a checkpoint when you need yesterday’s version of a **specific file**. It is not a snapshot of Assay, a folder tree or a whole iPhone, and cannot roll back a system change.

1. In **Lab → File Vault → Choose files for checkpoint**, select 1–32 individual files (up to 16 MiB each and 64 MiB total). Wait for the dated checkpoint to appear.
2. After editing a file, select it again to keep a second version. Assay does not monitor the original. Identical contents can be reused across checkpoints.
3. Expand the **earlier** checkpoint, tap the file and choose an empty writable folder in Files. Open the restored copy to check it. Assay verifies the bytes and refuses to overwrite a file of the same name; if there is a collision, choose another folder.

**Keep important copies outside the app.** Deleting Assay removes its vault. For a standard device backup instead, connect to a trusted Mac and use **Finder → your iPhone → General → Back Up Now**. That is distinct from an in-app protective backup for system tweaks, which this build does not provide.

[Field guide](Home.md) · [Testing and status](Testing-and-status.md)
