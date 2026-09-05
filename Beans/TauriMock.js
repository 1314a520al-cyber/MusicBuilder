(function() {
    'use strict';
    // ===== 终极安全层：Proxy 包装所有 Tauri 对象，任何未定义属性都返回 noop 函数 =====
    function makeSafeObject(obj, name) {
        if (obj === null || obj === undefined) obj = {};
        return new Proxy(obj, {
            get: function(target, prop) {
                if (prop in target) {
                    var val = target[prop];
                    if (typeof val === 'object' && val !== null && !val.__safe__) {
                        val.__safe__ = true;
                        return makeSafeObject(val, name + '.' + prop);
                    }
                    return val;
                }
                // 未定义的属性返回一个 noop 函数，调用时返回 Promise.resolve(null)
                var fn = function() { return Promise.resolve(null); };
                fn.__isNoop = true;
                return fn;
            },
            set: function(target, prop, value) {
                target[prop] = value;
                return true;
            }
        });
    }
    
    // 预定义 window.__TAURI__ 为安全对象
    if (!window.__TAURI__) window.__TAURI__ = {};
    window.__TAURI__ = makeSafeObject(window.__TAURI__, '__TAURI__');
    
    // 预定义 window.__TAURI_INTERNALS__ 为安全对象
    if (!window.__TAURI_INTERNALS__) window.__TAURI_INTERNALS__ = {};
    window.__TAURI_INTERNALS__ = makeSafeObject(window.__TAURI_INTERNALS__, '__TAURI_INTERNALS__');
    
    // 预定义事件插件
    if (!window.__TAURI_EVENT_PLUGIN_INTERNALS__) window.__TAURI_EVENT_PLUGIN_INTERNALS__ = {};
    window.__TAURI_EVENT_PLUGIN_INTERNALS__ = makeSafeObject(window.__TAURI_EVENT_PLUGIN_INTERNALS__, '__TAURI_EVENT_PLUGIN_INTERNALS__');
    
    console.log('[TauriMock] Proxy安全层已加载，所有未定义API返回noop');

    
    // ===== 错误追踪 =====
    window.__TAURI_DEBUG__ = { errors: [], logs: [] };
    var origError = console.error;
    console.error = function() {
        try { window.__TAURI_DEBUG__.errors.push(Array.prototype.slice.call(arguments).map(String).join(' ')); } catch(e) {}
        origError.apply(console, arguments);
    };
    var origLog = console.log;
    console.log = function() {
        try { window.__TAURI_DEBUG__.logs.push(Array.prototype.slice.call(arguments).map(String).join(' ')); } catch(e) {}
        origLog.apply(console, arguments);
    };
    
    // ===== 状态 =====
    var callbackId = 0;
    var callbacks = {};
    var sqlStore = {};
    var listeners = {};
    var fsStore = {};
    
    function loadSQL() { try { var d = localStorage.getItem('ew_sql_v3'); if (d) sqlStore = JSON.parse(d); } catch(e) { sqlStore = {}; } }
    function saveSQL() { try { localStorage.setItem('ew_sql_v3', JSON.stringify(sqlStore)); } catch(e) {} }
    loadSQL();
    
    // ===== IPC Key =====
    var IPC_KEY = Symbol('tauri-ipc');
    window.__TAURI_TO_IPC_KEY__ = IPC_KEY;
    
    // ===== 事件插件 =====
    window.__TAURI_EVENT_PLUGIN_INTERNALS__ = {
        transformCallback: function(cb, once) {
            var id = ++callbackId;
            callbacks[id] = { cb: cb, once: !!once };
            return id;
        },
        unregisterCallback: function(id) { try { delete callbacks[id]; } catch(e) {} }
    };
    
    // ===== 核心 internals =====
    function safeInvoke(cmd, args, options) {
        try {
            return handleInvoke(cmd, args || {}, options || {});
        } catch(e) {
            console.error('[TauriMock invoke crash]', cmd, e);
            return Promise.resolve(null);
        }
    }
    
    window.__TAURI_INTERNALS__ = {
        transformCallback: function(cb, once) {
            var id = ++callbackId;
            callbacks[id] = { cb: cb, once: !!once };
            return id;
        },
        unregisterCallback: function(id) { try { delete callbacks[id]; } catch(e) {} },
        invoke: safeInvoke,
        convertFileSrc: function(path, protocol) {
            if (typeof path === 'string' && path.indexOf('http') === 0) return path;
            return path || '';
        },
        event: {
            listen: function(ev, h) {
                if (!listeners[ev]) listeners[ev] = [];
                listeners[ev].push(h);
                return Promise.resolve(function() { try { listeners[ev] = listeners[ev].filter(function(f) { return f !== h; }); } catch(e) {} });
            },
            once: function(ev, h) {
                var wrapper = function(payload) { try { h(payload); } catch(e) {} try { listeners[ev] = listeners[ev].filter(function(f) { return f !== wrapper; }); } catch(e) {} };
                if (!listeners[ev]) listeners[ev] = [];
                listeners[ev].push(wrapper);
                return Promise.resolve(function() {});
            },
            emit: function(ev, payload) {
                try { if (listeners[ev]) listeners[ev].forEach(function(h) { try { h({ payload: payload }); } catch(e) {} }); } catch(e) {}
                return Promise.resolve();
            }
        }
    };
    
    // ===== 兼容层 =====
    window.__TAURI__ = window.__TAURI_INTERNALS__;
    window.__TAURI__.core = {
        invoke: safeInvoke,
        convertFileSrc: window.__TAURI_INTERNALS__.convertFileSrc,
        transformCallback: window.__TAURI_INTERNALS__.transformCallback,
        unregisterCallback: window.__TAURI_INTERNALS__.unregisterCallback
    };
    window.__TAURI__.event = window.__TAURI_INTERNALS__.event;
    
    // 所有插件对象都预定义，防止 undefined
    var pluginNames = ['window','app','path','fs','dialog','http','os','shell','clipboard','updater','image','webview','notification','global-shortcut','process','deep-link','barcode','biometric','nfc','geolocation','camera','log','store','sql','stronghold','authenticator','localhost','opener','persisted-scope','positioner','single-instance','sql','fs','store'];
    pluginNames.forEach(function(name) {
        if (!window.__TAURI__[name]) window.__TAURI__[name] = {};
    });
    
    // ===== 各插件完整实现 =====
    window.__TAURI__.window = makeWindowPlugin();
    window.__TAURI__.app = makeAppPlugin();
    window.__TAURI__.path = makePathPlugin();
    window.__TAURI__.fs = makeFsPlugin();
    window.__TAURI__.dialog = makeDialogPlugin();
    window.__TAURI__.http = makeHttpPlugin();
    window.__TAURI__.os = makeOsPlugin();
    window.__TAURI__.shell = makeShellPlugin();
    window.__TAURI__.clipboard = makeClipboardPlugin();
    window.__TAURI__.updater = makeUpdaterPlugin();
    window.__TAURI__.image = makeImagePlugin();
    window.__TAURI__.webview = makeWebviewPlugin();
    window.__TAURI__.store = makeStorePlugin();
    window.__TAURI__.sql = makeSqlPlugin();
    window.__TAURI__.log = makeLogPlugin();
    window.__TAURI__.notification = makeNotificationPlugin();
    window.__TAURI__.process = makeProcessPlugin();
    window.__TAURI__.opener = makeOpenerPlugin();
    
    function makeWindowPlugin() {
        var p = {};
        ['listen','once','emit','show','hide','close','setTitle','setSize','setPosition','maximize','unmaximize','minimize','unminimize','setFullscreen','setDecorations','setResizable','setAlwaysOnTop','setSkipTaskbar','setFocus','setIcon','setCursorIcon','setCursorPosition','setCursorGrab','setCursorVisible','setIgnoreCursorEvents','startDragging','print','innerSize','outerSize','isFullscreen','isMaximized','isMinimized','isDecorated','isResizable','title','scaleFactor','availableMonitors','currentMonitor','primaryMonitor','center','setMinSize','setMaxSize','setShadow','setContentProtected'].forEach(function(fn) {
            p[fn] = function() { return Promise.resolve(fn.indexOf('is') === 0 ? false : (fn === 'title' ? '易创' : null)); };
        });
        return p;
    }
    
    function makeAppPlugin() {
        return {
            getVersion: function() { return Promise.resolve('2.0.5'); },
            getName: function() { return Promise.resolve('易创'); },
            getTauriVersion: function() { return Promise.resolve('2.0.0'); },
            show: function() { return Promise.resolve(); },
            hide: function() { return Promise.resolve(); },
            defaultWindowIcon: function() { return Promise.resolve(null); }
        };
    }
    
    function makePathPlugin() {
        var p = {};
        ['appDataDir','appConfigDir','appLocalDataDir','appCacheDir','appLogDir','documentDir','downloadDir','homeDir','audioDir','desktopDir','fontDir','pictureDir','publicDir','runtimeDir','templateDir','videoDir','resourceDir','tempDir'].forEach(function(fn) {
            p[fn] = function() { return Promise.resolve('/Documents/' + fn + '/'); };
        });
        p.basename = function(p) { try { return p.split('/').pop(); } catch(e) { return ''; } };
        p.dirname = function(p) { try { return p.substring(0, p.lastIndexOf('/')); } catch(e) { return ''; } };
        p.extname = function(p) { try { var i = p.lastIndexOf('.'); return i > 0 ? p.substring(i) : ''; } catch(e) { return ''; } };
        p.join = function() { return Array.prototype.slice.call(arguments).join('/'); };
        p.normalize = function(p) { return p; };
        p.resolve = function() { return Array.prototype.slice.call(arguments).join('/'); };
        p.relative = function() { return ''; };
        return p;
    }
    
    function makeFsPlugin() {
        return {
            readTextFile: function(path) { try { var d = fsStore[path]; if (d !== undefined) return Promise.resolve(d); } catch(e) {} return Promise.reject(new Error('Not found')); },
            writeTextFile: function(path, contents) { try { fsStore[path] = typeof contents === 'string' ? contents : JSON.stringify(contents); } catch(e) {} return Promise.resolve(); },
            readBinaryFile: function(path) { try { if (fsStore[path]) return Promise.resolve(new Uint8Array()); } catch(e) {} return Promise.reject(new Error('Not found')); },
            writeBinaryFile: function() { return Promise.resolve(); },
            exists: function(path) { return Promise.resolve(fsStore[path] !== undefined); },
            remove: function(path) { try { delete fsStore[path]; } catch(e) {} return Promise.resolve(); },
            removeFile: function(path) { try { delete fsStore[path]; } catch(e) {} return Promise.resolve(); },
            createDir: function() { return Promise.resolve(); },
            removeDir: function() { return Promise.resolve(); },
            readDir: function() { return Promise.resolve([]); },
            copyFile: function() { return Promise.resolve(); },
            renameFile: function() { return Promise.resolve(); },
            metadata: function(path) { return Promise.resolve({ isFile: true, isDirectory: false, size: (fsStore[path] || '').length, modifiedAt: Date.now(), createdAt: Date.now() }); },
            watch: function() { return Promise.resolve(function() {}); },
            unwatch: function() { return Promise.resolve(); }
        };
    }
    
    function makeDialogPlugin() {
        return {
            save: function() { return Promise.resolve('/Documents/backup.json'); },
            open: function() { return Promise.resolve(null); },
            ask: function() { return Promise.resolve(true); },
            confirm: function() { return Promise.resolve(true); },
            message: function(msg) { try { alert(typeof msg === 'string' ? msg : (msg && msg.title) || ''); } catch(e) {} return Promise.resolve(); }
        };
    }
    
    function makeHttpPlugin() {
        return {
            fetch: function(url, options) {
                try {
                    return fetch(url, options || {}).then(function(r) {
                        return r.text().then(function(d) {
                            return { ok: r.ok, status: r.status, data: d, headers: {} };
                        });
                    });
                } catch(e) {
                    return Promise.resolve({ ok: false, status: 0, data: '', headers: {} });
                }
            }
        };
    }
    
    function makeOsPlugin() {
        return {
            platform: function() { return Promise.resolve('ios'); },
            version: function() { return Promise.resolve('17.0'); },
            osType: function() { return Promise.resolve('iOS'); },
            arch: function() { return Promise.resolve('arm64'); },
            locale: function() { return Promise.resolve('zh-CN'); },
            family: function() { return Promise.resolve('ios'); },
            hostname: function() { return Promise.resolve('iPhone'); },
            exeExtension: function() { return Promise.resolve(''); }
        };
    }
    
    function makeShellPlugin() {
        return {
            open: function() { return Promise.resolve(); },
            Command: function() { return { execute: function() { return Promise.resolve({ code: 0, stdout: '', stderr: '' }); }, spawn: function() { return Promise.resolve({ pid: 0 }); } }; }
        };
    }
    
    function makeClipboardPlugin() {
        return {
            writeText: function(text) { try { if (navigator.clipboard) navigator.clipboard.writeText(text || ''); } catch(e) {} return Promise.resolve(); },
            readText: function() { return Promise.resolve(''); },
            writeHTML: function() { return Promise.resolve(); },
            clear: function() { return Promise.resolve(); }
        };
    }
    
    function makeUpdaterPlugin() {
        return {
            check: function() { return Promise.resolve({ shouldUpdate: false, version: '2.0.5', body: '', date: '' }); },
            install: function() { return Promise.resolve(); },
            download: function() { return Promise.resolve(); }
        };
    }
    
    function makeImagePlugin() {
        return {
            transform: function() { return Promise.resolve(null); },
            fromPath: function() { return Promise.resolve(null); },
            fromBytes: function() { return Promise.resolve(null); },
            rgba: function() { return Promise.resolve(new Uint8Array()); },
            size: function() { return Promise.resolve({ width: 0, height: 0 }); }
        };
    }
    
    function makeWebviewPlugin() {
        return {
            listen: function() { return Promise.resolve(function() {}); },
            once: function() { return Promise.resolve(function() {}); },
            emit: function() { return Promise.resolve(); },
            show: function() { return Promise.resolve(); },
            hide: function() { return Promise.resolve(); },
            setFocus: function() { return Promise.resolve(); }
        };
    }
    
    function makeStorePlugin() {
        return {
            get: function(key) { try { return Promise.resolve(JSON.parse(localStorage.getItem('store_' + key) || 'null')); } catch(e) { return Promise.resolve(null); } },
            set: function(key, value) { try { localStorage.setItem('store_' + key, JSON.stringify(value)); } catch(e) {} return Promise.resolve(); },
            has: function(key) { return Promise.resolve(localStorage.getItem('store_' + key) !== null); },
            delete: function(key) { try { localStorage.removeItem('store_' + key); } catch(e) {} return Promise.resolve(); },
            clear: function() { try { Object.keys(localStorage).filter(function(k) { return k.indexOf('store_') === 0; }).forEach(function(k) { localStorage.removeItem(k); }); } catch(e) {} return Promise.resolve(); },
            keys: function() { return Promise.resolve(Object.keys(localStorage).filter(function(k) { return k.indexOf('store_') === 0; }).map(function(k) { return k.substring(6); })); },
            load: function() { return Promise.resolve(); },
            save: function() { return Promise.resolve(); }
        };
    }
    
    function makeSqlPlugin() {
        return {
            load: function() { return Promise.resolve(null); },
            close: function() { return Promise.resolve(null); },
            execute: function(query, args) {
                try {
                    var result = handleSQLQuery(query, args || []);
                    // Tauri v2 execute 返回 QueryResult
                    if (result && result.rows) {
                        return Promise.resolve({ rowsAffected: result.rowsAffected || 0, lastInsertId: result.lastInsertId || 0 });
                    }
                    return Promise.resolve({ rowsAffected: 0, lastInsertId: 0 });
                } catch(e) {
                    console.error('[SQL execute error]', query, e);
                    return Promise.resolve({ rowsAffected: 0, lastInsertId: 0 });
                }
            },
            select: function(query, args) {
                try {
                    var result = handleSQLQuery(query, args || []);
                    // Tauri v2 select 返回数组
                    return Promise.resolve(result && result.rows ? result.rows : []);
                } catch(e) {
                    console.error('[SQL select error]', query, e);
                    return Promise.resolve([]);
                }
            }
        };
    }
    
    function makeLogPlugin() {
        return {
            trace: function() { return Promise.resolve(); },
            debug: function() { return Promise.resolve(); },
            info: function() { return Promise.resolve(); },
            warn: function() { return Promise.resolve(); },
            error: function() { return Promise.resolve(); }
        };
    }
    
    function makeNotificationPlugin() {
        return {
            notify: function() { return Promise.resolve(); },
            requestPermission: function() { return Promise.resolve('granted'); },
            isPermissionGranted: function() { return Promise.resolve(true); }
        };
    }
    
    function makeProcessPlugin() {
        return {
            exit: function() { return Promise.resolve(); },
            restart: function() { return Promise.resolve(); }
        };
    }
    
    function makeOpenerPlugin() {
        return {
            openUrl: function() { return Promise.resolve(); },
            openPath: function() { return Promise.resolve(); },
            revealItemInDir: function() { return Promise.resolve(); }
        };
    }
    
    // ===== SQL 查询处理 =====
    function handleSQLQuery(query, args) {
        var q = (query || '').toString().trim();
        var db = 'default';
        
        if (!sqlStore[db]) sqlStore[db] = {};
        
        try {
            if (/^\s*CREATE\s+TABLE/i.test(q)) {
                var m = q.match(/CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?["`]?(\w+)/i);
                if (m && !sqlStore[db][m[1]]) sqlStore[db][m[1]] = [];
                saveSQL();
                return { rowsAffected: 0, lastInsertId: 0 };
            }
            if (/^\s*INSERT\s+INTO/i.test(q)) {
                var im = q.match(/INSERT\s+INTO\s+["`]?(\w+)/i);
                if (im) {
                    if (!sqlStore[db][im[1]]) sqlStore[db][im[1]] = [];
                    var row = {};
                    // 尝试提取 VALUES
                    var vm = q.match(/VALUES\s*\(([^)]+)\)/i);
                    if (vm) {
                        var vals = vm[1].split(',').map(function(v) { return v.trim().replace(/^['"]|['"]$/g, ''); });
                        row._values = vals;
                    }
                    row._raw = q;
                    row._time = Date.now();
                    sqlStore[db][im[1]].push(row);
                }
                saveSQL();
                return { rowsAffected: 1, lastInsertId: Date.now() };
            }
            if (/^\s*UPDATE\s+/i.test(q) || /^\s*DELETE\s+FROM/i.test(q)) {
                saveSQL();
                return { rowsAffected: 1, lastInsertId: 0 };
            }
            if (/^\s*SELECT/i.test(q)) {
                var sm = q.match(/FROM\s+["`]?(\w+)/i);
                var rows = (sm && sqlStore[db][sm[1]]) ? sqlStore[db][sm[1]] : [];
                return { rows: rows, rowsAffected: rows.length, lastInsertId: 0 };
            }
            if (/^\s*DROP\s+TABLE/i.test(q)) {
                var dm = q.match(/DROP\s+TABLE\s+(?:IF\s+EXISTS\s+)?["`]?(\w+)/i);
                if (dm) delete sqlStore[db][dm[1]];
                saveSQL();
                return { rowsAffected: 0, lastInsertId: 0 };
            }
            if (/^\s*PRAGMA/i.test(q)) {
                return { rows: [], rowsAffected: 0, lastInsertId: 0 };
            }
            if (/^\s*BEGIN|^\s*COMMIT|^\s*ROLLBACK/i.test(q)) {
                return { rowsAffected: 0, lastInsertId: 0 };
            }
        } catch(e) {
            console.error('[SQL handle error]', q, e);
        }
        return { rows: [], rowsAffected: 0, lastInsertId: 0 };
    }
    
    // ===== invoke 路由 =====
    function handleInvoke(cmd, args, options) {
        // SQL 插件
        if (cmd.indexOf('plugin:sql|') === 0) {
            var subCmd = cmd.substring('plugin:sql|'.length);
            if (subCmd === 'load' || subCmd === 'close') return Promise.resolve(null);
            if (subCmd === 'execute') {
                var r = handleSQLQuery(args.query, args.values || []);
                return Promise.resolve({ rowsAffected: r.rowsAffected || 0, lastInsertId: r.lastInsertId || 0 });
            }
            if (subCmd === 'select') {
                var sr = handleSQLQuery(args.query, args.values || []);
                return Promise.resolve(sr.rows || []);
            }
            return Promise.resolve(null);
        }
        
        // 所有 plugin 命令都返回安全默认值
        if (cmd.indexOf('plugin:') === 0) {
            var plugin = cmd.substring(7, cmd.indexOf('|'));
            var action = cmd.substring(cmd.indexOf('|') + 1);
            // 已知插件的特定处理
            if (plugin === 'dialog' && action === 'save') return Promise.resolve('/Documents/backup.json');
            if (plugin === 'dialog' && action === 'open') return Promise.resolve(null);
            if (plugin === 'dialog' && (action === 'ask' || action === 'confirm')) return Promise.resolve(true);
            if (plugin === 'dialog' && action === 'message') { try { alert(args.message || ''); } catch(e) {} return Promise.resolve(); }
            if (plugin === 'http' && action === 'fetch') {
                try {
                    return fetch(args.url, args.options || {}).then(function(r) {
                        return r.text().then(function(d) { return { ok: r.ok, status: r.status, data: d }; });
                    });
                } catch(e) { return Promise.resolve({ ok: false, status: 0, data: '' }); }
            }
            if (plugin === 'updater' && action === 'check') return Promise.resolve({ shouldUpdate: false, version: '999.999.999', body: '', date: '' });
            if (plugin === 'updater') return Promise.resolve();
            if (plugin === 'fs' && action === 'read_text_file') {
                var d = fsStore[args.path];
                return d !== undefined ? Promise.resolve(d) : Promise.reject(new Error('Not found'));
            }
            if (plugin === 'fs' && action === 'write_text_file') { try { fsStore[args.path] = args.contents || ''; } catch(e) {} return Promise.resolve(); }
            if (plugin === 'fs' && action === 'exists') return Promise.resolve(fsStore[args.path] !== undefined);
            if (plugin === 'fs') return Promise.resolve();
            if (plugin === 'os' && action === 'platform') return Promise.resolve('ios');
            if (plugin === 'os' && action === 'version') return Promise.resolve('17.0');
            if (plugin === 'os' && action === 'os_type') return Promise.resolve('iOS');
            if (plugin === 'os' && action === 'arch') return Promise.resolve('arm64');
            if (plugin === 'os' && action === 'locale') return Promise.resolve('zh-CN');
            if (plugin === 'os') return Promise.resolve('');
            if (plugin === 'clipboard' && action === 'write_text') { try { if (navigator.clipboard) navigator.clipboard.writeText(args.text || ''); } catch(e) {} return Promise.resolve(); }
            if (plugin === 'clipboard') return Promise.resolve('');
            if (plugin === 'shell') return Promise.resolve();
            if (plugin === 'window') return Promise.resolve();
            if (plugin === 'app') return Promise.resolve(null);
            if (plugin === 'webview') return Promise.resolve();
            if (plugin === 'image') return Promise.resolve(null);
            if (plugin === 'event') return Promise.resolve();
            if (plugin === 'store') {
                if (action === 'get') { try { return Promise.resolve(JSON.parse(localStorage.getItem('store_' + args.key) || 'null')); } catch(e) { return Promise.resolve(null); } }
                if (action === 'set') { try { localStorage.setItem('store_' + args.key, JSON.stringify(args.value)); } catch(e) {} return Promise.resolve(); }
                if (action === 'has') return Promise.resolve(localStorage.getItem('store_' + args.key) !== null);
                if (action === 'delete') { try { localStorage.removeItem('store_' + args.key); } catch(e) {} return Promise.resolve(); }
                if (action === 'keys') return Promise.resolve([]);
                return Promise.resolve();
            }
            if (plugin === 'notification') return Promise.resolve();
            if (plugin === 'log') return Promise.resolve();
            if (plugin === 'process') return Promise.resolve();
            if (plugin === 'opener') return Promise.resolve();
            // 未知插件命令 - 返回 null，不抛异常
            return Promise.resolve(null);
        }
        
        // 应用特定命令
        var appCmds = {
            'list_prompt_documents': [],
            'write_prompt_document': null,
            'get_default_backup_dir': '/Documents/backups',
            'open_backup_dir': null,
            'write_chapter_backups': { results: [] },
            'write_reference_backups': { results: [] },
            'restart_app': null,
            'toggle_devtools': null,
            'get_app_version': '999.999.999',
            'get_app_config': {},
            'save_app_config': null,
            'export_backup': '/Documents/backup.json',
            'import_backup': null,
            'get_settings': {},
            'save_settings': null
        };
        if (appCmds.hasOwnProperty(cmd)) {
            return Promise.resolve(appCmds[cmd]);
        }
        
        // 未知命令 - 返回 null
        console.log('[TauriMock unknown cmd]', cmd);
        return Promise.resolve(null);
    }
    
    // ===== 全局错误捕获 =====
    window.addEventListener('error', function(e) {
        console.error('[Global Error]', e.message, e.filename, e.lineno);
    });
    window.addEventListener('unhandledrejection', function(e) {
        console.error('[Unhandled Rejection]', e.reason);
    });
    
    console.log('[TauriMock v2.0.5 loaded] All APIs available');
})();
