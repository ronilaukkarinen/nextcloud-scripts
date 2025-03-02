# Nextcloud scripts

Dependency free scripts for syncing files to Nextcloud.

### WebDAV Sync script

This completely dependency-free script syncs a local directory to a Nextcloud WebDAV server.

## Getting started

1. Clone the repository.

```bash
git clone https://github.com/yourusername/nextcloud-webdav-sync.git
```

2. Install dependencies.

```bash
npm install
```

3. Create a `.env` file.

```bash
cp .env.example .env
```

4. Set permissions.

```bash
chmod +x sync-to-nextcloud.sh
```

5. Run the script.

```bash
# Sync a single file
./sync-to-nextcloud.sh ~/Documents/myfile.txt /

# Sync an entire directory
./sync-to-nextcloud.sh ~/Documents/files/ /

# Do a dry run first
./sync-to-nextcloud.sh --dry-run ~/Documents/files/ /

# More verbose output
./sync-to-nextcloud.sh --verbose ~/Documents/files/ /

# Show help
./sync-to-nextcloud.sh --help
```
