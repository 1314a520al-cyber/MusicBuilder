// Tauri API Mock for iOS WKWebView
// 模拟 Tauri v2 的 __TAURI_INTERNALS__ 和 __TAURI__ API
(function() {
    'use strict';

    // ========== 内部状态 ==========
    var callbackId = 0;
    var callbacks = {};
    var sqlStore = {}; // SQL 数据存储（localStorage 持久化）
    var listeners = {}; // 事件监听器

    // 从 localStorage 加载 SQL 数据
    function loadSQLStore() {
        try {
            var data = localStorage.getItem('tauri_sql_store');
            if (data) sqlStore = JSON.parse(data);
        } catch(e) { sqlStore = {}; }
    }
    function saveSQLStore() {
        try { localStorage.setItem('tauri_sql_store', JSON.stringify(sqlStore)); } catch(e) {}
    }
    loadSQLStore();

    // ========== __TAURI_INTERNALS__（Tauri v2 核心 API）==========
    window.__TAURI_INTERNALS__ = {
        // 转换回调函数为 ID
        transformCallback: function(callback, once) {
            var id = ++callbackId;
            callbacks[id] = { callback: callback, once: !!once };
            return id;
        },

        // 注销回调
        unregisterCallback: function(id) {
            delete callbacks[id];
        },

        // 执行回调
        runCallback: function(id, result, error) {
            var cb = callbacks[id];
            if (!cb) return;
            try {
                if (error) cb.callback(null, error);
                else cb.callback(result);
            } catch(e) { console.error('Callback error:', e); }
            if (cb.once) delete callbacks[id];
        },

        // 调用命令
        invoke: function(cmd, args, options) {
            console.log('[TauriMock] invoke:', cmd, args);
            return handleInvoke(cmd, args || {});
        },

        // 转换文件路径为可访问 URL
        convertFileSrc: function(filePath, protocol) {
            // 在 iOS 上直接返回文件路径（WKWebView 可以访问）
            return filePath;
        },

        // 事件系统
        event: {
            listen: function(event, handler) {
                if (!listeners[event]) listeners[event] = [];
                listeners[event].push(handler);
                return Promise.resolve(function() {
                    listeners[event] = listeners[event].filter(function(h) { return h !== handler; });
                });
            },
            emit: function(event, payload) {
                if (listeners[event]) {
                    listeners[event].forEach(function(h) {
                        try { h({ event: event, payload: payload }); } catch(e) {}
                    });
                }
                return Promise.resolve();
            }
        }
    };

    // ========== __TAURI__（兼容旧版 API）==========
    window.__TAURI__ = {
        invoke: window.__TAURI_INTERNALS__.invoke,
        convertFileSrc: window.__TAURI_INTERNALS__.convertFileSrc,
        transformCallback: window.__TAURI_INTERNALS__.transformCallback,
        unregisterCallback: window.__TAURI_INTERNALS__.unregisterCallback,
        event: window.__TAURI_INTERNALS__.event,
        core: {
            invoke: window.__TAURI_INTERNALS__.invoke,
            convertFileSrc: window.__TAURI_INTERNALS__.convertFileSrc
        },
        window: {
            label: 'main',
            title: '易创',
            getCurrentWindow: function() { return window.__TAURI__.window; },
            getAllWindows: function() { return Promise.resolve([window.__TAURI__.window]); },
            close: function() { return Promise.resolve(); },
            hide: function() { return Promise.resolve(); },
            show: function() { return Promise.resolve(); },
            minimize: function() { return Promise.resolve(); },
            maximize: function() { return Promise.resolve(); },
            unmaximize: function() { return Promise.resolve(); },
            setFullscreen: function() { return Promise.resolve(); },
            setTitle: function() { return Promise.resolve(); },
            innerSize: function() { return Promise.resolve({ width: 390, height: 844 }); },
            outerSize: function() { return Promise.resolve({ width: 390, height: 844 }); },
            position: function() { return Promise.resolve({ x: 0, y: 0 }); },
            setSize: function() { return Promise.resolve(); },
            setPosition: function() { return Promise.resolve(); },
            setDecorations: function() { return Promise.resolve(); },
            setAlwaysOnTop: function() { return Promise.resolve(); },
            setResizable: function() { return Promise.resolve(); },
            setMinSize: function() { return Promise.resolve(); },
            setMaxSize: function() { return Promise.resolve(); },
            startDragging: function() { return Promise.resolve(); },
            onCloseRequested: function() { return Promise.resolve(function() {}); },
            onFocus: function() { return Promise.resolve(function() {}); },
            onBlur: function() { return Promise.resolve(function() {}); }
        },
        app: {
            getName: function() { return Promise.resolve('易创'); },
            getVersion: function() { return Promise.resolve('1.1.1'); },
            getTauriVersion: function() { return Promise.resolve('2.0.0'); },
            getIdentifier: function() { return Promise.resolve('com.easywriting.app'); }
        },
        path: {
            appDataDir: function() { return Promise.resolve('/var/mobile/Containers/Data/Application/Documents'); },
            appConfigDir: function() { return Promise.resolve('/var/mobile/Containers/Data/Application/Documents'); },
            appLocalDataDir: function() { return Promise.resolve('/var/mobile/Containers/Data/Application/Documents'); },
            appCacheDir: function() { return Promise.resolve('/var/mobile/Containers/Data/Application/Library/Caches'); },
            appLogDir: function() { return Promise.resolve('/var/mobile/Containers/Data/Application/Library/Logs'); },
            documentDir: function() { return Promise.resolve('/var/mobile/Containers/Data/Application/Documents'); },
            downloadDir: function() { return Promise.resolve('/var/mobile/Containers/Data/Application/Documents/Downloads'); },
            audioDir: function() { return Promise.resolve('/var/mobile/Containers/Data/Application/Documents'); },
            pictureDir: function() { return Promise.resolve('/var/mobile/Containers/Data/Application/Documents'); },
            videoDir: function() { return Promise.resolve('/var/mobile/Containers/Data/Application/Documents'); },
            resourceDir: function() { return Promise.resolve('/var/mobile/Containers/Bundle/Application'); },
            tempDir: function() { return Promise.resolve('/var/mobile/Containers/Data/Application/tmp'); },
            resolve: function(path) { return Promise.resolve(path); },
            join: function() { return Promise.resolve(Array.prototype.join.call(arguments, '/')); },
            dirname: function(path) { return Promise.resolve(path.substring(0, path.lastIndexOf('/'))); },
            extname: function(path) { return Promise.resolve(path.substring(path.lastIndexOf('.') + 1)); },
            basename: function(path) { return Promise.resolve(path.substring(path.lastIndexOf('/') + 1)); }
        },
        os: {
            platform: function() { return Promise.resolve('ios'); },
            version: function() { return Promise.resolve('17.0'); },
            osType: function() { return Promise.resolve('iOS'); },
            arch: function() { return Promise.resolve('arm64'); },
            locale: function() { return Promise.resolve('zh-CN'); },
            hostname: function() { return Promise.resolve('iPhone'); },
            eol: function() { return Promise.resolve('\n'); }
        },
        shell: {
            open: function() { return Promise.resolve(); }
        },
        clipboard: {
            writeText: function(text) {
                try {
                    if (navigator.clipboard) navigator.clipboard.writeText(text);
                } catch(e) {}
                return Promise.resolve();
            },
            readText: function() { return Promise.resolve(''); }
        },
        dialog: {
            save: function() { return Promise.resolve('/var/mobile/Containers/Data/Application/Documents/backup.json'); },
            open: function() { return Promise.resolve(null); },
            ask: function(message) { return Promise.resolve(confirm(message)); },
            confirm: function(message) { return Promise.resolve(confirm(message)); },
            message: function(message) { alert(message); return Promise.resolve(); }
        },
        http: {
            fetch: function(url, options) {
                return fetch(url, options).then(function(r) {
                    return r.text().then(function(data) {
                        return {
                            ok: r.ok,
                            status: r.status,
                            headers: {},
                            data: data
                        };
                    });
                });
            }
        },
        updater: {
            check: function() { return Promise.resolve({ shouldUpdate: false, version: '1.1.1', body: '', date: new Date().toISOString() }); },
            download: function() { return Promise.resolve(); },
            install: function() { return Promise.resolve(); }
        },
        fs: {
            readTextFile: function(path) {
                try {
                    var data = localStorage.getItem('fs_' + path);
                    if (data) return Promise.resolve(data);
                } catch(e) {}
                return Promise.reject(new Error('File not found: ' + path));
            },
            writeTextFile: function(path, content) {
                try { localStorage.setItem('fs_' + path, content); } catch(e) {}
                return Promise.resolve();
            },
            exists: function(path) {
                return Promise.resolve(!!localStorage.getItem('fs_' + path));
            },
            mkdir: function() { return Promise.resolve(); },
            remove: function(path) {
                try { localStorage.removeItem('fs_' + path); } catch(e) {}
                return Promise.resolve();
            },
            rename: function(oldPath, newPath) {
                try {
                    var data = localStorage.getItem('fs_' + oldPath);
                    if (data) localStorage.setItem('fs_' + newPath, data);
                    localStorage.removeItem('fs_' + oldPath);
                } catch(e) {}
                return Promise.resolve();
            },
            copyFile: function(source, destination) {
                try {
                    var data = localStorage.getItem('fs_' + source);
                    if (data) localStorage.setItem('fs_' + destination, data);
                } catch(e) {}
                return Promise.resolve();
            }
        }
    };

    // ========== invoke 命令处理 ==========
    function handleInvoke(cmd, args) {
        // SQL 插件命令（全部走 handleSQL）
        if (cmd === 'plugin:sql|execute' || cmd === 'plugin:sql|select' || 
            cmd === 'plugin:sql|load' || cmd === 'plugin:sql|close') {
            return handleSQL(cmd, args);
        }

        // Dialog 插件
        if (cmd === 'plugin:dialog|save') return Promise.resolve('/Documents/backup.json');
        if (cmd === 'plugin:dialog|open') return Promise.resolve(null);
        if (cmd === 'plugin:dialog|ask' || cmd === 'plugin:dialog|confirm') {
            return Promise.resolve(confirm(args.message || '确认？'));
        }
        if (cmd === 'plugin:dialog|message') { alert(args.message || ''); return Promise.resolve(); }

        // HTTP 插件
        if (cmd === 'plugin:http|fetch') {
            return fetch(args.url, args.options || {}).then(function(r) {
                return r.text().then(function(data) {
                    return { ok: r.ok, status: r.status, headers: {}, data: data };
                });
            });
        }

        // Updater 插件
        if (cmd === 'plugin:updater|check') return Promise.resolve({ shouldUpdate: false, version: '1.1.1' });
        if (cmd === 'plugin:updater|download' || cmd === 'plugin:updater|install') return Promise.resolve();

        // FS 插件
        if (cmd === 'plugin:fs|read_text_file') {
            var data = localStorage.getItem('fs_' + args.path);
            return data ? Promise.resolve(data) : Promise.reject(new Error('Not found'));
        }
        if (cmd === 'plugin:fs|write_text_file') {
            localStorage.setItem('fs_' + args.path, args.contents || '');
            return Promise.resolve();
        }
        if (cmd === 'plugin:fs|exists') return Promise.resolve(!!localStorage.getItem('fs_' + args.path));
        if (cmd === 'plugin:fs|mkdir' || cmd === 'plugin:fs|remove' || cmd === 'plugin:fs|rename' || cmd === 'plugin:fs|copy_file') {
            return Promise.resolve();
        }

        // OS 插件
        if (cmd === 'plugin:os|platform') return Promise.resolve('ios');
        if (cmd === 'plugin:os|version') return Promise.resolve('17.0');
        if (cmd === 'plugin:os|os_type') return Promise.resolve('iOS');
        if (cmd === 'plugin:os|arch') return Promise.resolve('arm64');
        if (cmd === 'plugin:os|locale') return Promise.resolve('zh-CN');

        // Shell 插件
        if (cmd === 'plugin:shell|open') return Promise.resolve();

        // Clipboard 插件
        if (cmd === 'plugin:clipboard|write_text') {
            try { if (navigator.clipboard) navigator.clipboard.writeText(args.text || ''); } catch(e) {}
            return Promise.resolve();
        }

        // 应用自定义命令 - 返回合理的默认值
        var customCommands = {
            'restart_app': function() { return Promise.resolve(); },
            'toggle_devtools': function() { return Promise.resolve(); },
            'get_default_backup_dir': function() { return Promise.resolve('/Documents/backups'); },
            'open_backup_dir': function() { return Promise.resolve(); },
            'list_prompt_documents': function() { return Promise.resolve([]); },
            'write_prompt_document': function() { return Promise.resolve(); },
            'write_chapter_backups': function() { return Promise.resolve({ results: [] }); },
            'write_reference_backups': function() { return Promise.resolve({ results: [] }); },
            'get_app_version': function() { return Promise.resolve('1.1.1'); },
            'get_device_info': function() { return Promise.resolve({ platform: 'ios', version: '17.0' }); },
            'show_main_window': function() { return Promise.resolve(); },
            'set_window_size': function() { return Promise.resolve(); },
            'set_window_position': function() { return Promise.resolve(); },
            'minimize_window': function() { return Promise.resolve(); },
            'maximize_window': function() { return Promise.resolve(); },
            'close_window': function() { return Promise.resolve(); }
        };

        if (customCommands[cmd]) {
            return customCommands[cmd](args);
        }

        // 未知命令 - 返回 null，不报错
        console.log('[TauriMock] Unknown command:', cmd);
        return Promise.resolve(null);
    }

    // ========== SQL 处理（Tauri plugin-sql 格式）==========
    function handleSQL(cmd, args) {
        var query = args.query || '';
        var dbPath = args.db || 'default';

        // plugin:sql|load - 返回 null，JS 包装器会创建 Database 对象
        if (cmd === 'plugin:sql|load') {
            return Promise.resolve(null);
        }

        // plugin:sql|close
        if (cmd === 'plugin:sql|close') {
            return Promise.resolve(null);
        }

        if (!sqlStore[dbPath]) sqlStore[dbPath] = { tables: {} };

        // CREATE TABLE / CREATE INDEX
        if (/CREATE\s+(TABLE|INDEX)/i.test(query)) {
            var match = query.match(/CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?["`]?(\w+)["`]?/i);
            if (match) {
                var tableName = match[1];
                if (!sqlStore[dbPath].tables[tableName]) {
                    sqlStore[dbPath].tables[tableName] = [];
                }
            }
            saveSQLStore();
            // execute 返回 { rowsAffected, lastInsertId }
            return Promise.resolve({ rowsAffected: 0, lastInsertId: 0 });
        }

        // INSERT
        if (/INSERT\s+INTO/i.test(query)) {
            var insMatch = query.match(/INSERT\s+INTO\s+["`]?(\w+)["`]?/i);
            if (insMatch) {
                var insTable = insMatch[1];
                if (!sqlStore[dbPath].tables[insTable]) sqlStore[dbPath].tables[insTable] = [];
                sqlStore[dbPath].tables[insTable].push({ _raw: query, _values: args.values || [] });
            }
            saveSQLStore();
            return Promise.resolve({ rowsAffected: 1, lastInsertId: Date.now() });
        }

        // UPDATE
        if (/UPDATE\s+/i.test(query)) {
            saveSQLStore();
            return Promise.resolve({ rowsAffected: 1, lastInsertId: 0 });
        }

        // DELETE
        if (/DELETE\s+FROM/i.test(query)) {
            saveSQLStore();
            return Promise.resolve({ rowsAffected: 1, lastInsertId: 0 });
        }

        // SELECT - 关键：返回数组，不是 { rows: [] }
        if (/SELECT/i.test(query)) {
            var selMatch = query.match(/FROM\s+["`]?(\w+)["`]?/i);
            if (selMatch && sqlStore[dbPath].tables[selMatch[1]]) {
                return Promise.resolve(sqlStore[dbPath].tables[selMatch[1]]);
            }
            return Promise.resolve([]);
        }

        // DROP TABLE
        if (/DROP\s+TABLE/i.test(query)) {
            var dropMatch = query.match(/DROP\s+TABLE\s+(?:IF\s+EXISTS\s+)?["`]?(\w+)["`]?/i);
            if (dropMatch) delete sqlStore[dbPath].tables[dropMatch[1]];
            saveSQLStore();
            return Promise.resolve({ rowsAffected: 0, lastInsertId: 0 });
        }

        // PRAGMA / 其他
        if (/PRAGMA/i.test(query)) {
            return Promise.resolve([]);
        }

        // 其他 SQL - execute 返回对象
        if (cmd === 'plugin:sql|execute') {
            return Promise.resolve({ rowsAffected: 0, lastInsertId: 0 });
        }
        // select 返回数组
        return Promise.resolve([]);
    }

    console.log('[TauriMock] Tauri API Mock loaded (v2 internals + v1 compat)');
})();
