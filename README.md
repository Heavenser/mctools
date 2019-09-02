# mctools
Minecraft backup and rollback tools

## Install
```bash
git clone https://github.com/Heavenser/mctools.git
cd mctools
chmod +x mctools.sh
```

## Usage
This script can backup your Minecraft game data and rollback it when you need, also can clean your backup files.

backup:
```bash
mctools backup from /path/to/game/dir to /path/to/backup/dir
```
backup with specified compression tool (support **zstd, lz4 and gzip**, NOT support bzip2 and xz because they are to slow):
```bash
mctools backup from /path/to/game/dir to /path/to/backup/dir use zstd
```

rollback:
```bash
mctools rollback from /path/to/backup/dir to /path/to/game/dir
```

clean:
```bash
mctools clean /path/to/backup/dir
```
## Author
Heavenser Lee (hvss#live.hk)

## License
[BSD 2-Clause](https://github.com/Heavenser/mctools/blob/master/LICENSE)
