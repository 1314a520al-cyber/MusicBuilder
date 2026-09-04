// Tauri API Mock for iOS WKWebView
// 用 localStorage 和 fetch 替代 Tauri 的 SQL/HTTP/Dialog 插件

(function() {
    'use strict';
    
    // 简易事件系统
    const listeners = {};
    
    // 核心 Tauri 对象
    window.__TAURI__ = {
        // 核心 invoke - 所有 Tauri 命令都走这里
        invoke: function(cmd, args) {
            return new Promise(function(resolve, reject) {
                console.log('[TauriMock] invoke:', cmd, args);
                switch(cmd) {
                    case 'plugin:sql|execute':
                    case 'plugin:sql|select':
                        // SQL 操作用 localStorage 模拟
                        resolve({ rows: [], lastInsertId: 0, affectedRows: 0 });
                        break;
                    case 'plugin:dialog|save':
                    case 'plugin:dialog|open':
                        // 文件对话框 - 返回空
                        resolve(null);
                        break;
                    case 'plugin:http|fetch':
                        // HTTP 请求用 fetch 代理
                        if (args && args.options && args.options.url) {
                            fetch(args.options.url, {
                                method: args.options.method || 'GET',
                                headers: args.options.headers || {},
                                body: args.options.body
                            }).then(function(r) { return r.text(); })
                              .then(function(t) { resolve({ data: t, status: 200 }); })
                              .catch(function(e) { reject(e); });
                        } else {
                            resolve({ data: '', status: 200 });
                        }
                        break;
                    case 'plugin:updater|check':
                        resolve({ shouldUpdate: false, manifest: null });
                        break;
                    default:
                        resolve(null);
                }
            });
        },
        
        // 事件系统
        event: {
            listen: function(event, cb) {
                if (!listeners[event]) listeners[event] = [];
                listeners[event].push(cb);
                return Promise.resolve(function() {
                    listeners[event] = listeners[event].filter(function(f) { return f !== cb; });
                });
            },
            emit: function(event, payload) {
                if (listeners[event]) {
                    listeners[event].forEach(function(cb) { cb({ payload: payload }); });
                }
                return Promise.resolve();
            }
        },
        
        // 窗口
        window: {
            appWindow: {
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
                setMinSize: function() { return Promise.resolve(); },
                setMaxSize: function() { return Promise.resolve(); },
                setSkipTaskbar: function() { return Promise.resolve(); },
                startDragging: function() { return Promise.resolve(); },
            }
        },
        
        // 路径
        path: {
            appDataDir: function() { return Promise.resolve('/data/'); },
            appConfigDir: function() { return Promise.resolve('/config/'); },
            appLocalDataDir: function() { return Promise.resolve('/localdata/'); },
            appLogDir: function() { return Promise.resolve('/logs/'); },
            audioDir: function() { return Promise.resolve('/audio/'); },
            cacheDir: function() { return Promise.resolve('/cache/'); },
            configDir: function() { return Promise.resolve('/config/'); },
            dataDir: function() { return Promise.resolve('/data/'); },
            desktopDir: function() { return Promise.resolve('/desktop/'); },
            documentDir: function() { return Promise.resolve('/documents/'); },
            downloadDir: function() { return Promise.resolve('/downloads/'); },
            homeDir: function() { return Promise.resolve('/home/'); },
            localDataDir: function() { return Promise.resolve('/localdata/'); },
            pictureDir: function() { return Promise.resolve('/pictures/'); },
            publicDir: function() { return Promise.resolve('/public/'); },
            videoDir: function() { return Promise.resolve('/video/'); },
            resolve: function() { return Promise.resolve(''); },
            resolveResource: function() { return Promise.resolve(''); },
            sep: '/',
            delimiter: ':',
            basename: function(p) { return p.split('/').pop(); },
            dirname: function(p) { return p.split('/').slice(0, -1).join('/'); },
            extname: function(p) { var e = p.split('.').pop(); return e === p ? '' : e; },
            isAbsolute: function(p) { return p.startsWith('/'); },
            join: function() { return Array.from(arguments).join('/'); },
            normalize: function(p) { return p; },
        },
        
        // FS
        fs: {
            readTextFile: function(path) {
                return Promise.resolve(localStorage.getItem('fs_' + path) || '');
            },
            writeTextFile: function(path, content) {
                localStorage.setItem('fs_' + path, content);
                return Promise.resolve();
            },
            readBinaryFile: function(path) {
                return Promise.resolve(new Uint8Array());
            },
            writeBinaryFile: function(path, data) {
                return Promise.resolve();
            },
            exists: function(path) {
                return Promise.resolve(!!localStorage.getItem('fs_' + path));
            },
            createDir: function() { return Promise.resolve(); },
            removeDir: function() { return Promise.resolve(); },
            removeFile: function(path) {
                localStorage.removeItem('fs_' + path);
                return Promise.resolve();
            },
            renameFile: function() { return Promise.resolve(); },
            copyFile: function() { return Promise.resolve(); },
            mkdir: function() { return Promise.resolve(); },
        },
        
        // OS
        os: {
            platform: function() { return Promise.resolve('ios'); },
            version: function() { return Promise.resolve('16.0'); },
            type: function() { return Promise.resolve('iOS'); },
            arch: function() { return Promise.resolve('arm64'); },
            locale: function() { return Promise.resolve('zh-CN'); },
        },
        
        // Shell
        shell: {
            open: function(url) { window.open(url); return Promise.resolve(); },
        },
        
        // Clipboard
        clipboard: {
            writeText: function(text) {
                if (navigator.clipboard) navigator.clipboard.writeText(text);
                return Promise.resolve();
            },
            readText: function() {
                return Promise.resolve('');
            },
        },
        
        // Notification
        notification: {
            isPermissionGranted: function() { return Promise.resolve(true); },
            requestPermission: function() { return Promise.resolve('granted'); },
            sendNotification: function(opts) {
                if (Notification.permission === 'granted') {
                    new Notification(opts.title || '通知', { body: opts.body || '' });
                }
                return Promise.resolve();
            },
        },
        
        // Global shortcut
        globalShortcut: {
            register: function() { return Promise.resolve(); },
            unregister: function() { return Promise.resolve(); },
            isRegistered: function() { return Promise.resolve(false); },
        },
        
        // Process
        process: {
            exit: function() {},
            relaunch: function() {},
            platform: 'ios',
            arch: 'arm64',
        },
    };
    
    // 插件命名空间
    window.__TAURI__.dialog = {
        open: function() { return Promise.resolve(null); },
        save: function() { return Promise.resolve(null); },
        message: function(msg) { alert(msg); return Promise.resolve(); },
        ask: function(msg) { return Promise.resolve(confirm(msg)); },
        confirm: function(msg) { return Promise.resolve(confirm(msg)); },
    };
    
    window.__TAURI__.http = {
        fetch: function(url, options) {
            return fetch(url, options).then(function(r) { return r.text(); }).then(function(t) {
                return { data: t, status: 200, headers: {} };
            });
        },
    };
    
    window.__TAURI__.sql = {
        load: function() { return Promise.resolve({ id: 1 }); },
        get: function() { return Promise.resolve({ id: 1 }); },
        execute: function() { return Promise.resolve({ rowsAffected: 0, lastInsertId: 0 }); },
        select: function() { return Promise.resolve([]); },
        close: function() { return Promise.resolve(); },
    };
    
    window.__TAURI__.updater = {
        checkUpdate: function() { return Promise.resolve({ shouldUpdate: false, manifest: null }); },
        installUpdate: function() { return Promise.resolve(); },
    };
    
    // 兼容旧版 Tauri 1.x 调用方式
    if (typeof window.__TAURI_IPC__ !== 'function') {
        window.__TAURI_IPC__ = function(args) {
            return window.__TAURI__.invoke(args.cmd, args.args);
        };
    }
    
    console.log('[TauriMock] Tauri API mock loaded');
})();
