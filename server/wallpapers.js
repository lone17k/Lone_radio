const fs = require('fs');
const path = require('path');

const VALID_EXT = new Set(['.jpg', '.jpeg', '.png', '.gif', '.webp']);

// Cache wallpapers in memory so opening the radio menu costs ZERO disk I/O.
// Built once on resource start; rebuildable at runtime via the
// `lone_radio:refreshWallpapers` command (admins who drop in new images).
let cachedWallpapers = [];

async function loadWallpapers() {
    const resourcePath = GetResourcePath(GetCurrentResourceName());
    const wallpapersPath = path.join(resourcePath, 'web', 'dist', 'imgs', 'wallpapers');

    const wallpapers = [];
    try {
        const files = await fs.promises.readdir(wallpapersPath);
        for (const file of files) {
            const ext = path.extname(file).toLowerCase();
            if (VALID_EXT.has(ext)) {
                wallpapers.push({
                    id: file,
                    name: file.replace(ext, ''),
                    url: `./imgs/wallpapers/${file}`
                });
            }
        }
    } catch (err) {
        if (err.code !== 'ENOENT') {
            console.error('Error reading wallpapers directory:', err);
        }
    }

    cachedWallpapers = wallpapers;
    return wallpapers;
}

// Build the cache once when the resource starts.
on('onResourceStart', (resName) => {
    if (resName === GetCurrentResourceName()) {
        loadWallpapers();
    }
});

// Menu open -> pure in-memory return, no filesystem access.
onNet('lone_radio:server:GetWallpapers', () => {
    emitNet('lone_radio:client:ReceiveWallpapers', global.source, cachedWallpapers);
});

// Optional manual refresh for drop-in updates without a full resource restart.
RegisterCommand('refreshwallpapers', async (source) => {
    if (source !== 0) return; // server console only
    await loadWallpapers();
    console.log(`[lone_radio] Wallpaper cache refreshed (${cachedWallpapers.length} found).`);
}, true);
