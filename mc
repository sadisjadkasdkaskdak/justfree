<svg xmlns="http://www.w3.org/2000/svg" width="100%" height="100%" viewBox="0 0 600 400">
  <style>
    .bg { fill: #0f172a; }
    .card { fill: #1e293b; rx: 16px; stroke: #334155; stroke-width: 1; }
    .btn-launch { fill: #3b82f6; cursor: pointer; transition: fill 0.2s; }
    .btn-launch:hover { fill: #60a5fa; }
    .btn-clear { fill: #dc2626; cursor: pointer; transition: fill 0.2s; }
    .btn-clear:hover { fill: #f87171; }
    .title { fill: #f8fafc; font-family: system-ui, -apple-system, sans-serif; font-size: 22px; font-weight: 700; text-anchor: middle; }
    .status { fill: #94a3b8; font-family: system-ui, -apple-system, sans-serif; font-size: 14px; text-anchor: middle; }
    .btn-text { fill: #ffffff; font-family: system-ui, -apple-system, sans-serif; font-size: 15px; font-weight: 600; text-anchor: middle; pointer-events: none; }
  </style>

  <rect width="100%" height="100%" class="bg" />
  <rect x="50" y="50" width="500" height="300" class="card" />

  <text x="300" y="120" class="title">Eaglercraft Offline Launcher</text>
  <text x="300" y="160" id="statusText" class="status">Ready to load game...</text>

  <!-- Launch Button -->
  <g id="launchGroup" cursor="pointer">
    <rect x="110" y="220" width="180" height="50" rx="10" class="btn-launch" />
    <text x="200" y="251" class="btn-text">Download &amp; Launch</text>
  </g>

  <!-- Clear Cache Button -->
  <g id="clearGroup" cursor="pointer">
    <rect x="310" y="220" width="180" height="50" rx="10" class="btn-clear" />
    <text x="400" y="251" class="btn-text">Clear Cache</text>
  </g>

  <script type="text/javascript">
    <![CDATA[
    (function() {
      // Use GitHub Media LFS Endpoint to fetch full LFS file contents
      const RAW_URL = "https://media.githubusercontent.com/media/aerograde/eagle-26.2/main/dist/direct-connect.html";
      const BASE_URL = "https://media.githubusercontent.com/media/aerograde/eagle-26.2/main/dist/";
      const DB_NAME = "EaglercraftCacheDB";
      const STORE_NAME = "game_files";
      const GAME_KEY = "eaglercraft_index";

      const statusText = document.getElementById("statusText");
      const launchGroup = document.getElementById("launchGroup");
      const clearGroup = document.getElementById("clearGroup");

      function updateStatus(msg) {
        if (statusText) statusText.textContent = msg;
      }

      function openDB() {
        return new Promise((resolve, reject) => {
          const req = indexedDB.open(DB_NAME);

          req.onupgradeneeded = (e) => {
            const db = e.target.result;
            if (!db.objectStoreNames.contains(STORE_NAME)) {
              db.createObjectStore(STORE_NAME);
            }
          };

          req.onsuccess = () => {
            const db = req.result;
            if (db.objectStoreNames.contains(STORE_NAME)) {
              resolve(db);
            } else {
              const nextVersion = (db.version || 1) + 1;
              db.close();
              const upReq = indexedDB.open(DB_NAME, nextVersion);
              upReq.onupgradeneeded = (e) => {
                const uDb = e.target.result;
                if (!uDb.objectStoreNames.contains(STORE_NAME)) {
                  uDb.createObjectStore(STORE_NAME);
                }
              };
              upReq.onsuccess = () => resolve(upReq.result);
              upReq.onerror = () => reject(upReq.error);
            }
          };

          req.onerror = () => reject(req.error);
        });
      }

      async function getStoredGame(db) {
        return new Promise((resolve, reject) => {
          const tx = db.transaction(STORE_NAME, "readonly");
          const store = tx.objectStore(STORE_NAME);
          const req = store.get(GAME_KEY);
          req.onsuccess = () => resolve(req.result);
          req.onerror = () => reject(req.error);
        });
      }

      async function saveGame(db, content) {
        return new Promise((resolve, reject) => {
          const tx = db.transaction(STORE_NAME, "readwrite");
          const store = tx.objectStore(STORE_NAME);
          const req = store.put(content, GAME_KEY);
          req.onsuccess = () => resolve();
          req.onerror = () => reject(req.error);
        });
      }

      async function clearStoredGame(db) {
        return new Promise((resolve, reject) => {
          const tx = db.transaction(STORE_NAME, "readwrite");
          const store = tx.objectStore(STORE_NAME);
          const req = store.delete(GAME_KEY);
          req.onsuccess = () => resolve();
          req.onerror = () => reject(req.error);
        });
      }

      function launchInAboutBlank(htmlContent) {
        const win = window.open("about:blank", "_blank");
        if (!win) {
          updateStatus("Pop-up blocked! Allow pop-ups and try again.");
          return;
        }

        let processedHtml = htmlContent;
        if (!/<base\s/i.test(processedHtml)) {
          processedHtml = `<base href="${BASE_URL}">` + processedHtml;
        }

        win.document.open();
        win.document.write(processedHtml);
        win.document.close();
        updateStatus("Launched successfully!");
      }

      async function handleLaunch() {
        try {
          updateStatus("Opening IndexedDB...");
          const db = await openDB();

          updateStatus("Checking cached version...");
          let cachedHtml = await getStoredGame(db);

          // Check if cached HTML is valid and not an LFS pointer
          if (cachedHtml && !cachedHtml.trim().startsWith("version https://git-lfs.github.com/spec/v1")) {
            updateStatus("Loaded from IndexedDB! Launching...");
            launchInAboutBlank(cachedHtml);
          } else {
            updateStatus("Downloading game file (~89 MB)...");
            const response = await fetch(RAW_URL);
            if (!response.ok) {
              throw new Error(`HTTP ${response.status}`);
            }
            const text = await response.text();

            if (text.trim().startsWith("version https://git-lfs.github.com/spec/v1")) {
              throw new Error("Received LFS pointer instead of file.");
            }

            updateStatus("Saving to IndexedDB...");
            await saveGame(db, text);

            updateStatus("Launching...");
            launchInAboutBlank(text);
          }
        } catch (err) {
          console.error(err);
          updateStatus("Error: " + err.message);
        }
      }

      async function handleClear() {
        try {
          updateStatus("Opening IndexedDB...");
          const db = await openDB();
          updateStatus("Clearing stored cache...");
          await clearStoredGame(db);
          updateStatus("Cache cleared successfully!");
        } catch (err) {
          console.error(err);
          updateStatus("Error clearing cache: " + err.message);
        }
      }

      if (launchGroup) launchGroup.addEventListener("click", handleLaunch);
      if (clearGroup) clearGroup.addEventListener("click", handleClear);
    })();
    ]]>
  </script>
</svg>
