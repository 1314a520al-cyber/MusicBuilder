(function() {
    'use strict';
    
    // ========== SQL 模拟（基于 localStorage）==========
    var dbStore = {
        _get: function(dbId) {
            try {
                var raw = localStorage.getItem('tauri_sql_' + dbId);
                return raw ? JSON.parse(raw) : {};
            } catch(e) { return {}; }
        },
        _set: function(dbId, data) {
            try { localStorage.setItem('tauri_sql_' + dbId, JSON.stringify(data)); } catch(e) {}
        },
        execute: function(dbId, query, params) {
            var db = this._get(dbId);
            query = (query || '').trim();
            params = params || [];
            
            // CREATE TABLE
            if (/^CREATE\s+TABLE/i.test(query)) {
                var match = query.match(/CREATE\s+TABLE\s+(?:IF\s+NOT\s+EXISTS\s+)?["`']?(\w+)["`']?/i);
                if (match) {
                    var tableName = match[1];
                    if (!db[tableName]) db[tableName] = [];
                    this._set(dbId, db);
                }
                return { rowsAffected: 0, lastInsertId: 0 };
            }
            
            // INSERT
            if (/^INSERT\s+INTO/i.test(query)) {
                var im = query.match(/INSERT\s+INTO\s+["`']?(\w+)["`']?\s*\(([^)]+)\)\s*VALUES/i);
                if (im) {
                    var tName = im[1];
                    var cols = im[2].split(',').map(function(c){return c.trim().replace(/["`']/g,'');});
                    if (!db[tName]) db[tName] = [];
                    // 处理多行 VALUES
                    var valuesMatch = query.match(/VALUES\s*(.+)/i);
                    if (valuesMatch) {
                        var rows = valuesMatch[1].split(/\),\s*\(/).map(function(row) {
                            return row.replace(/^\(|\)$/g, '').split(',').map(function(v){return v.trim();});
                        });
                        rows.forEach(function(vals) {
                            var obj = {};
                            cols.forEach(function(col, i) {
                                var v = vals[i] !== undefined ? vals[i] : null;
                                if (v === '?' && params.length > 0) v = params.shift();
                                if (typeof v === 'string') {
                                    v = v.replace(/^["']|["']$/g, '');
                                    if (v === 'NULL' || v === 'null') v = null;
                                    else if (!isNaN(v) && v !== '') v = Number(v);
                                }
                                obj[col] = v;
                            });
                            if (!obj.id) obj.id = Date.now() + Math.random();
                            db[tName].push(obj);
                        });
                    }
                    this._set(dbId, db);
                    return { rowsAffected: 1, lastInsertId: db[tName].length };
                }
            }
            
            // UPDATE
            if (/^UPDATE/i.test(query)) {
                var um = query.match(/UPDATE\s+["`']?(\w+)["`']?\s+SET\s+(.+?)(?:\s+WHERE\s+(.+))?$/i);
                if (um) {
                    var utName = um[1];
                    var setStr = um[2];
                    var whereStr = um[3];
                    if (!db[utName]) db[utName] = [];
                    var setPairs = setStr.split(',').map(function(p) {
                        var parts = p.split('=').map(function(s){return s.trim();});
                        return {col: parts[0].replace(/["`']/g,''), val: parts[1]};
                    });
                    var count = 0;
                    db[utName].forEach(function(row) {
                        var match = !whereStr || true; // 简化：默认匹配所有
                        if (match) {
                            setPairs.forEach(function(pair) {
                                var v = pair.val;
                                if (v === '?' && params.length > 0) v = params.shift();
                                if (typeof v === 'string') v = v.replace(/^["']|["']$/g, '');
                                row[pair.col] = v;
                            });
                            count++;
                        }
                    });
                    this._set(dbId, db);
                    return { rowsAffected: count, lastInsertId: 0 };
                }
            }
            
            // DELETE
            if (/^DELETE\s+FROM/i.test(query)) {
                var dm = query.match(/DELETE\s+FROM\s+["`']?(\w+)["`']?(?:\s+WHERE\s+(.+))?$/i);
                if (dm) {
                    var dtName = dm[1];
                    if (db[dtName]) {
                        var dCount = db[dtName].length;
                        db[dtName] = [];
                        this._set(dbId, db);
                        return { rowsAffected: dCount, lastInsertId: 0 };
                    }
                }
            }
            
            // DROP TABLE
            if (/^DROP\s+TABLE/i.test(query)) {
                var dm2 = query.match(/DROP\s+TABLE\s+(?:IF\s+EXISTS\s+)?["`']?(\w+)["`']?/i);
                if (dm2 && db[dm2[1]]) {
                    delete db[dm2[1]];
                    this._set(dbId, db);
                }
                return { rowsAffected: 0, lastInsertId: 0 };
            }
            
            return { rowsAffected: 0, lastInsertId: 0 };
        },
        select: function(dbId, query, params) {
            var db = this._get(dbId);
            query = (query || '').trim();
            params = params || [];
            
            // SELECT
            var sm = query.match(/SELECT\s+(.+?)\s+FROM\s+["`']?(\w+)["`']?(?:\s+WHERE\s+(.+?))?(?:\s+ORDER\s+BY\s+(.+?))?(?:\s+LIMIT\s+(\d+))?$/i);
            if (sm) {
                var tName = sm[2];
                var rows = db[tName] || [];
                // 简单 WHERE 过滤
                if (sm[3]) {
                    var where = sm[3];
                    var eqMatch = where.match(/(\w+)\s*=\s*\?/);
                    if (eqMatch && params.length > 0) {
                        var col = eqMatch[1];
                        var val = params[0];
                        rows = rows.filter(function(r) { return String(r[col]) === String(val); });
                    }
                }
                // LIMIT
                if (sm[5]) rows = rows.slice(0, parseInt(sm[5]));
                return rows;
            }
            
            // PRAGMA table_info
            if (/^PRAGMA\s+table_info/i.test(query)) {
                return [];
            }
            
            return [];
        }
    };
    
    // ========== 事件系统 ==========
    var listeners = {};
    
    // ========== 核心 Tauri API ==========
    window.__TAURI__ = {
        core: {
            invoke: function(cmd, args) {
                console.log('[TauriMock] invoke:', cmd, args);
                return new Promise(function(resolve, reject) {
                    try {
                        switch(cmd) {
                            // SQL 插件
                            case 'plugin:sql|execute':
                                var r1 = dbStore.execute(args.db, args.query, args.values || []);
                                resolve(r1);
                                break;
                            case 'plugin:sql|select':
                                var r2 = dbStore.select(args.db, args.query, args.values || []);
                                resolve(r2);
                                break;
                            case 'plugin:sql|load':
                            case 'plugin:sql|close':
                                resolve({});
                                break;
                            
                            // Dialog 插件
                            case 'plugin:dialog|save':
                            case 'plugin:dialog|open':
                                resolve(null);
                                break;
                            case 'plugin:dialog|ask':
                            case 'plugin:dialog|confirm':
                            case 'plugin:dialog|message':
                                resolve(true);
                                break;
                            
                            // HTTP 插件
                            case 'plugin:http|fetch':
                                var url = args.url || (args.request && args.request.url);
                                var method = (args.method || (args.request && args.request.method) || 'GET').toUpperCase();
                                var body = args.body || (args.request && args.request.body);
                                var headers = args.headers || (args.request && args.request.headers) || {};
                                var fetchOpts = { method: method, headers: headers };
                                if (body && method !== 'GET') fetchOpts.body = typeof body === 'string' ? body : JSON.stringify(body);
                                fetch(url, fetchOpts)
                                    .then(function(r) { return r.text().then(function(t) { return {data: t, status: r.status, headers: {}}; }); })
                                    .then(resolve)
                                    .catch(reject);
                                break;
                            
                            // Updater
                            case 'plugin:updater|check':
                                resolve({ shouldUpdate: false, manifest: null });
                                break;
                            case 'plugin:updater|download':
                            case 'plugin:updater|install':
                                resolve({});
                                break;
                            
                            // FS 插件
                            case 'plugin:fs|read_text_file':
                                resolve(localStorage.getItem('tauri_fs_' + (args.path || '')) || '');
                                break;
                            case 'plugin:fs|write_text_file':
                                localStorage.setItem('tauri_fs_' + (args.path || ''), args.contents || '');
                                resolve({});
                                break;
                            case 'plugin:fs|exists':
                                resolve(!!localStorage.getItem('tauri_fs_' + (args.path || '')));
                                break;
                            case 'plugin:fs|mkdir':
                            case 'plugin:fs|remove':
                            case 'plugin:fs|rename':
                            case 'plugin:fs|copy_file':
                                resolve({});
                                break;
                            
                            // 应用命令
                            case 'restart_app':
                            case 'toggle_devtools':
                            case 'get_default_backup_dir':
                                resolve('/Documents/EasyWriting');
                                break;
                            case 'open_backup_dir':
                            case 'write_chapter_backups':
                                resolve({});
                                break;
                            
                            // OS 插件
                            case 'plugin:os|platform':
                                resolve('ios');
                                break;
                            case 'plugin:os|version':
                                resolve('17.0');
                                break;
                            case 'plugin:os|os_type':
                                resolve('iOS');
                                break;
                            case 'plugin:os|arch':
                                resolve('aarch64');
                                break;
                            case 'plugin:os|locale':
                                resolve('zh-CN');
                                break;
                            
                            // Shell 插件
                            case 'plugin:shell|open':
                                resolve({});
                                break;
                            
                            // Clipboard
                            case 'plugin:clipboard|write_text':
                                if (navigator.clipboard) navigator.clipboard.writeText(args.text || '');
                                resolve({});
                                break;
                            case 'plugin:clipboard|read_text':
                                resolve(navigator.clipboard ? '' : '');
                                break;
                            
                            // Notification
                            case 'plugin:notification|notify':
                                resolve({});
                                break;
                            
                            // Path 插件
                            case 'plugin:path|app_data_dir':
                            case 'plugin:path|app_config_dir':
                            case 'plugin:path|app_local_data_dir':
                            case 'plugin:path|document_dir':
                            case 'plugin:path|download_dir':
                                resolve('/Documents');
                                break;
                            case 'plugin:path|join':
                                resolve((args.paths || []).join('/'));
                                break;
                            case 'plugin:path|dirname':
                                resolve('/Documents');
                                break;
                            case 'plugin:path|basename':
                                resolve('file');
                                break;
                            case 'plugin:path|extname':
                                resolve('');
                                break;
                            
                            default:
                                console.log('[TauriMock] unhandled command:', cmd);
                                resolve(null);
                        }
                    } catch(e) {
                        console.error('[TauriMock] error:', e);
                        reject(e);
                    }
                });
            },
            transformCallback: function(cb) { return cb; },
            convertFileSrc: function(url) { return url; }
        },
        
        event: {
            listen: function(event, cb) {
                if (!listeners[event]) listeners[event] = [];
                listeners[event].push(cb);
                return Promise.resolve(function() {
                    listeners[event] = listeners[event].filter(function(f) { return f !== cb; });
                });
            },
            once: function(event, cb) {
                var wrapper = function(payload) { cb(payload); };
                return this.listen(event, wrapper);
            },
            emit: function(event, payload) {
                if (listeners[event]) {
                    listeners[event].forEach(function(cb) { cb({ payload: payload }); });
                }
                return Promise.resolve();
            }
        },
        
        window: {
            listen: function(event, cb) { return window.__TAURI__.event.listen(event, cb); },
            emit: function(event, payload) { return window.__TAURI__.event.emit(event, payload); },
            setTitle: function() { return Promise.resolve(); },
            maximize: function() { return Promise.resolve(); },
            unmaximize: function() { return Promise.resolve(); },
            minimize: function() { return Promise.resolve(); },
            hide: function() { return Promise.resolve(); },
            show: function() { return Promise.resolve(); },
            close: function() { return Promise.resolve(); },
            setSize: function() { return Promise.resolve(); },
            setPosition: function() { return Promise.resolve(); },
            setFullscreen: function() { return Promise.resolve(); },
            setDecorations: function() { return Promise.resolve(); },
            setAlwaysOnTop: function() { return Promise.resolve(); },
            setResizable: function() { return Promise.resolve(); },
            startDragging: function() { return Promise.resolve(); },
            getCurrentWindow: function() { return window.__TAURI__.window; },
            getAllWindows: function() { return Promise.resolve([window.__TAURI__.window]); },
            label: 'main',
            scaleFactor: function() { return Promise.resolve(1.0); },
            innerSize: function() { return Promise.resolve({width: 390, height: 844}); },
            outerSize: function() { return Promise.resolve({width: 390, height: 844}); },
            isFullscreen: function() { return Promise.resolve(false); },
            isMaximized: function() { return Promise.resolve(false); }
        },
        
        path: {
            appDataDir: function() { return Promise.resolve('/Documents'); },
            appConfigDir: function() { return Promise.resolve('/Documents'); },
            appLocalDataDir: function() { return Promise.resolve('/Documents'); },
            documentDir: function() { return Promise.resolve('/Documents'); },
            downloadDir: function() { return Promise.resolve('/Documents'); },
            join: function() { return Promise.resolve('/Documents/file'); },
            dirname: function() { return Promise.resolve('/Documents'); },
            basename: function() { return Promise.resolve('file'); },
            extname: function() { return Promise.resolve(''); },
            normalize: function(p) { return Promise.resolve(p); }
        },
        
        fs: {
            readTextFile: function(path) { return Promise.resolve(localStorage.getItem('tauri_fs_' + path) || ''); },
            writeTextFile: function(path, contents) { localStorage.setItem('tauri_fs_' + path, contents); return Promise.resolve(); },
            exists: function(path) { return Promise.resolve(!!localStorage.getItem('tauri_fs_' + path)); },
            mkdir: function() { return Promise.resolve(); },
            remove: function() { return Promise.resolve(); },
            rename: function() { return Promise.resolve(); },
            copyFile: function() { return Promise.resolve(); },
            readDir: function() { return Promise.resolve([]); }
        },
        
        os: {
            platform: function() { return Promise.resolve('ios'); },
            version: function() { return Promise.resolve('17.0'); },
            osType: function() { return Promise.resolve('iOS'); },
            arch: function() { return Promise.resolve('aarch64'); },
            locale: function() { return Promise.resolve('zh-CN'); }
        },
        
        shell: {
            open: function() { return Promise.resolve(); }
        },
        
        dialog: {
            save: function() { return Promise.resolve(null); },
            open: function() { return Promise.resolve(null); },
            ask: function() { return Promise.resolve(true); },
            confirm: function() { return Promise.resolve(true); },
            message: function() { return Promise.resolve(); }
        },
        
        clipboard: {
            writeText: function(text) { if (navigator.clipboard) navigator.clipboard.writeText(text); return Promise.resolve(); },
            readText: function() { return Promise.resolve(''); }
        },
        
        notification: {
            notify: function() { return Promise.resolve(); },
            requestPermission: function() { return Promise.resolve('granted'); },
            isPermissionGranted: function() { return Promise.resolve(true); }
        }
    };
    
    // 兼容旧版 Tauri API 路径
    window.__TAURI__.invoke = window.__TAURI__.core.invoke;
    
    console.log('[TauriMock] initialized with SQL/localStorage backend');
})();
