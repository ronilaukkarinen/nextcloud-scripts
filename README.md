# ⚡ Nextcloud scripts

 ![Version](https://img.shields.io/badge/version-1.0.0-blue?style=for-the-badge) ![Nextcloud](https://img.shields.io/badge/Nextcloud-%2300A2FF.svg?style=for-the-badge&logo=nextcloud&logoColor=white) ![bash](https://img.shields.io/badge/bash-%23121011.svg?style=for-the-badge&color=%23222222&logo=gnu-bash&logoColor=white)

Dependency free scripts for syncing files to Nextcloud.

### WebDAV sync script

This completely dependency-free script syncs a local directory to a Nextcloud WebDAV server.

## Getting started

1. Clone the repository.

```bash
git clone https://github.com/ronilaukkarinen/nextcloud-scripts
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
